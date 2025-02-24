//
//  ThemeService+Appearance.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-7-19.
//

import UIKit

extension ThemeService {
    func set(themeName: ThemeName) {
        UserDefaults.shared.currentThemeNameRawValue = themeName.rawValue

        let theme = themeName.theme
        apply(theme: theme)
        currentTheme.value = theme
    }

    func apply(theme: Theme) {
        // set navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = theme.navigationBarBackgroundColor
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        }

        // set tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()

        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
        tabBarItemAppearance.focused.titleTextAttributes = [.foregroundColor: UIColor.clear]
        tabBarItemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        tabBarItemAppearance.disabled.titleTextAttributes = [.foregroundColor: UIColor.clear]
        tabBarItemAppearance.selected.iconColor = theme.tabBarItemSelectedIconColor
        tabBarItemAppearance.focused.iconColor = theme.tabBarItemFocusedIconColor
        tabBarItemAppearance.normal.iconColor = theme.tabBarItemNormalIconColor
        tabBarItemAppearance.disabled.iconColor = theme.tabBarItemDisabledIconColor
        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.inlineLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = tabBarItemAppearance

        tabBarAppearance.backgroundColor = theme.tabBarBackgroundColor
        tabBarAppearance.selectionIndicatorTintColor = ThemeService.tintColor
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        } else {
            // Fallback on earlier versions
        }
        UITabBar.appearance().barTintColor = theme.tabBarBackgroundColor

        // set table view cell appearance
        UITableViewCell.appearance().backgroundColor = theme.tableViewCellBackgroundColor
        UITableViewCell.appearance(whenContainedInInstancesOf: [SettingsViewController.self]).backgroundColor = theme.secondarySystemGroupedBackgroundColor
        UITableViewCell.appearance().selectionColor = theme.tableViewCellSelectionBackgroundColor

        // set search bar appearance
        UISearchBar.appearance().tintColor = ThemeService.tintColor
        UISearchBar.appearance().barTintColor = theme.navigationBarBackgroundColor
        let cancelButtonAttributes: [NSAttributedString.Key : Any] = [NSAttributedString.Key.foregroundColor: ThemeService.tintColor]
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes(cancelButtonAttributes, for: .normal)
    }
}
