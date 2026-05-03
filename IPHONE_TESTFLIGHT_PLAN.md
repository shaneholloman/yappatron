# Yappatron iPhone/TestFlight Plan

Last checked: 2026-05-03

## Current State

Yappatron now has both the existing macOS Swift Package app and a new iOS project scaffold:

- Source: `packages/app/Yappatron`
- Product: macOS executable packaged into `build/Yappatron.app`
- Platform in `Package.swift`: macOS 14+
- Core reusable pieces: microphone capture, AVFoundation audio flow, `STTProvider`, `DeepgramSTTProvider`, and likely some FluidAudio local ASR code
- macOS-only pieces: AppKit menu bar app, overlay windows, `HotKey`, Accessibility permissions, `CGEvent` keystroke injection, and focused text input detection
- iOS project: `packages/ios/YappatronIOS/YappatronIOS.xcodeproj`
- iOS app target: `YappatronIOS`
- iOS keyboard extension target: `YappatronKeyboard`
- iOS App Group bridge: `group.com.yappatron.shared`
- iOS MVP behavior: the containing app records/transcribes with Deepgram, then the keyboard extension inserts the latest synced transcript into the active text field

This machine currently has Swift command-line tools, but not full Xcode selected:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

That means I cannot create, sign, run, archive, or upload an iPhone build from here yet.

## Important iOS Constraint

The macOS product behavior cannot be copied directly to iPhone. iOS does not allow a normal app to inject keystrokes systemwide like the macOS Accessibility/CGEvent path does.

A custom keyboard extension is not a clean workaround for voice dictation either: Apple's custom keyboard documentation says custom keyboards have no access to the device microphone, so dictation input is not possible inside the keyboard extension itself.

Official reference:
https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html

## Implemented iOS Direction

The iOS implementation follows the industry-standard workaround used by dictation companion apps:

- A foreground containing app owns microphone permission, audio session setup, Deepgram streaming, and transcript storage.
- The containing app declares background audio mode so a live recording session can continue while the user switches apps, subject to iOS suspension/termination behavior.
- A custom keyboard extension reads the latest transcript from an App Group and inserts it into the current text field with `textDocumentProxy.insertText`.
- The keyboard does not access the microphone and does not need network access for the current MVP.
- The app includes an optional one-shot auto-insert behavior when the keyboard opens with a newly updated transcript.

This is not macOS-style global event injection. It is the supported iOS custom-keyboard insertion model.

## Options

### Option A: Direct-Install iPhone MVP With Keyboard Companion

Build the iOS app and keyboard extension, run it directly on a device, start recording in Yappatron, switch apps, and use the Yappatron keyboard to insert the transcript.

This is the fastest way to get a real app running on an iPhone. Apple says a free Apple developer account can test apps directly on your own devices using Xcode, but TestFlight requires Apple Developer Program membership.

Current first version:

- SwiftUI iOS app target
- Microphone permission
- Background audio mode declaration
- Start/stop dictation button in containing app
- Live transcript view
- Copy transcript button
- Share sheet
- Custom keyboard extension for text insertion
- App Group transcript bridge
- Deepgram backend first, because it avoids local model download/app size issues
- Local FluidAudio/Parakeet as a second pass once the iOS shell is running

Pros:

- Fastest path to your phone
- Provides the actual iOS-compatible type-anywhere surface
- Avoids TestFlight until direct-device behavior is proven
- Reuses the existing Deepgram streaming approach with iOS-specific audio/session code

Cons:

- The user still has to start/keep alive the containing app recording session
- iOS may suspend or terminate background recording
- Third-party keyboards are unavailable in secure text fields and some restricted inputs

### Option B: TestFlight iOS MVP

Same app as Option A, then archive and upload it to App Store Connect/TestFlight.

Apple's current TestFlight docs say:

- Builds can be tested for up to 90 days
- External testers can scale up to 10,000 people
- External beta testing may require Beta App Review
- A build must be uploaded to App Store Connect before testers can install it

Official references:

- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/

Requirements:

- Full Xcode installed and selected
- Apple Developer Program membership, currently $99 USD per membership year per Apple docs
- Bundle ID, for example `com.yappatron.ios`
- App Store Connect app record
- Signing team configured in Xcode
- Archive uploaded through Xcode, Transporter, or App Store Connect tooling

Official membership reference:
https://developer.apple.com/programs/

### Option C: Custom Keyboard Companion

Build a containing iOS app plus custom keyboard extension where dictation happens in the containing app and the keyboard can insert the latest transcript.

This is now the chosen first iOS build because type-anywhere behavior is integral to the product.

Pros:

- Closer to "type into other apps" than Option A

Cons:

- Cannot capture microphone audio inside the keyboard extension
- More App Review/privacy risk
- More setup and UX complexity before proving the iOS transcription core

### Option D: PWA/Web Prototype

Build a web page for recording/transcription and save it to the iPhone home screen.

This is not a TestFlight app and should only be used as a throwaway prototype if native setup is blocked.

## Recommended Plan

1. Install and select full Xcode.

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   xcodebuild -version
   ```

2. Open the new iOS project.

   ```bash
   open packages/ios/YappatronIOS/YappatronIOS.xcodeproj
   ```

3. Configure signing.

   Set the development team for both targets, then enable/register `group.com.yappatron.shared` for both `YappatronIOS` and `YappatronKeyboard`.

4. Run directly on your iPhone from Xcode.

   Use a free Apple developer account for personal-device testing if TestFlight is not ready yet.

5. Test type-anywhere behavior.

   Start recording in Yappatron, switch to a text field in another app, select the Yappatron keyboard, and insert the latest transcript.

6. Refactor shared Swift code after the first iPhone run.

   Move cross-platform STT protocol/provider code into a reusable Swift package or shared target. Keep macOS input simulation, hotkeys, and overlay code in the macOS target.

7. Add local FluidAudio on iOS.

   Validate app size, model download behavior, memory use, latency, and Neural Engine/Core ML behavior on the actual phone.

8. Prepare TestFlight.

   Enroll in the Apple Developer Program if needed, create the App Store Connect record, configure `com.yappatron.ios`, add app icon/privacy strings/export-compliance answers, archive, validate, upload, and invite internal testers first.

## Immediate Blockers

- Full Xcode is not installed/selected on this machine.
- I do not have access to an Apple Developer Program team, App Store Connect, signing certificates, or a connected iPhone from this environment.
- iOS cannot support the current macOS-style systemwide keystroke injection behavior.
- The App Group and bundle IDs must be registered under a real Apple team before device/TestFlight signing can succeed.

## Next Concrete Build Task

Install/select full Xcode, open `packages/ios/YappatronIOS/YappatronIOS.xcodeproj`, configure signing/App Group, and run the app on a physical iPhone.
