//
//  HomeTimelineViewController+DebugAction.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-2-5.
//


#if DEBUG
import os.log
import UIKit
import CoreData
import CoreDataStack
import FLEX
import SwiftUI
import MastodonUI
import MastodonSDK
import StoreKit

extension HomeTimelineViewController {
    var debugMenu: UIMenu {
        let menu = UIMenu(
            title: "Debug Tools",
            image: nil,
            identifier: nil,
            options: .displayInline,
            children: [
                showMenu,
                moveMenu,
                dropMenu,
                miscMenu,
                notificationMenu,
                UIAction(title: "Settings", image: UIImage(systemName: "gear"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showSettings(action)
                },
                UIAction(title: "Sign Out", image: UIImage(systemName: "escape"), attributes: .destructive) { [weak self] action in
                    guard let self = self else { return }
                    self.signOutAction(action)
                }
            ]
        )
        return menu
    }

    var showMenu: UIMenu {
        return UIMenu(
            title: "Show…",
            image: UIImage(systemName: "plus.rectangle.on.rectangle"),
            identifier: nil,
            options: [],
            children: [
                UIAction(title: "FLEX", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.showFLEXAction(action)
                }),
                UIAction(title: "Welcome", image: UIImage(systemName: "figure.walk"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showWelcomeAction(action)
                },
                UIAction(title: "Confirm Email", image: UIImage(systemName: "envelope"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showConfirmEmail(action)
                },
                UIAction(title: "Account List", image: UIImage(systemName: "person"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showAccountList(action)
                },
                UIAction(title: "Public Timeline", image: UIImage(systemName: "list.dash"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showPublicTimelineAction(action)
                },
                UIAction(title: "Profile", image: UIImage(systemName: "person.crop.circle"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showProfileAction(action)
                },
                UIAction(title: "Thread", image: UIImage(systemName: "bubble.left.and.bubble.right"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showThreadAction(action)
                },
                UIAction(title: "Store Rating", image: UIImage(systemName: "star.fill"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    guard let windowScene = self.view.window?.windowScene else { return }
                    SKStoreReviewController.requestReview(in: windowScene)
                },
            ]
        )
    }
    
    var moveMenu: UIMenu {
        return UIMenu(
            title: "Move to…",
            image: UIImage(systemName: "arrow.forward.circle"),
            identifier: nil,
            options: [],
            children: [
                UIAction(title: "First Gap", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.moveToTopGapAction(action)
                }),
                UIAction(title: "First Replied Status", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.moveToFirstRepliedStatus(action)
                }),
                UIAction(title: "First Reblog Status", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.moveToFirstReblogStatus(action)
                }),
                UIAction(title: "First Poll Status", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.moveToFirstPollStatus(action)
                }),
                UIAction(title: "First Audio Status", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.moveToFirstAudioStatus(action)
                }),
                UIAction(title: "First Video Status", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.moveToFirstVideoStatus(action)
                }),
                UIAction(title: "First GIF status", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.moveToFirstGIFStatus(action)
                }),
            ]
        )
    }
    
    var dropMenu: UIMenu {
        return UIMenu(
            title: "Drop…",
            image: UIImage(systemName: "minus.circle"),
            identifier: nil,
            options: [],
            children: [50, 100, 150, 200, 250, 300].map { count in
                UIAction(title: "Drop Recent \(count) Statuses", image: nil, attributes: [], handler: { [weak self] action in
                    guard let self = self else { return }
                    self.dropRecentStatusAction(action, count: count)
                })
            }
        )
    }
    
