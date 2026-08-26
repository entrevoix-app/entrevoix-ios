import CloudKit
import Foundation
import UIKit

extension Notification.Name {
    static let cleanupLibraryCloudChange = Notification.Name("cleanupLibraryCloudChange")
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
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
              notification.subscriptionID == CleanupLibraryCloudSync.subscriptionID else {
            completionHandler(.noData)
            return
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cleanupLibraryCloudChange, object: nil)
            completionHandler(.newData)
        }
    }
}
