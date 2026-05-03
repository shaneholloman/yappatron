# Core Constraints

## What This Is

Voice dictation for macOS, now with a working iPhone companion spike. Always-on by default on macOS, with optional push-to-talk for noisy environments.

## Architecture (Non-Negotiable)

- **Pure Swift** — No Python in production. Python code in `packages/core/` is dormant prototype.
- **Single process** — Menu bar app, no daemon, no WebSocket bridge.
- **Local-first direction** — On-device inference is the target, especially for mobile. Deepgram exists as a working cloud backend/prototype path, but avoid making cloud the only long-term path.
- **Neural Engine** — Local ASR should run on ANE/Core ML for efficiency where possible, not GPU.
- **iOS constraints** — iPhone apps cannot do macOS-style global keystroke injection. Type-anywhere behavior requires a custom keyboard extension or pasteboard-driven workflow.

## Tech Stack

| Layer | Technology | License |
|-------|------------|---------|
| App | Swift 5.9+, SwiftUI | — |
| ASR | FluidAudio (StreamingEouAsrManager) | Apache 2.0 |
| Model | Parakeet EOU 120M (CoreML) | MIT/Apache 2.0 |
| Hotkeys | soffes/HotKey | MIT |
| Hosting | Cloudflare Pages | — |
| iOS app | SwiftUI + custom keyboard extension | — |

## Critical Patterns

### Streaming ASR Flow
```
Mic → 16kHz resample → 160ms chunks → FluidAudio → partialCallback/eouCallback
```

### Ghost Text Diffing
Partials are cumulative ("hello" → "hello wor" → "hello world"). `InputSimulator.applyTextUpdate()` diffs old vs new, backspaces divergent suffix, types new suffix. Only backspaces if model revises mid-stream.

### EOU Semantics
Model is semantically aware. Complete thoughts finalize fast. Fragments wait for continuation.

## Licensing Constraint

**All permissive.** Do NOT use FluidAudioTTS — it includes GPL ESpeakNG.

## File Locations (Mac)

```
~/Workspace/yappatron/packages/app/Yappatron/  # Swift app
~/Workspace/yappatron/packages/ios/YappatronIOS/  # iPhone app + keyboard extension
~/Library/Application Support/FluidAudio/Models/  # Downloaded models
```
