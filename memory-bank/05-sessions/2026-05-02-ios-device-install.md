# 2026-05-02 iPhone Install Session

## What Happened

- Added and shipped a native iOS project at `packages/ios/YappatronIOS`.
- App target: `YappatronIOS`.
- Keyboard extension target: `YappatronKeyboard`.
- Installed and launched `com.yappatron.ios` on a connected test iPhone using free Xcode Personal Team signing.
- No paid Apple Developer Program membership was required for this personal-device install.

## Mobile Architecture

- The main iOS app owns microphone permission, audio capture, Deepgram streaming, transcript display, copy, and share.
- The keyboard extension inserts text into the active field via `textDocumentProxy.insertText`.
- iOS cannot support macOS-style global keystroke injection, so type-anywhere has to go through a keyboard extension or paste/pasteboard-style workflow.
- Custom keyboards cannot use the microphone directly, so recording/transcription must happen in the containing app.

## Signing And Device Setup

- Full Xcode 26.4.1 was installed and selected.
- iPhone Developer Mode had to be enabled before Xcode/CoreDevice could mount the developer disk image.
- A normal Apple Account was added to Xcode, creating a free Apple Development identity.
- iOS required trusting the developer profile before launching the app.
- Free Personal Team profiles expire periodically; rebuild/reinstall when iOS stops launching the app.

## App Group vs Pasteboard Decision

- Initial implementation used an App Group (`group.com.yappatron.shared`) so the app and keyboard could share transcript state cleanly.
- App Groups require registered provisioning capabilities and are not a good fit for the user's no-paid-membership, ASAP personal-device install.
- Switched to a Yappatron-tagged local `UIPasteboard` item with an 8-hour expiration.
- Keyboard requires Allow Full Access to read the pasteboard.
- This is acceptable for the spike, but App Groups remain the cleaner App Store-quality architecture if paid provisioning is ever used.

## Build Notes

- Code typechecked cleanly for app and keyboard, including app-extension restrictions.
- Standard Xcode Run was blocked by missing iOS 26.4 platform/runtime pieces.
- The successful ASAP device build used CLI overrides to exclude `Assets.xcassets` and skip app icon asset compilation.
- The built app was signed, installed with `devicectl`, and launched successfully after the developer profile was trusted.

## Next

1. Spike local/on-device ASR on iPhone so the app can transcribe without requiring a Deepgram API key.
2. Enable Yappatron Keyboard on iPhone and test insertion into another app.
3. Finish normal Xcode platform/runtime setup later if needed for standard Run workflows and app icon builds.
