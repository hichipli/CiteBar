# Apple Developer ID Distribution Setup

This project distributes CiteBar outside the Mac App Store. The production release path is:

1. Build a universal macOS app bundle.
2. Sign the app and embedded Sparkle framework with a `Developer ID Application` certificate.
3. Create the drag-to-Applications DMG.
4. Sign the DMG container with the same `Developer ID Application` certificate.
5. Submit the DMG to Apple's notary service with `notarytool`.
6. Staple the notarization ticket to the DMG.
7. Publish the notarized DMG and Sparkle appcast on GitHub Releases.

Apple references:

- [Signing Mac Software with Developer ID](https://developer.apple.com/developer-id/)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [TN3147: Migrating to the latest notarization tool](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool)

## What You Need From Apple

You need these values and credentials. Do not commit private keys, `.p12` files, or app-specific passwords.

| Name | Where to get it | Used as |
| --- | --- | --- |
| Apple ID email | Apple Developer account login | `APPLE_ID` |
| Team ID | Apple Developer account membership page | `APPLE_TEAM_ID` |
| Developer ID Application identity | Keychain Access after importing the certificate | `DEVELOPER_ID_APPLICATION` |
| Developer ID Application `.p12` | Export from Keychain Access | `MACOS_CERTIFICATE_P12` |
| `.p12` export password | You choose this during export | `MACOS_CERTIFICATE_PASSWORD` |
| App-specific password | appleid.apple.com account security settings | `APP_SPECIFIC_PASSWORD` |
| Sparkle public/private EdDSA keys | Existing `RELEASING.md` Sparkle setup | `SPARKLE_PUBLIC_ED_KEY`, `SPARKLE_PRIVATE_KEY` |

The signing identity must look like:

```text
Developer ID Application: Your Legal Name or Company Name (TEAMID1234)
```

## Apple Developer Portal Setup

1. Sign in to <https://developer.apple.com/account/>.
2. Confirm the membership is active and you can access Certificates, Identifiers & Profiles.
3. Create or download a `Developer ID Application` certificate:
   - Open Certificates, Identifiers & Profiles.
   - Add a certificate.
   - Choose `Developer ID Application`.
   - If Apple asks for a CSR, create one in Keychain Access using Certificate Assistant.
   - Download the generated `.cer` file.
   - Double-click it so it imports into your login keychain.
4. In Keychain Access, find the certificate and verify it has a private key under it.
5. Export it as a `.p12`:
   - Select the certificate and private key.
   - File > Export Items.
   - Format: Personal Information Exchange (`.p12`).
   - Set a strong export password and save it somewhere secure.
6. Create an app-specific password:
   - Go to <https://appleid.apple.com/>.
   - Sign-In and Security > App-Specific Passwords.
   - Generate one named `CiteBar Notarization`.

## Local Machine Setup

Install or update Xcode from the Mac App Store, then make sure command line tools use that Xcode:

```bash
xcode-select -p
xcodebuild -version
xcrun notarytool --help
```

Store notarization credentials in your local keychain:

```bash
xcrun notarytool store-credentials "CiteBar Notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID1234"
```

When prompted, paste the app-specific password.

Find the exact signing identity:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

Build, sign, notarize, and staple locally:

```bash
make notarize \
  SIGN_IDENTITY="Developer ID Application: Your Legal Name (TEAMID1234)" \
  NOTARY_PROFILE="CiteBar Notary"
```

The final DMG will be in `dist/`.

## GitHub Secrets Setup

Base64-encode the `.p12` for GitHub Actions:

```bash
base64 -i DeveloperIDApplication.p12 -o DeveloperIDApplication.p12.base64
```

Configure these GitHub repository secrets:

```bash
gh secret set DEVELOPER_ID_APPLICATION --body "Developer ID Application: Your Legal Name (TEAMID1234)"
gh secret set MACOS_CERTIFICATE_P12 < DeveloperIDApplication.p12.base64
gh secret set MACOS_CERTIFICATE_PASSWORD --body "your-p12-export-password"
gh secret set APPLE_ID --body "you@example.com"
gh secret set APPLE_TEAM_ID --body "TEAMID1234"
gh secret set APP_SPECIFIC_PASSWORD --body "xxxx-xxxx-xxxx-xxxx"
```

Optional, only if you want to control the temporary CI keychain password:

```bash
gh secret set KEYCHAIN_PASSWORD --body "a-long-random-temporary-keychain-password"
```

Sparkle secrets are still required:

```bash
gh variable set SPARKLE_PUBLIC_ED_KEY --body "your-public-ed-key"
gh secret set SPARKLE_PRIVATE_KEY < .sparkle/private_ed_key.txt
```

## Release

After the secrets are configured, the existing release workflow will sign, notarize, staple, generate the Sparkle appcast, and publish the release when a version tag is pushed:

```bash
git tag v1.x.y
git push origin v1.x.y
```

You can also start the workflow manually from GitHub Actions and provide the version.

## Verification

For a local DMG:

```bash
codesign --verify --verbose=4 dist/CiteBar-*.dmg
xcrun stapler validate dist/CiteBar-*.dmg
spctl -a -vvv -t open --context context:primary-signature dist/CiteBar-*.dmg
```

For the app bundle before DMG creation:

```bash
codesign --verify --strict --deep --verbose=2 dist/CiteBar.app
codesign -dv --verbose=4 dist/CiteBar.app
spctl -a -vvv -t exec dist/CiteBar.app
```

Expected outcome:

- `codesign` verification succeeds.
- `spctl` shows accepted Developer ID assessment for the signed DMG.
- `stapler validate` confirms the ticket is attached.
- A fresh Mac can open the downloaded DMG, drag CiteBar to Applications, and launch without Terminal commands.

## Notarization Diagnostics

The notarization script writes diagnostics for every submission under:

```bash
dist/notary-logs/
```

Each run gets its own timestamped directory and `dist/notary-logs/latest` points to the newest run. Important files:

- `submit.json`: the upload response with the Apple submission ID.
- `submission-id.txt`: the Apple submission ID only.
- `poll-001.json`, `poll-002.json`, etc.: every status response from `notarytool info`.
- `latest-info.json`: the newest status response.
- `submission-log.json`: the Apple notary submission log, when Apple makes it available.
- `signing-diagnostics.txt`: GitHub Actions signing checks before notarization.

If notarization is slow, check the current status:

```bash
SUBMISSION_ID=$(cat dist/notary-logs/latest/submission-id.txt)
xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "CiteBar Notary"
```

If notarization fails or remains stuck long enough to contact Apple Developer Support, collect:

```bash
SUBMISSION_ID=$(cat dist/notary-logs/latest/submission-id.txt)
xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "CiteBar Notary" \
  "dist/notary-logs/latest/submission-log.json"
```

When contacting Apple Developer Support, include:

- Team ID.
- Submission ID.
- DMG filename.
- `latest-info.json`.
- `submission-log.json`, if available.
- A short note that this is a Developer ID notarization submission using `notarytool`.

Apple's Notary API also exposes a submission-log endpoint; `xcrun notarytool log` is the local CLI wrapper around the same diagnostic information.

In GitHub Actions, the release workflow uploads `notarization-diagnostics-*` as an artifact even if the notarization step fails or times out. Download that artifact from the failed workflow run before rerunning the release.

## Information To Provide To A Maintainer

Provide only these non-secret values in chat:

- `APPLE_TEAM_ID`
- Exact `DEVELOPER_ID_APPLICATION` string
- Whether you want releases built locally or by GitHub Actions

Provide these only through GitHub Secrets or another secure channel:

- `MACOS_CERTIFICATE_P12`
- `MACOS_CERTIFICATE_PASSWORD`
- `APP_SPECIFIC_PASSWORD`
- `SPARKLE_PRIVATE_KEY`
