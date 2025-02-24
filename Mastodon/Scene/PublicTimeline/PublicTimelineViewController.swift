//
//  PublicTimelineViewController.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/1/27.
//

import AVKit
import Combine
import CoreData
import CoreDataStack
import GameplayKit
import os.log
import UIKit

final class PublicTimelineViewController: UIViewController, NeedsDependency, MediaPreviewableViewController {
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }
    
    var disposeBag = Set<AnyCancellable>()
    var viewModel: PublicTimelineViewModel!
    
    let mediaPreviewTransitionController = MediaPreviewTransitionController()
    
    let refreshControl = UIRefreshControl()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(StatusTableViewCell.self, forCellReuseIdentifier: String(describing: StatusTableViewCell.self))
        tableView.register(TimelineMiddleLoaderTableViewCell.self, forCellReuseIdentifier: String(describing: TimelineMiddleLoaderTableViewCell.self))
        tableView.register(TimelineBottomLoaderTableViewCell.self, forCellReuseIdentifier: String(describing: TimelineBottomLoaderTableViewCell.self))
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        return tableView
    }()
    
    deinit {
        os_log("%{public}s[%{public}ld], %{public}s", (#file as NSString).lastPathComponent, #line, #function)
    }
}

extension PublicTimelineViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Public"
        view.backgroundColor = ThemeService.shared.currentTheme.value.secondarySystemBackgroundColor
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(PublicTimelineViewController.refreshControlValueChanged(_:)), for: .valueChanged)
        // bind refresh control
        viewModel.isFetchingLatestTimeline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFetching in
                guard let self = self else { return }
                if !isFetching {
                    UIView.animate(withDuration: 0.5) { [weak self] in
                        guard let self = self else { return }
                        self.refreshControl.endRefreshing()
                    }
                }
            }
            .store(in: &disposeBag)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        viewModel.tableView = tableView
        viewModel.contentOffsetAdjustableTimelineViewControllerDelegate = self
        tableView.delegate = self
        tableView.prefetchDataSource = self
        viewModel.setupDiffableDataSource(
            for: tableView,
            dependency: self,
            statusTableViewCellDelegate: self,
            timelineMiddleLoaderTableViewCellDelegate: self
        )
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        context.videoPlaybackService.viewDidDisappear(from: self)
        context.audioPlaybackService.viewDidDisappear(from: self)
    }
}

// MARK: - UIScrollViewDelegate
extension PublicTimelineViewController {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        handleScrollViewDidScroll(scrollView)
    }
}

// MARK: - Selector
extension PublicTimelineViewController {
    @objc private func refreshControlValueChanged(_ sender: UIRefreshControl) {
        guard viewModel.stateMachine.enter(PublicTimelineViewModel.State.Loading.self) else {
            sender.endRefreshing()
            return
        }
    }
}

// MARK: - UITableViewDelegate
extension PublicTimelineViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let diffableDataSource = viewModel.diffableDataSource else { return 100 }
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return 100 }
        
        guard let frame = viewModel.cellFrameCache.object(forKey: NSNumber(value: item.hashValue))?.cgRectValue else {
            return 200
        }
        
        return ceil(frame.height)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {}
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        handleTableView(tableView, willDisplay: cell, forRowAt: indexPath)
    }
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        handleTableView(tableView, didEndDisplaying: cell, forRowAt: indexPath)
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return }
        
        let key = item.hashValue
        let frame = cell.frame
        viewModel.cellFrameCache.setObject(NSValue(cgRect: frame), forKey: NSNumber(value: key))
    }
}

// MARK: - UITableViewDataSourcePrefetching
extension PublicTimelineViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        handleTableView(tableView, prefetchRowsAt: indexPaths)
    }
}

// MARK: - ContentOffsetAdjustableTimelineViewControllerDelegate
extension PublicTimelineViewController: ContentOffsetAdjustableTimelineViewControllerDelegate {
    func navigationBar() -> UINavigationBar? {
        return navigationController?.navigationBar
    }
}

// MARK: - LoadMoreConfigurableTableViewContainer
extension PublicTimelineViewController: LoadMoreConfigurableTableViewContainer {
    typealias BottomLoaderTableViewCell = TimelineBottomLoaderTableViewCell
    typealias LoadingState = PublicTimelineViewModel.State.LoadingMore
    
    var loadMoreConfigurableTableView: UITableView { return tableView }
    var loadMoreConfigurableStateMachine: GKStateMachine { return viewModel.stateMachine }
}

// MARK: - TimelineMiddleLoaderTableViewCellDelegate
extension PublicTimelineViewController: TimelineMiddleLoaderTableViewCellDelegate {
    func configure(cell: TimelineMiddleLoaderTableViewCell, upperTimelineStatusID: String?, timelineIndexobjectID: NSManagedObjectID?) {
        guard let upperTimelineStatusID = upperTimelineStatusID else {return}
        viewModel.loadMiddleSateMachineList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                guard let _ = self else { return }
                if let stateMachine = ids[upperTimelineStatusID] {
                    guard let state = stateMachine.currentState else {
                        assertionFailure()
                        return
                    }

                    // make success state same as loading due to snapshot updating delay
                    let isLoading = state is PublicTimelineViewModel.LoadMiddleState.Loading || state is PublicTimelineViewModel.LoadMiddleState.Success
                    if isLoading {
                        cell.startAnimating()
                    } else {
                        cell.stopAnimating()
                    }
                } else {
                    cell.stopAnimating()
                }
            }
            .store(in: &cell.disposeBag)
        
        var dict = viewModel.loadMiddleSateMachineList.value
        if let _ = dict[upperTimelineStatusID] {
            // do nothing
        } else {
            let stateMachine = GKStateMachine(states: [
                PublicTimelineViewModel.LoadMiddleState.Initial(viewModel: viewModel, upperTimelineStatusID: upperTimelineStatusID),
                PublicTimelineViewModel.LoadMiddleState.Loading(viewModel: viewModel, upperTimelineStatusID: upperTimelineStatusID),
                PublicTimelineViewModel.LoadMiddleState.Fail(viewModel: viewModel, upperTimelineStatusID: upperTimelineStatusID),
                PublicTimelineViewModel.LoadMiddleState.Success(viewModel: viewModel, upperTimelineStatusID: upperTimelineStatusID),
            ])
            stateMachine.enter(PublicTimelineViewModel.LoadMiddleState.Initial.self)
            dict[upperTimelineStatusID] = stateMachine
            viewModel.loadMiddleSateMachineList.value = dict
        }
    }
    
    func timelineMiddleLoaderTableViewCell(_ cell: TimelineMiddleLoaderTableViewCell, loadMoreButtonDidPressed button: UIButton) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .publicMiddleLoader(let upper):
            guard let stateMachine = viewModel.loadMiddleSateMachineList.value[upper] else {
                assertionFailure()
                return
            }
            stateMachine.enter(PublicTimelineViewModel.LoadMiddleState.Loading.self)
        default:
            assertionFailure()
        }
    }
}

// MARK: - AVPlayerViewControllerDelegate
extension PublicTimelineViewController: AVPlayerViewControllerDelegate {
    
    func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        handlePlayerViewController(playerViewController, willBeginFullScreenPresentationWithAnimationCoordinator: coordinator)
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        handlePlayerViewController(playerViewController, willEndFullScreenPresentationWithAnimationCoordinator: coordinator)
    }
    
}

// MARK: - StatusTableViewCellDelegate
extension PublicTimelineViewController: StatusTableViewCellDelegate {
    weak var playerViewControllerDelegate: AVPlayerViewControllerDelegate? { return self }
    func parent() -> UIViewController { return self }
}
