//
//  OnboardingViewControllerAppearance.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/2/25.
//

import UIKit

protocol OnboardingViewControllerAppearance: UIViewController {
    static var viewBottomPaddingHeight: CGFloat { get }
    func setupOnboardingAppearance()
    func setupNavigationBarAppearance()
}

extension OnboardingViewControllerAppearance {
    
    static var actionButtonHeight: CGFloat { return 46 }
    static var actionButtonMargin: CGFloat { return 12 }
    static var viewBottomPaddingHeight: CGFloat { return 11 }
    
    func setupOnboardingAppearance() {
        view.backgroundColor = Asset.Theme.Mastodon.systemGroupedBackground.color

        setupNavigationBarAppearance()
        
        let backItem = UIBarButtonItem(
            title: L10n.Common.Controls.Actions.back,
            style: .plain,
            target: nil,
            action: nil
        )
        navigationItem.backBarButtonItem = backItem
    }
    
    func setupNavigationBarAppearance() {
        // use TransparentBackground so view push / dismiss will be more visual nature
        // please add opaque background for status bar manually if needs
        
        switch traitCollection.userInterfaceIdiom {
        case .pad:
            if traitCollection.horizontalSizeClass == .regular {
                // do nothing
            } else {
                fallthrough
            }
        default:
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithTransparentBackground()
            navigationItem.standardAppearance = barAppearance
            navigationItem.compactAppearance = barAppearance
            navigationItem.scrollEdgeAppearance = barAppearance
            if #available(iOS 15.0, *) {
                navigationItem.compactScrollEdgeAppearance = barAppearance
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    func setupNavigationBarBackgroundView() {
        let navigationBarBackgroundView: UIView = {
            let view = UIView()
            view.backgroundColor = Asset.Theme.Mastodon.systemGroupedBackground.color
            return view
        }()
        
        navigationBarBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBarBackgroundView)
        NSLayoutConstraint.activate([
            navigationBarBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            navigationBarBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBarBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBarBackgroundView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
        ])
    }
    
}

extension OnboardingViewControllerAppearance {
    static var viewEdgeMargin: CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return .zero }
        return 20
//        let shortEdgeWidth = min(UIScreen.main.bounds.height, UIScreen.main.bounds.width)
//        return shortEdgeWidth * 0.17 // magic
    }
}
