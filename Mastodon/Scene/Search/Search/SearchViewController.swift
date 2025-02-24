//
//  SearchViewController.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/3/31.
//

import os.log
import Combine
import GameplayKit
import MastodonSDK
import UIKit

final class HeightFixedSearchBar: UISearchBar {
    override var intrinsicContentSize: CGSize {
        return CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44)
    }
}

final class SearchViewController: UIViewController, NeedsDependency {

    let logger = Logger(subsystem: "Search", category: "UI")
    
    public static var hashtagCardHeight: CGFloat {
        get {
            if UIScreen.main.bounds.size.height > 736 {
                return 186
            }
            return 130
        }
    }
    
    public static var hashtagPeopleTalkingLabelTop: CGFloat {
        get {
            if UIScreen.main.bounds.size.height > 736 {
                return 18
            }
            return 6
        }
    }
    public static let accountCardHeight = 202
    
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }

    var searchTransitionController = SearchTransitionController()
    
    var disposeBag = Set<AnyCancellable>()
    private(set) lazy var viewModel = SearchViewModel(context: context)
    
    // use AutoLayout could set search bar margin automatically to
    // layout alongside with split mode button (on iPad)
    let titleViewContainer = UIView()
    let searchBar = HeightFixedSearchBar()

    // recommend
    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.clipsToBounds = false
        return scrollView
    }()
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        return stackView
    }()
    
    let hashtagCollectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        let view = ControlContainableCollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let accountsCollectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        let view = ControlContainableCollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let searchBarTapPublisher = PassthroughSubject<Void, Never>()
    
    deinit {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
    }

}

extension SearchViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackgroundColor(theme: ThemeService.shared.currentTheme.value)
        ThemeService.shared.currentTheme
            .receive(on: RunLoop.main)
            .sink { [weak self] theme in
                guard let self = self else { return }
                self.setupBackgroundColor(theme: theme)
            }
            .store(in: &disposeBag)

        title = L10n.Scene.Search.title

        setupSearchBar()
        setupScrollView()
        setupHashTagCollectionView()
        setupAccountsCollectionView()
        setupDataSource()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewModel.viewDidAppeared.send()
        
        // note:
        // need set alpha because (maybe) SDK forget set alpha back
        titleViewContainer.alpha = 1
    }
}

extension SearchViewController {
    private func setupBackgroundColor(theme: Theme) {
        view.backgroundColor = theme.systemGroupedBackgroundColor
    }

    private func setupSearchBar() {
        searchBar.placeholder = L10n.Scene.Search.SearchBar.placeholder
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        titleViewContainer.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: titleViewContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: titleViewContainer.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: titleViewContainer.trailingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: titleViewContainer.bottomAnchor),
        ])
        navigationItem.titleView = titleViewContainer

        searchBarTapPublisher
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] in
                guard let self = self else { return }
                // push to search detail
                let searchDetailViewModel = SearchDetailViewModel()
                searchDetailViewModel.needsBecomeFirstResponder = true
                self.navigationController?.delegate = self.searchTransitionController
                self.coordinator.present(scene: .searchDetail(viewModel: searchDetailViewModel), from: self, transition: .customPush)
            }
            .store(in: &disposeBag)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // scrollView
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.frameLayoutGuide.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.frameLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            scrollView.frameLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.frameLayoutGuide.widthAnchor.constraint(equalTo: scrollView.contentLayoutGuide.widthAnchor),
        ])

        // stack view
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentLayoutGuide.widthAnchor),
            scrollView.contentLayoutGuide.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
        ])
    }
    
    private func setupDataSource() {
        viewModel.hashtagDiffableDataSource = RecommendHashTagSection.collectionViewDiffableDataSource(for: hashtagCollectionView)
        viewModel.accountDiffableDataSource = RecommendAccountSection.collectionViewDiffableDataSource(
            for: accountsCollectionView,
            dependency: self,
            delegate: self,
            managedObjectContext: context.managedObjectContext
        )
    }
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        os_log("%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
        searchBarTapPublisher.send()
        return false
    }
}

// MARK - UISearchControllerDelegate
extension SearchViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        logger.debug("\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public)")
        searchController.isActive = true
    }
    func didPresentSearchController(_ searchController: UISearchController) {
        logger.debug("\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public)")
    }
}

#if canImport(SwiftUI) && DEBUG
import SwiftUI

struct SearchViewController_Previews: PreviewProvider {
    static var previews: some View {
        UIViewControllerPreview {
            let viewController = SearchViewController()
            return viewController
        }
        .previewLayout(.fixed(width: 375, height: 800))
    }
}

#endif
