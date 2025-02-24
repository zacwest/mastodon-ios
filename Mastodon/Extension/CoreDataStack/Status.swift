//
//  Status.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021/2/4.
//

import CoreDataStack
import Foundation
import MastodonSDK

extension Status.Property {
    init(entity: Mastodon.Entity.Status, domain: String, networkDate: Date) {
        self.init(
            domain: domain,
            id: entity.id,
            uri: entity.uri,
            createdAt: entity.createdAt,
            content: entity.content!,
            visibility: entity.visibility?.rawValue,
            sensitive: entity.sensitive ?? false,
            spoilerText: entity.spoilerText,
            emojisData: entity.emojis.flatMap { Status.encode(emojis: $0) },
            reblogsCount: NSNumber(value: entity.reblogsCount),
            favouritesCount: NSNumber(value: entity.favouritesCount),
            repliesCount: entity.repliesCount.flatMap { NSNumber(value: $0) },
            url: entity.url ?? entity.uri,
            inReplyToID: entity.inReplyToID,
            inReplyToAccountID: entity.inReplyToAccountID,
            language: entity.language,
            text: entity.text,
            networkDate: networkDate
        )
    }
}

extension Status {
    enum SensitiveType {
        case none
        case all
        case media(isSensitive: Bool)
    }
    
    var sensitiveType: SensitiveType {
        let spoilerText = self.spoilerText ?? ""
        
        // cast .all sensitive when has spoiter text
        if !spoilerText.isEmpty {
            return .all
        }
        
        if let firstAttachment = mediaAttachments?.first {
            // cast .media when has non audio media
            if firstAttachment.type != .audio {
                return .media(isSensitive: sensitive)
            } else {
                return .none
            }
        }
        
        // not sensitive
        return .none
    }
}

extension Status {
    var authorForUserProvider: MastodonUser {
        let author = (reblog ?? self).author
        return author
    }
}

extension Status {
    var statusURL: URL {
        if let urlString = self.url,
           let url = URL(string: urlString)
        {
            return url
        } else {
            return URL(string: "https://\(self.domain)/web/statuses/\(self.id)")!
        }
    }
    
    var activityItems: [Any] {
        var items: [Any] = []
        items.append(self.statusURL)
        return items
    }
}

extension Status: EmojiContainer { }


extension Status {
    var visibilityEnum: Mastodon.Entity.Status.Visibility? {
        return visibility.flatMap { Mastodon.Entity.Status.Visibility(rawValue: $0) }
    }
}
