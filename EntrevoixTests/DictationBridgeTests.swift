@testable import Entrevoix
import Foundation
import Testing

@Suite("Dictation bridge")
@MainActor
struct DictationBridgeTests {
    @Test("An unsupported keyboard command is rejected without starting a session")
    func unsupportedRequestIsRejected() {
        let request = KeyboardDictationRequest(version: KeyboardDictationRequest.currentVersion + 1)
        KeyboardHandoffStore.writeRequest(request)
        let bridge = DictationBridge(preferences: PreferencesModel())

        bridge.handle(url: URL(string: "entrevoix://dictation/start")!)

        #expect(KeyboardHandoffStore.readResult()?.requestID == request.id)
        #expect(KeyboardHandoffStore.readResult()?.state == .failed)
        #expect(bridge.state == .idle)
        KeyboardHandoffStore.clearHandoff(for: request.id)
    }

    @Test("A missing provider returns an actionable keyboard failure")
    func missingProviderFailsBeforeRecording() {
        let request = KeyboardDictationRequest()
        KeyboardHandoffStore.writeRequest(request)
        let bridge = DictationBridge(preferences: PreferencesModel())

        bridge.handle(url: URL(string: "entrevoix://dictation/start")!)

        #expect(KeyboardHandoffStore.readResult()?.requestID == request.id)
        #expect(KeyboardHandoffStore.readResult()?.state == .failed)
        #expect(KeyboardHandoffStore.readResult()?.message?.isEmpty == false)
        #expect(KeyboardHandoffStore.readRequest()?.id == request.id)
        #expect(bridge.state != .recording)
        KeyboardHandoffStore.clearHandoff(for: request.id)
    }
}
