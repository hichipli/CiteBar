#!/bin/bash
set -euo pipefail

DMG_FILE="${1:-${DMG_FILE:-}}"

if [ -z "$DMG_FILE" ]; then
    echo "Usage: scripts/notarize-dmg.sh path/to/CiteBar.dmg"
    exit 1
fi

if [ ! -f "$DMG_FILE" ]; then
    echo "Error: DMG not found: $DMG_FILE"
    exit 1
fi

LOG_ROOT="${NOTARY_LOG_DIR:-dist/notary-logs}"
DMG_BASENAME=$(basename "$DMG_FILE")
DMG_STEM="${DMG_BASENAME%.dmg}"
RUN_STAMP=$(date -u +"%Y%m%dT%H%M%SZ")
RUN_LOG_DIR="$LOG_ROOT/$DMG_STEM-$RUN_STAMP"
mkdir -p "$RUN_LOG_DIR"

NOTARY_ARGS=()
if [ -n "${NOTARY_PROFILE:-}" ]; then
    NOTARY_ARGS+=(--keychain-profile "$NOTARY_PROFILE")
else
    if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ] || [ -z "${APP_SPECIFIC_PASSWORD:-}" ]; then
        echo "Error: set NOTARY_PROFILE, or set APPLE_ID, APPLE_TEAM_ID, and APP_SPECIFIC_PASSWORD."
        exit 1
    fi
    NOTARY_ARGS+=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APP_SPECIFIC_PASSWORD")
fi

run_notary_log() {
    local submission_id="$1"
    local log_path="$RUN_LOG_DIR/submission-log.json"

    echo "Fetching Apple notary submission log..."
    if xcrun notarytool log "${NOTARY_ARGS[@]}" "$submission_id" "$log_path"; then
        echo "Saved Apple notary submission log: $log_path"
    else
        echo "Apple notary submission log is not available yet."
        echo "Saved log attempt output path for follow-up: $log_path"
    fi
}

echo "Submitting $DMG_FILE for notarization..."
SUBMISSION_JSON=$(xcrun notarytool submit "$DMG_FILE" "${NOTARY_ARGS[@]}" --output-format json)
echo "$SUBMISSION_JSON"
printf "%s\n" "$SUBMISSION_JSON" > "$RUN_LOG_DIR/submit.json"

SUBMISSION_ID=$(printf "%s" "$SUBMISSION_JSON" | plutil -extract id raw -o - - 2>/dev/null || true)

if [ -z "$SUBMISSION_ID" ]; then
    echo "Error: could not read notary submission ID."
    echo "Notary diagnostics directory: $RUN_LOG_DIR"
    exit 1
fi

printf "%s\n" "$SUBMISSION_ID" > "$RUN_LOG_DIR/submission-id.txt"
ln -sfn "$(basename "$RUN_LOG_DIR")" "$LOG_ROOT/latest"

POLL_INTERVAL_SECONDS="${NOTARY_POLL_INTERVAL_SECONDS:-30}"
TIMEOUT_SECONDS="${NOTARY_TIMEOUT_SECONDS:-1800}"
ELAPSED_SECONDS=0
STATUS="In Progress"
POLL_COUNT=0

echo "Waiting for notarization result for submission: $SUBMISSION_ID"
while [ "$STATUS" = "In Progress" ] && [ "$ELAPSED_SECONDS" -lt "$TIMEOUT_SECONDS" ]; do
    sleep "$POLL_INTERVAL_SECONDS"
    ELAPSED_SECONDS=$((ELAPSED_SECONDS + POLL_INTERVAL_SECONDS))
    POLL_COUNT=$((POLL_COUNT + 1))

    INFO_JSON=$(xcrun notarytool info "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" --output-format json)
    STATUS=$(printf "%s" "$INFO_JSON" | plutil -extract status raw -o - - 2>/dev/null || true)
    INFO_PATH=$(printf "%s/poll-%03d.json" "$RUN_LOG_DIR" "$POLL_COUNT")
    printf "%s\n" "$INFO_JSON" > "$INFO_PATH"
    printf "%s\n" "$INFO_JSON" > "$RUN_LOG_DIR/latest-info.json"

    echo "[$ELAPSED_SECONDS/$TIMEOUT_SECONDS seconds] Notarization status: ${STATUS:-unknown}"
done

if [ "$STATUS" = "In Progress" ]; then
    echo "Notarization is still in progress after $TIMEOUT_SECONDS seconds."
    run_notary_log "$SUBMISSION_ID" || true
    echo "Resume checking with:"
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        echo "  xcrun notarytool info $SUBMISSION_ID --keychain-profile \"$NOTARY_PROFILE\""
        echo "  xcrun notarytool log $SUBMISSION_ID --keychain-profile \"$NOTARY_PROFILE\" \"$RUN_LOG_DIR/submission-log.json\""
    else
        echo "  xcrun notarytool info $SUBMISSION_ID --apple-id \"$APPLE_ID\" --team-id \"$APPLE_TEAM_ID\" --password \"<app-specific-password>\""
        echo "  xcrun notarytool log $SUBMISSION_ID --apple-id \"$APPLE_ID\" --team-id \"$APPLE_TEAM_ID\" --password \"<app-specific-password>\" \"$RUN_LOG_DIR/submission-log.json\""
    fi
    echo "Notary diagnostics directory: $RUN_LOG_DIR"
    exit 124
fi

if [ "$STATUS" != "Accepted" ]; then
    echo "Notarization failed with status: ${STATUS:-unknown}"
    run_notary_log "$SUBMISSION_ID" || true
    echo "Inspect the detailed log with:"
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        echo "  xcrun notarytool log $SUBMISSION_ID --keychain-profile \"$NOTARY_PROFILE\""
    else
        echo "  xcrun notarytool log $SUBMISSION_ID --apple-id \"$APPLE_ID\" --team-id \"$APPLE_TEAM_ID\" --password \"<app-specific-password>\""
    fi
    echo "Notary diagnostics directory: $RUN_LOG_DIR"
    exit 1
fi

run_notary_log "$SUBMISSION_ID" || true

echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_FILE"
xcrun stapler validate "$DMG_FILE"

echo "Checking Gatekeeper assessment..."
spctl -a -vvv -t open --context context:primary-signature "$DMG_FILE"

echo "Notary diagnostics directory: $RUN_LOG_DIR"
