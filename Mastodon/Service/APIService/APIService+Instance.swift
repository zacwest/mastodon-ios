//
//  APIService+Instance.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-2-5.
//

import Foundation
import Combine
import CoreData
import CoreDataStack
import CommonOSLog
import DateToolsSwift
import MastodonSDK

extension APIService {
    
    func instance(
        domain: String
    ) -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Instance>, Error> {
        return Mastodon.API.Instance.instance(session: session, domain: domain)
    }
    
}
