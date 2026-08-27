# Gates: iOS provider catalogue

OWNS: Entrevoix/PreferencesView.swift, Entrevoix/PreferencesModel.swift, Entrevoix/EntrevoixApp.swift, Entrevoix/CleanupLibraryCloudSync.swift, Entrevoix/CleanupLibraryPushHandler.swift, Entrevoix/Localizable.xcstrings, Entrevoix/Assets.xcassets/**, EntrevoixTests/PreferencesModelTests.swift

Scope: provide the provider catalogue and keep CloudKit-optional startup safe on the simulator.

- [x] G1: provider model behavior is covered by the iOS unit-test suite
  CHECK: simulator_id="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"; xcodebuild test -quiet -project Entrevoix.xcodeproj -scheme Entrevoix -destination "id=$simulator_id" CODE_SIGNING_ALLOWED=NO && printf 'provider test verification passed\n'
  EXPECT: provider test verification passed
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/d9beud/Documents/Repositories/entrevoix/entrevoix-ios; path=677d46ecdfd2/23 entries; EXPECT=matched; output-sha256=39aac7c5a3bb983059ed2e8a2763113dc8554765f694b33aa8e4604c55e88f09; output-bytes=2586

- [x] G2: the application compiles with its bundled vector resources
  CHECK: simulator_id="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"; xcodebuild build -quiet -project Entrevoix.xcodeproj -scheme Entrevoix -destination "id=$simulator_id" CODE_SIGNING_ALLOWED=NO && printf 'provider build verification passed\n'
  EXPECT: provider build verification passed
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/d9beud/Documents/Repositories/entrevoix/entrevoix-ios; path=677d46ecdfd2/23 entries; EXPECT=matched; output-sha256=0b6717f8b7b3a5ab6145827ea85d704ea8a116b6e4225dbcae4aedb7926887cf; output-bytes=35

- [x] G3: the provider catalogue is manually reviewed for compact and regular navigation structures
  EVIDENCE: 2026-08-27: iPhone 17 Pro (iOS 26.5) screenshot confirms the single top-trailing plus toolbar action and no text add button; source review confirms the same unconditioned toolbar is hosted by both NavigationStack and NavigationSplitView paths, and G2 confirms both SVG assets are compiled.

- [x] G4: an unsigned simulator build launches without a CloudKit entitlement crash
  CHECK: simulator_id="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"; target_build_dir="$(xcodebuild -project Entrevoix.xcodeproj -scheme Entrevoix -destination "id=$simulator_id" -showBuildSettings CODE_SIGNING_ALLOWED=NO | awk -F ' = ' '/ TARGET_BUILD_DIR =/{print $2; exit}')"; xcodebuild build -quiet -project Entrevoix.xcodeproj -scheme Entrevoix -destination "id=$simulator_id" CODE_SIGNING_ALLOWED=NO && xcrun simctl install "$simulator_id" "$target_build_dir/Entrevoix.app" && launch_output="$(xcrun simctl launch "$simulator_id" app.entrevoix.ios)" && launch_pid="${launch_output##*: }" && sleep 2 && kill -0 "$launch_pid" && printf 'simulator launch verification passed\n'
  EXPECT: simulator launch verification passed
  EVIDENCE: exit=0; shell=/bin/sh; cwd=/Users/d9beud/Documents/Repositories/entrevoix/entrevoix-ios; path=677d46ecdfd2/23 entries; EXPECT=matched; output-sha256=f1e982266c30e89921052f9b6c980fc5432d674ba443986b0a1e397167210e27; output-bytes=37
