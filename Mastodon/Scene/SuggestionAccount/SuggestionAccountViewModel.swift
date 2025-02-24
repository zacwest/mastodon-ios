//
//  SuggestionAccountViewModel.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/4/21.
//

import Combine
import CoreData
import CoreDataStack
import GameplayKit
import MastodonSDK
import os.log
import UIKit
    
protocol SuggestionAccountViewModelDelegate: AnyObject {
    var homeTimelineNeedRefresh: PassthroughSubject<Void, Never> { get }
}

final class SuggestionAccountViewModel: NSObject {
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    
    let currentMastodonUser = CurrentValueSubject<MastodonUser?, Never>(nil)
    weak var delegate: SuggestionAccountViewModelDelegate?
    // output
    let accounts = CurrentValueSubject<[NSManagedObjectID], Never>([])
    var selectedAccounts = CurrentValueSubject<[NSManagedObjectID], Never>([])

    var headerPlaceholderCount = CurrentValueSubject<Int?, Never>(nil)
    var suggestionAccountsFallback = PassthroughSubject<Void, Never>()
    
    var viewWillAppear = PassthroughSubject<Void, Never>()
    
    var diffableDataSource: UITableViewDiffableDataSource<RecommendAccountSection, NSManagedObjectID>? {
        didSet(value) {
            if !accounts.value.isEmpty {
                applyTableViewDataSource(accounts: accounts.value)
            }
        }
    }
    
    var collectionDiffableDataSource: UICollectionViewDiffableDataSource<SelectedAccountSection, SelectedAccountItem>?
    
    init(context: AppContext, accounts: [NSManagedObjectID]? = nil) {
        self.context = context

        super.init()
        
        Publishers.CombineLatest(
            self.accounts,
            self.selectedAccounts
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] accounts,selectedAccounts in
            self?.applyTableViewDataSource(accounts: accounts)
            self?.applySelectedCollectionViewDataSource(accounts: selectedAccounts)
        }
        .store(in: &disposeBag)
        
