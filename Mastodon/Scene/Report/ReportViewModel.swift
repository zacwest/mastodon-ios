//
//  ReportViewModel.swift
//  Mastodon
//
//  Created by ihugo on 2021/4/19.
//

import Combine
import CoreData
import CoreDataStack
import Foundation
import MastodonSDK
import UIKit
import os.log

class ReportViewModel: NSObject {
    typealias FileReportQuery = Mastodon.API.Reports.FileReportQuery
    
    enum Step: Int {
        case one
        case two
    }
    
    // confirm set only once
    weak var context: AppContext! { willSet { precondition(context == nil) } }
    var user: MastodonUser
    var status: Status?
    
    var statusIDs = [Mastodon.Entity.Status.ID]()
    var comment: String?
    
    var reportQuery: FileReportQuery
    var disposeBag = Set<AnyCancellable>()
    let currentStep = CurrentValueSubject<Step, Never>(.one)
    let statusFetchedResultsController: StatusFetchedResultsController
    var diffableDataSource: UITableViewDiffableDataSource<ReportSection, Item>?
    let continueEnableSubject = CurrentValueSubject<Bool, Never>(false)
    let sendEnableSubject = CurrentValueSubject<Bool, Never>(false)
    
    struct Input {
        let didToggleSelected: AnyPublisher<Item, Never>
        let comment: AnyPublisher<String?, Never>
        let step1Continue: AnyPublisher<Void, Never>
        let step1Skip: AnyPublisher<Void, Never>
        let step2Continue: AnyPublisher<Void, Never>
        let step2Skip: AnyPublisher<Void, Never>
        let cancel: AnyPublisher<Void, Never>
    }

    struct Output {
        let currentStep: AnyPublisher<Step, Never>
        let continueEnableSubject: AnyPublisher<Bool, Never>
        let sendEnableSubject: AnyPublisher<Bool, Never>
        let reportResult: AnyPublisher<(Bool, Error?), Never>
    }
    
    init(context: AppContext,
         domain: String,
         user: MastodonUser,
         status: Status?
    ) {
        self.context = context
        self.user = user
        self.status = status
        self.statusFetchedResultsController = StatusFetchedResultsController(
            managedObjectContext: context.managedObjectContext,
            domain: domain,
            additionalTweetPredicate: Status.notDeleted()
        )
        
        self.reportQuery = FileReportQuery(
            accountID: user.id,
            statusIDs: [],
            comment: nil,
            forward: nil
        )
        super.init()
    }
    
    func transform(input: Input?) -> Output? {
        guard let input = input else { return nil }
        guard let activeMastodonAuthenticationBox = context.authenticationService.activeMastodonAuthenticationBox.value else {
            return nil
        }
        let domain = activeMastodonAuthenticationBox.domain
        
        // data binding
        bindData(input: input)
        
        // step1 and step2 binding
        bindForStep1(input: input)
        let reportResult = bindForStep2(
            input: input,
            domain: domain,
            activeMastodonAuthenticationBox: activeMastodonAuthenticationBox
        )
        
        requestRecentStatus(
            domain: domain,
            accountId: self.user.id,
            authorizationBox: activeMastodonAuthenticationBox
        )
        
        fetchStatus()
        
        return Output(
            currentStep: currentStep.eraseToAnyPublisher(),
            continueEnableSubject: continueEnableSubject.eraseToAnyPublisher(),
            sendEnableSubject: sendEnableSubject.eraseToAnyPublisher(),
            reportResult: reportResult
        )
    }
    
    // MARK: - Private methods
    func bindData(input: Input) {
        input.didToggleSelected.sink { [weak self] (item) in
            guard let self = self else { return }
            guard case let .reportStatus(objectID, attribute) = item else { return }
            let managedObjectContext = self.statusFetchedResultsController.fetchedResultsController.managedObjectContext
            guard let status = managedObjectContext.object(with: objectID) as? Status else {
                return
            }
            
            attribute.isSelected = !attribute.isSelected
            if attribute.isSelected {
                self.append(statusID: status.id)
            } else {
                self.remove(statusID: status.id)
            }
            
            let continueEnable = self.statusIDs.count > 0
            self.continueEnableSubject.send(continueEnable)
        }
        .store(in: &disposeBag)
        
        input.comment.sink { [weak self] (comment) in
            guard let self = self else { return }
            
            self.comment = comment
            
            let sendEnable = (comment?.length ?? 0) > 0
            self.sendEnableSubject.send(sendEnable)
        }
        .store(in: &disposeBag)
    }
    
    func bindForStep1(input: Input) {
        let skip = input.step1Skip.map { [weak self] value -> Void in
            guard let self = self else { return value }
            self.reportQuery.statusIDs?.removeAll()
            return value
        }
        
        let step1Continue = input.step1Continue.map { [weak self] value -> Void in
            guard let self = self else { return value }
            self.reportQuery.statusIDs = self.statusIDs
            return value
        }
        
        Publishers.Merge(skip, step1Continue)
            .sink { [weak self] _ in
                self?.currentStep.value = .two
                self?.sendEnableSubject.send(false)
            }
            .store(in: &disposeBag)
    }
    
    func bindForStep2(input: Input, domain: String, activeMastodonAuthenticationBox: MastodonAuthenticationBox) -> AnyPublisher<(Bool, Error?), Never> {
        let skip = input.step2Skip.map { [weak self] value -> Void in
            guard let self = self else { return value }
            self.reportQuery.comment = nil
            return value
        }
        
        let step2Continue = input.step2Continue.map { [weak self] value -> Void in
            guard let self = self else { return value }
            self.reportQuery.comment = self.comment
            return value
        }

        return Publishers.Merge(skip, step2Continue)
            .flatMap { [weak self] (_) -> AnyPublisher<(Bool, Error?), Never> in
                guard let self = self else {
                    return Empty(completeImmediately: true).eraseToAnyPublisher()
                }
                
                return self.context.apiService.report(
                    domain: domain,
                    query: self.reportQuery,
                    mastodonAuthenticationBox: activeMastodonAuthenticationBox
                )
                .map({ (content) -> (Bool, Error?) in
                    return (true, nil)
                })
                .eraseToAnyPublisher()
                .tryCatch({ (error) -> AnyPublisher<(Bool, Error?), Never> in
                    return Just((false, error)).eraseToAnyPublisher()
                })
                // to covert to AnyPublisher<(Bool, Error?), Never>
                .replaceError(with: (false, nil))
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func append(statusID: Mastodon.Entity.Status.ID) {
        guard self.statusIDs.contains(statusID) != true else { return }
        self.statusIDs.append(statusID)
    }
    
    func remove(statusID: String) {
        guard let index = self.statusIDs.firstIndex(of: statusID) else { return }
        self.statusIDs.remove(at: index)
    }
}
