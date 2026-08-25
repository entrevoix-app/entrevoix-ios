import CloudKit
import EntrevoixCore
import Foundation

@MainActor
final class CleanupLibraryCloudSync {
    static let subscriptionID = "cleanup-library-v2-ios"

    var onRemoteLibrary: ((CleanupLibrary) -> Void)?

    private let store: any CleanupLibraryCloudStoring
    private var lastLibrary: CleanupLibrary?
    private var syncTask: Task<Void, Never>?
    private var publishTask: Task<Void, Never>?

    init(store: any CleanupLibraryCloudStoring = CloudKitCleanupLibraryStore()) {
        self.store = store
    }

    deinit {
        syncTask?.cancel()
        publishTask?.cancel()
    }

    func start(with localLibrary: CleanupLibrary, seedLocalLibrary: Bool) {
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self, store] in
            do {
                try await store.ensureSubscription(id: Self.subscriptionID)
                let library = try await store.bootstrap(localLibrary: localLibrary, seedLocalLibrary: seedLocalLibrary)
                guard !Task.isCancelled else { return }
                self?.lastLibrary = library
                self?.onRemoteLibrary?(library)
            } catch {
                // CloudKit is optional. A later activation retries without
                // discarding the device-local library.
            }
        }
    }

    func publish(_ library: CleanupLibrary) {
        publishTask?.cancel()
        let previousLibrary = lastLibrary
        publishTask = Task { @MainActor [weak self, store] in
            do {
                let replacement = if let previousLibrary { previousLibrary } else { try await store.fetchLibrary() }
                try await store.saveLibrary(library, replacing: replacement)
                guard !Task.isCancelled else { return }
                self?.lastLibrary = library
            } catch {
                // Local persistence already succeeded. Retain it and retry on
                // the next edit or activation.
            }
        }
    }

    func refresh() {
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self, store] in
            do {
                guard let library = try await store.fetchLibrary(), !Task.isCancelled else { return }
                self?.lastLibrary = library
                self?.onRemoteLibrary?(library)
            } catch {
                // A push is only a hint. A later lifecycle refresh catches up.
            }
        }
    }
}

@MainActor
protocol CleanupLibraryCloudStoring {
    func bootstrap(localLibrary: CleanupLibrary, seedLocalLibrary: Bool) async throws -> CleanupLibrary
    func fetchLibrary() async throws -> CleanupLibrary?
    func saveLibrary(_ library: CleanupLibrary, replacing previousLibrary: CleanupLibrary?) async throws
    func ensureSubscription(id: String) async throws
}

@MainActor
final class CloudKitCleanupLibraryStore: CleanupLibraryCloudStoring {
    private static let containerIdentifier = "iCloud.app.entrevoix.shared"
    private static let legacyRecordType = "CleanupLibrary"
    private static let legacyRecordName = "library-v1"
    private static let itemRecordType = "CleanupLibraryItemV2"
    private static let markerRecordName = "library-v2"
    private static let payloadKey = "payload"
    private static let kindKey = "kind"
    private static let orderKey = "order"
    private static let tombstoneKey = "tombstone"

    private let database: CKDatabase

    init() {
        database = CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase
    }

    init(database: CKDatabase) {
        self.database = database
    }

    func bootstrap(localLibrary: CleanupLibrary, seedLocalLibrary: Bool) async throws -> CleanupLibrary {
        if let library = try await fetchV2Library() { return library }
        if let legacyLibrary = try await fetchLegacyLibrary() {
            try await saveLibrary(legacyLibrary, replacing: nil)
            return legacyLibrary
        }
        if seedLocalLibrary {
            try await saveLibrary(localLibrary, replacing: nil)
        }
        return localLibrary
    }

    func fetchLibrary() async throws -> CleanupLibrary? {
        try await fetchV2Library()
    }