    var miscMenu: UIMenu {
        return UIMenu(
            title: "Debug…",
            image: UIImage(systemName: "switch.2"),
            identifier: nil,
            options: [],
            children: [
                UIAction(title: "Toggle EmptyView", image: UIImage(systemName: "clear"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    if self.emptyView.superview != nil {
                        self.emptyView.removeFromSuperview()
                    } else {
                        self.showEmptyView()
                    }
                },
                UIAction(
                    title: "Notification badge +1",
                    image: UIImage(systemName: "1.circle.fill"),
                    identifier: nil,
                    attributes: [],
                    state: .off,
                    handler: { [weak self] _ in
                        guard let self = self else { return }
                        guard let accessToken = self.context.authenticationService.activeMastodonAuthentication.value?.userAccessToken else { return }
                        UserDefaults.shared.increaseNotificationCount(accessToken: accessToken)
                        self.context.notificationService.applicationIconBadgeNeedsUpdate.send()
                    }
                ),
                UIAction(
                    title: "Enable account switcher wizard",
                    image: UIImage(systemName: "square.stack.3d.down.forward.fill"),
                    identifier: nil,
                    attributes: [],
                    state: .off,
                    handler: { _ in 
                        UserDefaults.shared.didShowMultipleAccountSwitchWizard = false
                    }
                ),
            ]
        )
    }
    
    var notificationMenu: UIMenu {
        return UIMenu(
            title: "Notification…",
            image: UIImage(systemName: "bell.badge"),
            identifier: nil,
            options: [],
            children: [
                UIAction(title: "Profile", image: UIImage(systemName: "person.badge.plus"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showNotification(action, notificationType: .follow)
                },
                UIAction(title: "Status", image: UIImage(systemName: "list.bullet.rectangle"), attributes: []) { [weak self] action in
                    guard let self = self else { return }
                    self.showNotification(action, notificationType: .mention)
                },
            ]
        )
    }
    
}

extension HomeTimelineViewController {
    
    @objc private func showFLEXAction(_ sender: UIAction) {
        FLEXManager.shared.showExplorer()
    }
    
    @objc private func moveToTopGapAction(_ sender: UIAction) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let snapshotTransitioning = diffableDataSource.snapshot()
        let item = snapshotTransitioning.itemIdentifiers.first(where: { item in
            switch item {
            case .homeMiddleLoader:         return true
            default:                        return false
            }
        })
        if let targetItem = item, let index = snapshotTransitioning.indexOfItem(targetItem) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
        }
    }
    