        Publishers.CombineLatest(
            self.selectedAccounts,
            self.headerPlaceholderCount
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] selectedAccount,count in
            self?.applySelectedCollectionViewDataSource(accounts: selectedAccount)
        }
        .store(in: &disposeBag)
        
        viewWillAppear
            .sink { [weak self] _ in
                self?.checkAccountsFollowState()
            }
            .store(in: &disposeBag)
        
        if let accounts = accounts {
            self.accounts.value = accounts
        }
        
        context.authenticationService.activeMastodonAuthentication
            .sink { [weak self] activeMastodonAuthentication in
                guard let self = self else { return }
                guard let activeMastodonAuthentication = activeMastodonAuthentication else {
                    self.currentMastodonUser.value = nil
                    return
                }
                self.currentMastodonUser.value = activeMastodonAuthentication.user
            }
            .store(in: &disposeBag)
        
        if accounts == nil || (accounts ?? []).isEmpty {
            guard let activeMastodonAuthenticationBox = context.authenticationService.activeMastodonAuthenticationBox.value else { return }

            context.apiService.suggestionAccountV2(domain: activeMastodonAuthenticationBox.domain, query: nil, mastodonAuthenticationBox: activeMastodonAuthenticationBox)
                .sink { [weak self] completion in
                    switch completion {
                    case .failure(let error):
                        if let apiError = error as? Mastodon.API.Error {
                            if apiError.httpResponseStatus == .notFound {
                                self?.suggestionAccountsFallback.send()
                            }
                        }
                        os_log("%{public}s[%{public}ld], %{public}s: fetch recommendAccountV2 failed. %s", (#file as NSString).lastPathComponent, #line, #function, error.localizedDescription)
                    case .finished:
                        // handle isFetchingLatestTimeline in fetch controller delegate
                        break
                    }
                } receiveValue: { [weak self] response in
                    let ids = response.value.map(\.account.id)
                    self?.receiveAccounts(ids: ids)
                }
                .store(in: &disposeBag)
            
            suggestionAccountsFallback
                .sink(receiveValue: { [weak self] _ in
                    self?.requestSuggestionAccount()
                })
                .store(in: &disposeBag)
        }
    }
    
    func requestSuggestionAccount() {
        guard let activeMastodonAuthenticationBox = context.authenticationService.activeMastodonAuthenticationBox.value else { return }
        context.apiService.suggestionAccount(domain: activeMastodonAuthenticationBox.domain, query: nil, mastodonAuthenticationBox: activeMastodonAuthenticationBox)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    os_log("%{public}s[%{public}ld], %{public}s: fetch recommendAccount failed. %s", (#file as NSString).lastPathComponent, #line, #function, error.localizedDescription)
                case .finished:
                    // handle isFetchingLatestTimeline in fetch controller delegate
                    break
                }
            } receiveValue: { [weak self] response in
                let ids = response.value.map(\.id)
                self?.receiveAccounts(ids: ids)
            }
            .store(in: &disposeBag)
    }
    
    func applyTableViewDataSource(accounts: [NSManagedObjectID]) {
        assert(Thread.isMainThread)
        guard let dataSource = diffableDataSource else { return }
        var snapshot = NSDiffableDataSourceSnapshot<RecommendAccountSection, NSManagedObjectID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(accounts, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false, completion: nil)
    }
    
    func applySelectedCollectionViewDataSource(accounts: [NSManagedObjectID]) {
        assert(Thread.isMainThread)
        guard let count = headerPlaceholderCount.value else { return }
        guard let dataSource = collectionDiffableDataSource else { return }
        var snapshot = NSDiffableDataSourceSnapshot<SelectedAccountSection, SelectedAccountItem>()
        snapshot.appendSections([.main])
        let placeholderCount = count - accounts.count
        let accountItems = accounts.map { SelectedAccountItem.accountObjectID(accountObjectID: $0) }
        snapshot.appendItems(accountItems, toSection: .main)
        
        if placeholderCount > 0 {
            for _ in 0 ..< placeholderCount {
                snapshot.appendItems([SelectedAccountItem.placeHolder(uuid: UUID())], toSection: .main)
            }
        }
        dataSource.apply(snapshot, animatingDifferences: false, completion: nil)
    }

    func receiveAccounts(ids: [String]) {
        guard let activeMastodonAuthenticationBox = context.authenticationService.activeMastodonAuthenticationBox.value else {
            return
        }
        let userFetchRequest = MastodonUser.sortedFetchRequest
        userFetchRequest.predicate = MastodonUser.predicate(domain: activeMastodonAuthenticationBox.domain, ids: ids)
        let mastodonUsers: [MastodonUser]? = {
            let userFetchRequest = MastodonUser.sortedFetchRequest
            userFetchRequest.predicate = MastodonUser.predicate(domain: activeMastodonAuthenticationBox.domain, ids: ids)
            userFetchRequest.returnsObjectsAsFaults = false
            do {
                return try self.context.managedObjectContext.fetch(userFetchRequest)
            } catch {
                assertionFailure(error.localizedDescription)
                return nil
            }
        }()
        if let users = mastodonUsers {
            let sortedUsers = users.sorted { (user1, user2) -> Bool in
                (ids.firstIndex(of: user1.id) ?? 0) < (ids.firstIndex(of: user2.id) ?? 0)
            }
            accounts.value = sortedUsers.map(\.objectID)
        }
    }

    func followAction(objectID: NSManagedObjectID) -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Relationship>, Error>? {
        guard let activeMastodonAuthenticationBox = context.authenticationService.activeMastodonAuthenticationBox.value else { return nil }

        let mastodonUser = context.managedObjectContext.object(with: objectID) as! MastodonUser
        return context.apiService.toggleFollow(
            for: mastodonUser,
            activeMastodonAuthenticationBox: activeMastodonAuthenticationBox
        )
    }
    
    func checkAccountsFollowState() {
        guard let currentMastodonUser = currentMastodonUser.value else {
            return
        }
        let users: [MastodonUser] = accounts.value.compactMap {
            guard let user = context.managedObjectContext.object(with: $0) as? MastodonUser else {
                return nil
            }
            let isBlock = user.blockingBy.flatMap { $0.contains(currentMastodonUser) } ?? false
            let isDomainBlock = user.domainBlockingBy.flatMap { $0.contains(currentMastodonUser) } ?? false
            if isBlock || isDomainBlock {
                return nil
            } else {
                return user
            }
        }
        accounts.value = users.map(\.objectID)
        
        let followingUsers = users.filter { user -> Bool in
            let isFollowing = user.followingBy.flatMap { $0.contains(currentMastodonUser) } ?? false
            let isPending = user.followRequestedBy.flatMap { $0.contains(currentMastodonUser) } ?? false
            return isFollowing || isPending
        }.map(\.objectID)
        
        selectedAccounts.value = followingUsers
    }
}
