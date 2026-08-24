# Entrevoix iOS

The iOS and iPadOS client for Entrevoix. It is a SwiftUI application targeting
iOS 26 and currently provides the application composition root plus persistent
configuration for shared dictation and cleanup features.

The product architecture is a custom keyboard extension paired with a
containing application. The app owns microphone recording and transcription;
the keyboard owns the system-wide text-entry surface and inserts completed
dictation. See [the keyboard-dictation architecture](docs/keyboard-dictation-architecture.md)
for the handoff protocol and its iOS lifecycle constraints.

The project includes the `EntrevoixKeyboard` extension target. It provides the
dictation surface, a manual keyboard fallback, the required next-keyboard
control, and the App Group handoff contract. The containing app's background
recording/transcription service is the next implementation step.

## Shared package

The Xcode project pins
[`EntrevoixShared`](https://github.com/entrevoix-app/entrevoix-shared) to
version `0.1.0` and links its three public products:

- `EntrevoixCore` for preferences and provider-domain models;
- `EntrevoixAppleAdapters` for `UserDefaults` persistence and secure Keychain
  storage;
- `EntrevoixOpenAIAdapters` for the forthcoming remote transcription and
  cleanup composition.

For local coordinated development, open `Entrevoix.xcodeproj`, select the
`EntrevoixShared` package in Xcode, then use **File → Packages → Edit Package**
to point it at the sibling `entrevoix-shared` checkout. Before committing,
unedit the package and keep the declared version pin.

## Build

Open `Entrevoix.xcodeproj` in Xcode 26 or newer, choose an iPhone or iPad
simulator, and run the `Entrevoix` scheme. Set a development team before
running on a physical device. Before signing, register the App Group
`group.app.entrevoix.ios` for both the app and `EntrevoixKeyboard` targets in
the Apple Developer portal.

## License

Entrevoix iOS is distributed under the MIT License. See [LICENSE](LICENSE).