    @objc private func moveToFirstReblogStatus(_ sender: UIAction) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let snapshotTransitioning = diffableDataSource.snapshot()
        let item = snapshotTransitioning.itemIdentifiers.first(where: { item in
            switch item {
            case .homeTimelineIndex(let objectID, _):
                let homeTimelineIndex = viewModel.fetchedResultsController.managedObjectContext.object(with: objectID) as! HomeTimelineIndex
                return homeTimelineIndex.status.reblog != nil
            default:
                return false
            }
        })
        if let targetItem = item, let index = snapshotTransitioning.indexOfItem(targetItem) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            tableView.blinkRow(at: IndexPath(row: index, section: 0))
        } else {
            print("Not found reblog status")
        }
    }
    
    @objc private func moveToFirstPollStatus(_ sender: UIAction) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let snapshotTransitioning = diffableDataSource.snapshot()
        let item = snapshotTransitioning.itemIdentifiers.first(where: { item in
            switch item {
            case .homeTimelineIndex(let objectID, _):
                let homeTimelineIndex = viewModel.fetchedResultsController.managedObjectContext.object(with: objectID) as! HomeTimelineIndex
                let post = homeTimelineIndex.status.reblog ?? homeTimelineIndex.status
                return post.poll != nil
            default:
                return false
            }
        })
        if let targetItem = item, let index = snapshotTransitioning.indexOfItem(targetItem) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            tableView.blinkRow(at: IndexPath(row: index, section: 0))
        } else {
            print("Not found poll status")
        }
    }
    
    @objc private func moveToFirstRepliedStatus(_ sender: UIAction) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let snapshotTransitioning = diffableDataSource.snapshot()
        let item = snapshotTransitioning.itemIdentifiers.first(where: { item in
            switch item {
            case .homeTimelineIndex(let objectID, _):
                let homeTimelineIndex = viewModel.fetchedResultsController.managedObjectContext.object(with: objectID) as! HomeTimelineIndex
                guard homeTimelineIndex.status.inReplyToID != nil else {
                    return false
                }
                return true
            default:
                return false
            }
        })
        if let targetItem = item, let index = snapshotTransitioning.indexOfItem(targetItem) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            tableView.blinkRow(at: IndexPath(row: index, section: 0))
        } else {
            print("Not found replied status")
        }
    }
    
    @objc private func moveToFirstAudioStatus(_ sender: UIAction) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let snapshotTransitioning = diffableDataSource.snapshot()
        let item = snapshotTransitioning.itemIdentifiers.first(where: { item in
            switch item {
            case .homeTimelineIndex(let objectID, _):
                let homeTimelineIndex = viewModel.fetchedResultsController.managedObjectContext.object(with: objectID) as! HomeTimelineIndex
                let status = homeTimelineIndex.status.reblog ?? homeTimelineIndex.status
                return status.mediaAttachments?.contains(where: { $0.type == .audio }) ?? false
            default:
                return false
            }
        })
        if let targetItem = item, let index = snapshotTransitioning.indexOfItem(targetItem) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            tableView.blinkRow(at: IndexPath(row: index, section: 0))
        } else {
            print("Not found audio status")
        }
    }
    
    @objc private func moveToFirstVideoStatus(_ sender: UIAction) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let snapshotTransitioning = diffableDataSource.snapshot()
        let item = snapshotTransitioning.itemIdentifiers.first(where: { item in
            switch item {
            case .homeTimelineIndex(let objectID, _):
                let homeTimelineIndex = viewModel.fetchedResultsController.managedObjectContext.object(with: objectID) as! HomeTimelineIndex
                let status = homeTimelineIndex.status.reblog ?? homeTimelineIndex.status
                return status.mediaAttachments?.contains(where: { $0.type == .video }) ?? false
            default:
                return false
            }
        })
        if let targetItem = item, let index = snapshotTransitioning.indexOfItem(targetItem) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            tableView.blinkRow(at: IndexPath(row: index, section: 0))
        } else {
            print("Not found video status")
        }
    }
    
    @objc private func moveToFirstGIFStatus(_ sender: UIAction) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let snapshotTransitioning = diffableDataSource.snapshot()
        let item = snapshotTransitioning.itemIdentifiers.first(where: { item in
            switch item {
            case .homeTimelineIndex(let objectID, _):
                let homeTimelineIndex = viewModel.fetchedResultsController.managedObjectContext.object(with: objectID) as! HomeTimelineIndex
                let status = homeTimelineIndex.status.reblog ?? homeTimelineIndex.status
                return status.mediaAttachments?.contains(where: { $0.type == .gifv }) ?? false
            default:
                return false
            }
        })
        if let targetItem = item, let index = snapshotTransitioning.indexOfItem(targetItem) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
            tableView.blinkRow(at: IndexPath(row: index, section: 0))
        } else {
            print("Not found GIF status")
        }
    }
    
    @objc private func dropRecentStatusAction(_ sender: UIAction, count: Int) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let snapshotTransitioning = diffableDataSource.snapshot()
        
        let droppingObjectIDs = snapshotTransitioning.itemIdentifiers.prefix(count).compactMap { item -> NSManagedObjectID? in
            switch item {
            case .homeTimelineIndex(let objectID, _):   return objectID
            default:                                    return nil
            }
        }
        var droppingStatusObjectIDs: [NSManagedObjectID] = []
        context.apiService.backgroundManagedObjectContext.performChanges { [weak self] in
            guard let self = self else { return }
            for objectID in droppingObjectIDs {
                guard let homeTimelineIndex = try? self.context.apiService.backgroundManagedObjectContext.existingObject(with: objectID) as? HomeTimelineIndex else { continue }
                droppingStatusObjectIDs.append(homeTimelineIndex.status.objectID)
                self.context.apiService.backgroundManagedObjectContext.delete(homeTimelineIndex)
            }
        }
        .sink { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.context.apiService.backgroundManagedObjectContext.performChanges { [weak self] in
                    guard let self = self else { return }
                    for objectID in droppingStatusObjectIDs {
                        guard let post = try? self.context.apiService.backgroundManagedObjectContext.existingObject(with: objectID) as? Status else { continue }
                        self.context.apiService.backgroundManagedObjectContext.delete(post)
                    }
                }
                .sink { _ in
                    // do nothing
                }
                .store(in: &self.disposeBag)
            case .failure(let error):
                assertionFailure(error.localizedDescription)
            }
        }
        .store(in: &disposeBag)
    }
    
    @objc private func showWelcomeAction(_ sender: UIAction) {
        coordinator.present(scene: .welcome, from: self, transition: .modal(animated: true, completion: nil))
    }

    @objc private func showConfirmEmail(_ sender: UIAction) {
        let mastodonConfirmEmailViewModel = MastodonConfirmEmailViewModel()
        coordinator.present(scene: .mastodonConfirmEmail(viewModel: mastodonConfirmEmailViewModel), from: nil, transition: .modal(animated: true, completion: nil))
    }

    @objc private func showAccountList(_ sender: UIAction) {
        coordinator.present(scene: .accountList, from: self, transition: .modal(animated: true, completion: nil))
    }
    
    @objc private func showPublicTimelineAction(_ sender: UIAction) {
        coordinator.present(scene: .publicTimeline, from: self, transition: .show)
    }
    
    @objc private func showProfileAction(_ sender: UIAction) {
        let alertController = UIAlertController(title: "Enter User ID", message: nil, preferredStyle: .alert)
        alertController.addTextField()
        let showAction = UIAlertAction(title: "Show", style: .default) { [weak self, weak alertController] _ in
            guard let self = self else { return }
            guard let textField = alertController?.textFields?.first else { return }
            let profileViewModel = RemoteProfileViewModel(context: self.context, userID: textField.text ?? "")
            self.coordinator.present(scene: .profile(viewModel: profileViewModel), from: self, transition: .show)
        }
        alertController.addAction(showAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        coordinator.present(scene: .alertController(alertController: alertController), from: self, transition: .alertController(animated: true, completion: nil))
    }
    
    @objc private func showThreadAction(_ sender: UIAction) {
        let alertController = UIAlertController(title: "Enter Status ID", message: nil, preferredStyle: .alert)
        alertController.addTextField()
        let showAction = UIAlertAction(title: "Show", style: .default) { [weak self, weak alertController] _ in
            guard let self = self else { return }
            guard let textField = alertController?.textFields?.first else { return }
            let threadViewModel = RemoteThreadViewModel(context: self.context, statusID: textField.text ?? "")
            self.coordinator.present(scene: .thread(viewModel: threadViewModel), from: self, transition: .show)
        }
        alertController.addAction(showAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        coordinator.present(scene: .alertController(alertController: alertController), from: self, transition: .alertController(animated: true, completion: nil))
    }
    
    private func showNotification(_ sender: UIAction, notificationType: Mastodon.Entity.Notification.NotificationType) {
        guard let authenticationBox = self.context.authenticationService.activeMastodonAuthenticationBox.value else { return }
        
        let alertController = UIAlertController(title: "Enter notification ID", message: nil, preferredStyle: .alert)
        alertController.addTextField()
        
        let showAction = UIAlertAction(title: "Show", style: .default) { [weak self, weak alertController] _ in
            guard let self = self else { return }
            guard let textField = alertController?.textFields?.first,
                  let text = textField.text,
                  let notificationID = Int(text)
            else { return }
            
            let pushNotification = MastodonPushNotification(
                _accessToken: authenticationBox.userAuthorization.accessToken,
                notificationID: notificationID,
                notificationType: notificationType.rawValue,
                preferredLocale: nil,
                icon: nil,
                title: "",
                body: ""
            )
            self.context.notificationService.requestRevealNotificationPublisher.send(pushNotification)
        }
        alertController.addAction(showAction)
        
        // for multiple accounts debug
        let boxes = self.context.authenticationService.mastodonAuthenticationBoxes.value    // already sorted
        if boxes.count >= 2 {
            let accessToken = boxes[1].userAuthorization.accessToken
            let showForSecondaryAction = UIAlertAction(title: "Show for Secondary", style: .default) { [weak self, weak alertController] _ in
                guard let self = self else { return }
                guard let textField = alertController?.textFields?.first,
                      let text = textField.text,
                      let notificationID = Int(text)
                else { return }
                
                let pushNotification = MastodonPushNotification(
                    _accessToken: accessToken,
                    notificationID: notificationID,
                    notificationType: notificationType.rawValue,
                    preferredLocale: nil,
                    icon: nil,
                    title: "",
                    body: ""
                )
                self.context.notificationService.requestRevealNotificationPublisher.send(pushNotification)
            }
            alertController.addAction(showForSecondaryAction)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        self.coordinator.present(scene: .alertController(alertController: alertController), from: self, transition: .alertController(animated: true, completion: nil))
    }
    
    @objc private func showSettings(_ sender: UIAction) {
        guard let currentSetting = context.settingService.currentSetting.value else { return }
        let settingsViewModel = SettingsViewModel(context: context, setting: currentSetting)
        coordinator.present(
            scene: .settings(viewModel: settingsViewModel),
            from: self,
            transition: .modal(animated: true, completion: nil)
        )
    }

}
#endif
