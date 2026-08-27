import CloudKit
import Foundation
import UIKit

extension Notification.Name {
    static let cleanupLibraryCloudChange = Notification.Name("cleanupLibraryCloudChange")
    static let dictationDictionaryCloudChange = Notification.Name("dictationDictionaryCloudChange")
}

final class EntrevoixAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification else {
            completionHandler(.noData)
            return
        }
        DispatchQueue.main.async {
            switch notification.subscriptionID {
            case CleanupLibraryCloudSync.subscriptionID: NotificationCenter.default.post(name: .cleanupLibraryCloudChange, object: nil)
            case DictationDictionaryCloudSync.subscriptionID: NotificationCenter.default.post(name: .dictationDictionaryCloudChange, object: nil)
            default: completionHandler(.noData); return
            }
            completionHandler(.newData)
        }
    }
}