    func saveLibrary(_ library: CleanupLibrary, replacing previousLibrary: CleanupLibrary?) async throws {
        var records = [markerRecord()]
        let previousPrompts = Dictionary(uniqueKeysWithValues: (previousLibrary?.prompts ?? []).map { ($0.id, $0) })
        let previousWorkflows = Dictionary(uniqueKeysWithValues: (previousLibrary?.workflows ?? []).map { ($0.id, $0) })
        let currentPromptIDs = Set(library.prompts.map(\.id))
        let currentWorkflowIDs = Set(library.workflows.map(\.id))

        for (index, prompt) in library.prompts.enumerated() where previousPrompts[prompt.id] != prompt || previousLibrary == nil {
            records.append(try itemRecord(prompt, order: index))
        }
        for (index, workflow) in library.workflows.enumerated() where previousWorkflows[workflow.id] != workflow || previousLibrary == nil {
            records.append(try itemRecord(workflow, order: index))
        }
        for id in Set(previousPrompts.keys).subtracting(currentPromptIDs) {
            records.append(tombstoneRecord(kind: .prompt, id: id))
        }
        for id in Set(previousWorkflows.keys).subtracting(currentWorkflowIDs) {
            records.append(tombstoneRecord(kind: .workflow, id: id))
        }
        _ = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys, atomically: false)
    }

    func ensureSubscription(id: String) async throws {
        do {
            _ = try await database.subscription(for: CKSubscription.ID(id))
            return
        } catch let error as CKError {
            guard error.code == .unknownItem else { throw error }
        }
        let subscription = CKQuerySubscription(
            recordType: Self.itemRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: CKSubscription.ID(id),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        _ = try await database.save(subscription)
    }

    private func fetchV2Library() async throws -> CleanupLibrary? {
        let query = CKQuery(recordType: Self.itemRecordType, predicate: NSPredicate(value: true))
        let (results, _) = try await database.records(matching: query)
        var didFindMarker = false
        var prompts = [(Int, CleanupPrompt)]()
        var workflows = [(Int, CleanupWorkflow)]()

        for (_, result) in results {
            let record = try result.get()
            if record.recordID.recordName == Self.markerRecordName {
                didFindMarker = true
                continue
            }
            guard record[Self.tombstoneKey] as? Bool != true,
                  let rawKind = record[Self.kindKey] as? String,
                  let kind = ItemKind(rawValue: rawKind),
                  let payload = record[Self.payloadKey] as? Data else { continue }
            let order = record[Self.orderKey] as? Int ?? Int.max
            switch kind {
            case .prompt:
                prompts.append((order, try JSONDecoder().decode(CleanupPrompt.self, from: payload)))
            case .workflow:
                workflows.append((order, try JSONDecoder().decode(CleanupWorkflow.self, from: payload)))
            }
        }
        guard didFindMarker else { return nil }
        return CleanupLibrary(
            prompts: prompts.sorted { $0.0 == $1.0 ? $0.1.id.uuidString < $1.1.id.uuidString : $0.0 < $1.0 }.map(\.1),
            workflows: workflows.sorted { $0.0 == $1.0 ? $0.1.id.uuidString < $1.1.id.uuidString : $0.0 < $1.0 }.map(\.1)
        )
    }

    private func fetchLegacyLibrary() async throws -> CleanupLibrary? {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: Self.legacyRecordName))
            guard record.recordType == Self.legacyRecordType,
                  let payload = record[Self.payloadKey] as? Data else { return nil }
            return try JSONDecoder().decode(CleanupLibrary.self, from: payload)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func markerRecord() -> CKRecord {
        CKRecord(recordType: Self.itemRecordType, recordID: CKRecord.ID(recordName: Self.markerRecordName))
    }

    private func itemRecord(_ prompt: CleanupPrompt, order: Int) throws -> CKRecord {
        try itemRecord(kind: .prompt, id: prompt.id, payload: JSONEncoder().encode(prompt), order: order)
    }

    private func itemRecord(_ workflow: CleanupWorkflow, order: Int) throws -> CKRecord {
        try itemRecord(kind: .workflow, id: workflow.id, payload: JSONEncoder().encode(workflow), order: order)
    }

    private func itemRecord(kind: ItemKind, id: UUID, payload: Data, order: Int) -> CKRecord {
        let record = CKRecord(recordType: Self.itemRecordType, recordID: CKRecord.ID(recordName: "\(kind.rawValue):\(id.uuidString)"))
        record[Self.kindKey] = kind.rawValue as CKRecordValue
        record[Self.payloadKey] = payload as CKRecordValue
        record[Self.orderKey] = order as CKRecordValue
        record[Self.tombstoneKey] = false as CKRecordValue
        return record
    }

    private func tombstoneRecord(kind: ItemKind, id: UUID) -> CKRecord {
        let record = CKRecord(recordType: Self.itemRecordType, recordID: CKRecord.ID(recordName: "\(kind.rawValue):\(id.uuidString)"))
        record[Self.kindKey] = kind.rawValue as CKRecordValue
        record[Self.tombstoneKey] = true as CKRecordValue
        return record
    }

    private enum ItemKind: String {
        case prompt
        case workflow
    }
}

struct CleanupLibrary: Codable, Equatable, Sendable {
    var prompts: [CleanupPrompt]
    var workflows: [CleanupWorkflow]
}
