# Tech Stack

## Production (Swift App)

| Component | Technology | Purpose |
|-----------|------------|---------|
| Language | Swift 5.9+ | Native Apple apps |
| UI | SwiftUI | Menu bar + overlay |
| Audio | AVFoundation | Mic capture, resampling |
| ASR | FluidAudio | Streaming transcription |
| Input | CGEvent | Keystroke injection |
| Hotkeys | HotKey | Global shortcuts |

## iPhone Spike

| Component | Technology | Purpose |
|-----------|------------|---------|
| Project | `packages/ios/YappatronIOS/YappatronIOS.xcodeproj` | Native iOS app + keyboard extension |
| App UI | SwiftUI | API key field, record/stop, transcript, copy/share |
| Audio | AVFoundation / AVAudioApplication | iPhone microphone capture and 16 kHz conversion |
| Cloud ASR | Deepgram Nova-3 WebSocket | Current iOS transcription backend |
| Type-anywhere bridge | Custom keyboard extension + `UIPasteboard` | Inserts latest Yappatron-tagged transcript into active text field |
| Signing | Free Xcode Personal Team | Direct install to connected test iPhone; no paid Developer Program required |

### iPhone Build Notes

- Installed and launched on a connected test iPhone on 2026-05-02 using free Personal Team signing.
- The production-clean App Group bridge was removed for the free-device build because App Groups require registered provisioning capabilities.
- Current bridge writes a Yappatron-tagged, local-only pasteboard item with an 8-hour expiration. The keyboard requires Allow Full Access to read it.
- First install required iPhone Developer Mode and trusting the free developer profile in Settings.
- The ASAP CLI install bypassed the asset catalog at build time because Xcode still wanted the full iOS 26.4 platform/runtime component for asset compilation. The project still contains real icons for normal Xcode builds once that component is installed.
- Free Personal Team installs expire periodically; rebuild/reinstall when iOS stops launching the app.

## Models

| Model | Size | Latency | Use |
|-------|------|---------|-----|
| Parakeet EOU 120M | ~250MB | 160ms | Streaming ASR |

Models auto-download to `~/Library/Application Support/FluidAudio/Models/`

## Website

| Component | Technology |
|-----------|------------|
| Framework | Astro 4 |
| Styling | Custom CSS (RGB orb, light/dark mode) |
| Hosting | Cloudflare Pages |
| Project | `yappatron` |
| URL | https://yappatron.pages.dev |

### Website Deployment (from VPS)

**IMPORTANT:** The Cloudflare Pages project name is `yappatron` (not `yappa` or anything else from wrangler.toml).

```bash
cd /home/alex/code/yappatron/packages/website
npm run build
CLOUDFLARE_API_TOKEN=$(cat ~/.config/cloudflare/pages-token) npx wrangler pages deploy dist --project-name yappatron
```

### Local Development

```bash
cd /home/alex/code/yappatron/packages/website
npm run dev
# Runs on http://localhost:4321
# SSH tunnel: ssh -L 4321:localhost:4321 tiny-bat
```

## Development (Mac)

```bash
# Build
swift build

# Run dev script
./scripts/run-dev.sh
```

## Development (iPhone)

```bash
# From repo root; TEAM is local-only and must not be committed.
TEAM=$(awk -F'= ' '/DEVELOPMENT_TEAM = [A-Z0-9]+;/ {gsub(/;/,"",$2); print $2; exit}' packages/ios/YappatronIOS/YappatronIOS.xcodeproj/project.pbxproj)

xcodebuild -project packages/ios/YappatronIOS/YappatronIOS.xcodeproj \
  -target YappatronIOS \
  -configuration Debug \
  -sdk iphoneos \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM" \
  EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets \
  ASSETCATALOG_COMPILER_APPICON_NAME= \
  ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME= \
  build

xcrun devicectl device install app --device "<device name>" \
  packages/ios/YappatronIOS/build/Debug-iphoneos/Yappatron.app

xcrun devicectl device process launch --device "<device name>" --terminate-existing com.yappatron.ios
```

## Dormant (Python Prototype)

Not used in production. Kept for reference.

- faster-whisper (batch ASR)
- silero-vad (VAD)
- speechbrain (speaker ID)
- pynput (keystrokes)
