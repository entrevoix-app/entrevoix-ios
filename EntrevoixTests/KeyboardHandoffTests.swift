@testable import Entrevoix
import Foundation
import Testing

@Suite("Keyboard handoff")
@MainActor
struct KeyboardHandoffTests {
    @Test("A request preserves its supplied identity and creation date")
    func requestPreservesIdentityAndCreationDate() {
        let id = UUID(uuidString: "7E5BDBE3-3A4A-4672-AF6A-68C6EE45C97A")!
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        let request = KeyboardDictationRequest(id: id, createdAt: createdAt)

        #expect(request.id == id)
        #expect(request.createdAt == createdAt)
    }

    @Test("A completed result retains its transcript")
    func completedResultRetainsTranscript() {
        let requestID = UUID(uuidString: "D1431981-5181-4FE5-894D-7829C900E691")!
        let result = KeyboardDictationResult(
            requestID: requestID,
            state: .completed,
            transcript: "Bonjour"
        )

        #expect(result.requestID == requestID)
        #expect(result.state == .completed)
        #expect(result.transcript == "Bonjour")
        #expect(result.message == nil)
    }

    @Test("Requests and results round-trip through the shared handoff store")
    func handoffStoreRoundTrip() {
        let request = KeyboardDictationRequest()
        let result = KeyboardDictationResult(
            requestID: request.id,
            state: .completed,
            transcript: "Bonjour"
        )

        KeyboardHandoffStore.writeRequest(request)
        KeyboardHandoffStore.writeResult(result)

        #expect(KeyboardHandoffStore.readRequest() == request)
        #expect(KeyboardHandoffStore.readResult() == result)
    }

    @Test("Clearing a result only removes the matching request result")
    func clearResultOnlyRemovesMatchingRequest() {
        let requestID = UUID()
        let result = KeyboardDictationResult(requestID: requestID, state: .failed)
        KeyboardHandoffStore.writeResult(result)

        KeyboardHandoffStore.clearResult(for: UUID())
        #expect(KeyboardHandoffStore.readResult() == result)

        KeyboardHandoffStore.clearResult(for: requestID)
        #expect(KeyboardHandoffStore.readResult() == nil)
    }
}
