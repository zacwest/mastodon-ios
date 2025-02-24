//
//  AppDelegate.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021/1/22.
//

import os.log
import UIKit
import UserNotifications
import AppShared
import AVFoundation
@_exported import MastodonUI

#if ASDK
import AsyncDisplayKit
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    let appContext = AppContext()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        AppSecret.default.register()

        // configure appearance
        ThemeService.shared.apply(theme: ThemeService.shared.currentTheme.value)
        
        // Update app version info. See: `Settings.bundle`
        UserDefaults.standard.setValue(UIApplication.appVersion(), forKey: "Mastodon.appVersion")
        UserDefaults.standard.setValue(UIApplication.appBuild(), forKey: "Mastodon.appBundle")
        
        // Setup notification
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        
        // increase app process count
        var count = UserDefaults.shared.processCompletedCount
        count += 1      // Int64. could ignore overflow here
        UserDefaults.shared.processCompletedCount = count
        
        #if ASDK && DEBUG
        // PerformanceMonitor.shared().start()
        // ASDisplayNode.shouldShowRangeDebugOverlay = true
        // ASControlNode.enableHitTestDebug = true
        // ASImageNode.shouldShowImageScalingOverlay = true
        #endif
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return true
    }

}

extension AppDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        #if DEBUG
        return .all
        #else
        return UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
        #endif
    }
}

extension AppDelegate {
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        appContext.notificationService.deviceToken.value = deviceToken
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // notification present in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: [Push Notification]", ((#file as NSString).lastPathComponent), #line, #function)
        guard let mastodonPushNotification = AppDelegate.mastodonPushNotification(from: notification) else {
            completionHandler([])
            return
        }
        
        let notificationID = String(mastodonPushNotification.notificationID)
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: [Push Notification] notification %s", ((#file as NSString).lastPathComponent), #line, #function, notificationID)
        
        let accessToken = mastodonPushNotification.accessToken
        UserDefaults.shared.increaseNotificationCount(accessToken: accessToken)
        appContext.notificationService.applicationIconBadgeNeedsUpdate.send()
        
        appContext.notificationService.handle(mastodonPushNotification: mastodonPushNotification)
        completionHandler([.sound])
    }
    
    // response to user action for notification (e.g. redirect to post)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: [Push Notification]", ((#file as NSString).lastPathComponent), #line, #function)
        
        guard let mastodonPushNotification = AppDelegate.mastodonPushNotification(from: response.notification) else {
            completionHandler()
            return
        }
        
        let notificationID = String(mastodonPushNotification.notificationID)
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: [Push Notification] notification %s", ((#file as NSString).lastPathComponent), #line, #function, notificationID)
        appContext.notificationService.handle(mastodonPushNotification: mastodonPushNotification)
        appContext.notificationService.requestRevealNotificationPublisher.send(mastodonPushNotification)
        completionHandler()
    }
    
    private static func mastodonPushNotification(from notification: UNNotification) -> MastodonPushNotification? {
        guard let plaintext = notification.request.content.userInfo["plaintext"] as? Data,
              let mastodonPushNotification = try? JSONDecoder().decode(MastodonPushNotification.self, from: plaintext) else {
            return nil
        }
        
        return mastodonPushNotification
    }
    
}

extension AppContext {
    static var shared: AppContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.appContext
    }
}
