//
//  AuthenticationService.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021/2/3.
//

import os.log
import Foundation
import Combine
import CoreData
import CoreDataStack
import MastodonSDK

final class AuthenticationService: NSObject {

    var disposeBag = Set<AnyCancellable>()
    
    // input
    weak var apiService: APIService?
    let managedObjectContext: NSManagedObjectContext    // read-only
    let backgroundManagedObjectContext: NSManagedObjectContext
    let mastodonAuthenticationFetchedResultsController: NSFetchedResultsController<MastodonAuthentication>

    // output
    let mastodonAuthentications = CurrentValueSubject<[MastodonAuthentication], Never>([])
    let mastodonAuthenticationBoxes = CurrentValueSubject<[MastodonAuthenticationBox], Never>([])
    let activeMastodonAuthentication = CurrentValueSubject<MastodonAuthentication?, Never>(nil)
    let activeMastodonAuthenticationBox = CurrentValueSubject<MastodonAuthenticationBox?, Never>(nil)

    init(
        managedObjectContext: NSManagedObjectContext,
        backgroundManagedObjectContext: NSManagedObjectContext,
        apiService: APIService
    ) {
        self.managedObjectContext = managedObjectContext
        self.backgroundManagedObjectContext = backgroundManagedObjectContext
        self.apiService = apiService
        self.mastodonAuthenticationFetchedResultsController = {
            let fetchRequest = MastodonAuthentication.sortedFetchRequest
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.fetchBatchSize = 20
            let controller = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            return controller
        }()
        super.init()

        mastodonAuthenticationFetchedResultsController.delegate = self

        // TODO: verify credentials for active authentication
    
        // bind data
        mastodonAuthentications
            .map { $0.sorted(by: { $0.activedAt > $1.activedAt }).first }
            .assign(to: \.value, on: activeMastodonAuthentication)
            .store(in: &disposeBag)
        
        mastodonAuthentications
            .map { authentications -> [MastodonAuthenticationBox] in
                return authentications
                    .sorted(by: { $0.activedAt > $1.activedAt })
                    .compactMap { authentication -> MastodonAuthenticationBox? in
                        return MastodonAuthenticationBox(
                            domain: authentication.domain,
                            userID: authentication.userID,
                            appAuthorization: Mastodon.API.OAuth.Authorization(accessToken: authentication.appAccessToken),
                            userAuthorization: Mastodon.API.OAuth.Authorization(accessToken: authentication.userAccessToken)
                        )
                    }
            }
            .assign(to: \.value, on: mastodonAuthenticationBoxes)
            .store(in: &disposeBag)
        
        mastodonAuthenticationBoxes
            .map { $0.first }
            .assign(to: \.value, on: activeMastodonAuthenticationBox)
            .store(in: &disposeBag)

        do {
            try mastodonAuthenticationFetchedResultsController.performFetch()
            mastodonAuthentications.value = mastodonAuthenticationFetchedResultsController.fetchedObjects ?? []
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

}

extension AuthenticationService {
    
    func activeMastodonUser(domain: String, userID: MastodonUser.ID) -> AnyPublisher<Result<Bool, Error>, Never> {
        var isActive = false
        var _mastodonAuthentication: MastodonAuthentication?
        
        return backgroundManagedObjectContext.performChanges { [weak self] in
            guard let self = self else { return }
            
            let request = MastodonAuthentication.sortedFetchRequest
            request.predicate = MastodonAuthentication.predicate(domain: domain, userID: userID)
            request.fetchLimit = 1
            guard let mastodonAuthentication = try? self.backgroundManagedObjectContext.fetch(request).first else {
                return
            }
            mastodonAuthentication.update(activedAt: Date())
            _mastodonAuthentication = mastodonAuthentication
            isActive = true
        
        }
        .receive(on: DispatchQueue.main)
        .map { [weak self] result in
            switch result {
            case .success:
                if let self = self,
                   let mastodonAuthentication = _mastodonAuthentication
                {
                    // force set to avoid delay
                    self.activeMastodonAuthentication.value = mastodonAuthentication
                    self.activeMastodonAuthenticationBox.value = MastodonAuthenticationBox(
                        domain: mastodonAuthentication.domain,
                        userID: mastodonAuthentication.userID,
                        appAuthorization: Mastodon.API.OAuth.Authorization(accessToken: mastodonAuthentication.appAccessToken),
                        userAuthorization: Mastodon.API.OAuth.Authorization(accessToken: mastodonAuthentication.userAccessToken)
                    )
                }
            case .failure:
                break
            }
            return result.map { isActive }
        }
        .eraseToAnyPublisher()
    }
    
    func signOutMastodonUser(domain: String, userID: MastodonUser.ID) -> AnyPublisher<Result<Bool, Error>, Never> {
        var isSignOut = false
        
        var _mastodonAuthenticationBox: MastodonAuthenticationBox?
        let managedObjectContext = backgroundManagedObjectContext
        return managedObjectContext.performChanges {
            let request = MastodonAuthentication.sortedFetchRequest
            request.predicate = MastodonAuthentication.predicate(domain: domain, userID: userID)
            request.fetchLimit = 1
            guard let mastodonAuthentication = try? managedObjectContext.fetch(request).first else {
                return
            }
            _mastodonAuthenticationBox = MastodonAuthenticationBox(
                domain: mastodonAuthentication.domain,
                userID: mastodonAuthentication.userID,
                appAuthorization: Mastodon.API.OAuth.Authorization(accessToken: mastodonAuthentication.appAccessToken),
                userAuthorization: Mastodon.API.OAuth.Authorization(accessToken: mastodonAuthentication.userAccessToken)
            )

            // remove home timeline indexes
            let homeTimelineIndexRequest = HomeTimelineIndex.sortedFetchRequest
            homeTimelineIndexRequest.predicate = HomeTimelineIndex.predicate(
                domain: mastodonAuthentication.domain,
                userID: mastodonAuthentication.userID
            )
            let homeTimelineIndexes = managedObjectContext.safeFetch(homeTimelineIndexRequest)
            for homeTimelineIndex in homeTimelineIndexes {
                managedObjectContext.delete(homeTimelineIndex)
            }

            // remove user authentication
            managedObjectContext.delete(mastodonAuthentication)
            isSignOut = true
        }
        .flatMap { result -> AnyPublisher<Result<Void, Error>, Never> in
            guard let apiService = self.apiService,
                  let mastodonAuthenticationBox = _mastodonAuthenticationBox else {
                return Just(result).eraseToAnyPublisher()
            }
            
            return apiService.cancelSubscription(
                mastodonAuthenticationBox: mastodonAuthenticationBox
            )
            .map { _ in result }
            .catch { _ in Just(result).eraseToAnyPublisher() }
            .eraseToAnyPublisher()
        }
        .map { result in
            return result.map { isSignOut }
        }
        .eraseToAnyPublisher()
    }
    
}


// MARK: - NSFetchedResultsControllerDelegate
extension AuthenticationService: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
         os_log("%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if controller === mastodonAuthenticationFetchedResultsController {
            mastodonAuthentications.value = mastodonAuthenticationFetchedResultsController.fetchedObjects ?? []
        }
    }
    
}
    
