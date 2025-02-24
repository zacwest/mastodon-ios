//
//  StatusFilterService.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-7-14.
//

import os.log
import Foundation
import Combine
import CoreData
import CoreDataStack
import MastodonSDK
import MastodonMeta

final class StatusFilterService {

    var disposeBag = Set<AnyCancellable>()

    // input
    weak var apiService: APIService?
    weak var authenticationService: AuthenticationService?
    let filterUpdatePublisher = PassthroughSubject<Void, Never>()

    // output
    let activeFilters = CurrentValueSubject<[Mastodon.Entity.Filter], Never>([])

    init(
        apiService: APIService,
        authenticationService: AuthenticationService
    ) {
        self.apiService = apiService
        self.authenticationService = authenticationService

        // fetch account filters every 300s
        // also trigger fetch when app resume from background
        let filterUpdateTimerPublisher = Timer.publish(every: 300.0, on: .main, in: .common)
            .autoconnect()
            .share()
            .eraseToAnyPublisher()

        filterUpdateTimerPublisher
            .map { _ in }
            .subscribe(filterUpdatePublisher)
            .store(in: &disposeBag)

        let activeMastodonAuthenticationBox = authenticationService.activeMastodonAuthenticationBox
        Publishers.CombineLatest(
            activeMastodonAuthenticationBox,
            filterUpdatePublisher
        )
        .flatMap { box, _ -> AnyPublisher<Result<Mastodon.Response.Content<[Mastodon.Entity.Filter]>, Error>, Never> in
            guard let box = box else {
                return Just(Result { throw APIService.APIError.implicit(.authenticationMissing) }).eraseToAnyPublisher()
            }
            return apiService.filters(mastodonAuthenticationBox: box)
                .map { response in
                    let now = Date()
                    let newResponse = response.map { filters in
                        return filters.filter { $0.expiresAt > now }        // filter out expired rules
                    }
                    return Result<Mastodon.Response.Content<[Mastodon.Entity.Filter]>, Error>.success(newResponse)
                }
                .catch { error in
                    Just(Result<Mastodon.Response.Content<[Mastodon.Entity.Filter]>, Error>.failure(error))
                }
                .eraseToAnyPublisher()
        }
        .sink { result in
            switch result {
            case .success(let response):
                os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: fetch account filters success. %ld items", ((#file as NSString).lastPathComponent), #line, #function, response.value.count)
                self.activeFilters.value = response.value
            case .failure(let error):
                os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: fetch account filters fail: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)

                break
            }
        }
        .store(in: &disposeBag)

        // make initial trigger once
        filterUpdatePublisher.send()
    }

}
