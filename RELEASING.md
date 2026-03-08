# CiteBar Release Guide (Maintainers)

This document is for maintainers publishing a new release.

## One-Time Sparkle Signing Setup

To make automatic updates pass signature validation:

```bash
# Ensure Sparkle source checkout exists
make build

# 1) Build Sparkle key tool
xcodebuild -project .build/checkouts/Sparkle/Sparkle.xcodeproj \
  -scheme generate_keys \
  -configuration Release \
  -derivedDataPath .build/sparkle-tools \
  CODE_SIGNING_ALLOWED=NO

# 2) Generate key in login keychain (or print existing public key)
.build/sparkle-tools/Build/Products/Release/generate_keys
PUBLIC_KEY=$(.build/sparkle-tools/Build/Products/Release/generate_keys -p)

# 3) Export private key to a local file (do NOT commit this file)
mkdir -p .sparkle
.build/sparkle-tools/Build/Products/Release/generate_keys -x .sparkle/private_ed_key.txt
```

Configure repository settings:

- `Variable` (or `Secret`): `SPARKLE_PUBLIC_ED_KEY=$PUBLIC_KEY`
- `Secret`: `SPARKLE_PRIVATE_KEY=<contents of .sparkle/private_ed_key.txt>`

Using GitHub CLI:

```bash
gh variable set SPARKLE_PUBLIC_ED_KEY --body "$PUBLIC_KEY"
gh secret set SPARKLE_PRIVATE_KEY < .sparkle/private_ed_key.txt
```

After setup, release workflow will:

- write `SUPublicEDKey` into app `Info.plist`
- sign DMG via `sign_update`
- publish `sparkle:edSignature` into `appcast.xml`

## Publish a Release

```bash
git switch main
git pull --ff-only
git push origin main
git tag v1.x.y
git push origin v1.x.y
```

## Verify Release Outputs

```bash
gh run list --workflow Release --limit 3
curl -fsSL https://github.com/hichipli/CiteBar/releases/latest/download/appcast.xml \
  | grep -E "sparkle:edSignature|sparkle:shortVersionString|sparkle:version"
```
