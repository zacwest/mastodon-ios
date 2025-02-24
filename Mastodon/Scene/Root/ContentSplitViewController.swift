//
//  ContentSplitViewController.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-10-28.
//

import os.log
import UIKit
import Combine
import CoreDataStack

protocol ContentSplitViewControllerDelegate: AnyObject {
    func contentSplitViewController(_ contentSplitViewController: ContentSplitViewController, sidebarViewController: SidebarViewController, didSelectTab tab: MainTabBarController.Tab)
}

final class ContentSplitViewController: UIViewController, NeedsDependency {

    var disposeBag = Set<AnyCancellable>()
    
    static let sidebarWidth: CGFloat = 89
    
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }
    
    weak var delegate: ContentSplitViewControllerDelegate?
    
    private(set) lazy var sidebarViewController: SidebarViewController = {
        let sidebarViewController = SidebarViewController()
        sidebarViewController.context = context
        sidebarViewController.coordinator = coordinator
        sidebarViewController.viewModel = SidebarViewModel(context: context)
        sidebarViewController.delegate = self
        return sidebarViewController
    }()
    
    @Published var currentSupplementaryTab: MainTabBarController.Tab = .home
    private(set) lazy var mainTabBarController: MainTabBarController = {
        let mainTabBarController = MainTabBarController(context: context, coordinator: coordinator)
        if let homeTimelineViewController = mainTabBarController.viewController(of: HomeTimelineViewController.self) {
            homeTimelineViewController.viewModel.displayComposeBarButtonItem.value = false
            homeTimelineViewController.viewModel.displaySettingBarButtonItem.value = false
        }
        return mainTabBarController
    }()

    deinit {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
    }
    
}

extension ContentSplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        addChild(sidebarViewController)
        sidebarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebarViewController.view)
        sidebarViewController.didMove(toParent: self)
        NSLayoutConstraint.activate([
            sidebarViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarViewController.view.widthAnchor.constraint(equalToConstant: ContentSplitViewController.sidebarWidth),
        ])
        
        addChild(mainTabBarController)
        mainTabBarController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainTabBarController.view)
        sidebarViewController.didMove(toParent: self)
        NSLayoutConstraint.activate([
            mainTabBarController.view.topAnchor.constraint(equalTo: view.topAnchor),
            mainTabBarController.view.leadingAnchor.constraint(equalTo: sidebarViewController.view.trailingAnchor, constant: UIView.separatorLineHeight(of: view)),
            mainTabBarController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainTabBarController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        $currentSupplementaryTab
            .removeDuplicates()
            .sink(receiveValue: { [weak self] tab in
                guard let self = self else { return }
                self.mainTabBarController.selectedIndex = tab.rawValue
                self.mainTabBarController.currentTab.value = tab
            })
            .store(in: &disposeBag)
    }
}

// MARK: - SidebarViewControllerDelegate
extension ContentSplitViewController: SidebarViewControllerDelegate {
    
    func sidebarViewController(_ sidebarViewController: SidebarViewController, didSelectTab tab: MainTabBarController.Tab) {
        delegate?.contentSplitViewController(self, sidebarViewController: sidebarViewController, didSelectTab: tab)
    }
    
    func sidebarViewController(_ sidebarViewController: SidebarViewController, didLongPressItem item: SidebarViewModel.Item, sourceView: UIView) {
        guard case let .tab(tab) = item, tab == .me else { return }
        
        let accountListViewController = coordinator.present(scene: .accountList, from: nil, transition: .popover(sourceView: sourceView)) as! AccountListViewController
        accountListViewController.dragIndicatorView.barView.isHidden = true
        // content width needs > 300 to make checkmark display
        accountListViewController.preferredContentSize = CGSize(width: 375, height: 400)
    }
    
}
