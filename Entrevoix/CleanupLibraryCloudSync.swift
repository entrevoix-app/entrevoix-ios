import CloudKit
import EntrevoixCore
import Foundation

@MainActor
final class CleanupLibraryCloudSync {
    var onRemoteLibrary: ((CleanupLibrary) -> Void)?

    private let store: any CleanupLibraryCloudStoring
    private var syncTask: Task<Void, Never>?

    init(store: any CleanupLibraryCloudStoring = CloudKitCleanupLibraryStore()) {
        self.store = store
    }

    deinit {
        syncTask?.cancel()
    }

    func start() {
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self, store] in
            do {
                let library = try await store.fetchLibrary()
                guard !Task.isCancelled, let library else { return }
                self?.onRemoteLibrary?(library)
            } catch {
                // The macOS app remains the publisher. A transient CloudKit failure
                // must leave the iOS device's local library intact.
            }
        }
    }
}

@MainActor
protocol CleanupLibraryCloudStoring {
    func fetchLibrary() async throws -> CleanupLibrary?
}

@MainActor
final class CloudKitCleanupLibraryStore: CleanupLibraryCloudStoring {
    private static let containerIdentifier = "iCloud.app.entrevoix.shared"
    private static let recordType = "CleanupLibrary"
    private static let recordName = "library-v1"
    private static let payloadKey = "payload"

    private let database: CKDatabase

    init() {
        database = CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase
    }

    init(database: CKDatabase) {
        self.database = database
    }

    func fetchLibrary() async throws -> CleanupLibrary? {
        let recordID = CKRecord.ID(recordName: Self.recordName)
        do {
            let record = try await database.record(for: recordID)
            guard let payload = record[Self.payloadKey] as? Data else { return nil }
            return try JSONDecoder().decode(CleanupLibrary.self, from: payload)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }
}

struct CleanupLibrary: Codable, Equatable, Sendable {
    let prompts: [CleanupPrompt]
    let workflows: [CleanupWorkflow]
}
