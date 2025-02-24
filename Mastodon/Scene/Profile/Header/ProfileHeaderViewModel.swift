//
//  ProfileHeaderViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-4-9.
//

import os.log
import UIKit
import Combine
import Kanna
import MastodonSDK
import MastodonMeta

final class ProfileHeaderViewModel {
    
    static let maxProfileFieldCount = 4
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let isEditing = CurrentValueSubject<Bool, Never>(false)
    let viewDidAppear = CurrentValueSubject<Bool, Never>(false)
    let needsSetupBottomShadow = CurrentValueSubject<Bool, Never>(true)
    let needsFiledCollectionViewHidden = CurrentValueSubject<Bool, Never>(false)
    let isTitleViewContentOffsetSet = CurrentValueSubject<Bool, Never>(false)
    let emojiMeta = CurrentValueSubject<MastodonContent.Emojis, Never>([:])
    let accountForEdit = CurrentValueSubject<Mastodon.Entity.Account?, Never>(nil)
    
    // output
    let displayProfileInfo = ProfileInfo()
    let editProfileInfo = ProfileInfo()
    let editProfileInfoDidInitialized = CurrentValueSubject<Void, Never>(Void()) // needs trigger initial event
    let isTitleViewDisplaying = CurrentValueSubject<Bool, Never>(false)
    var fieldDiffableDataSource: UICollectionViewDiffableDataSource<ProfileFieldSection, ProfileFieldItem>!
    
    init(context: AppContext) {
        self.context = context

        Publishers.CombineLatest(
            isEditing.removeDuplicates(),   // only trigger when value toggle
            accountForEdit
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isEditing, account in
            guard let self = self else { return }
            guard isEditing else { return }
            // setup editing value when toggle to editing
            self.editProfileInfo.name.value = self.displayProfileInfo.name.value        // set to name
            self.editProfileInfo.avatarImageResource.value = .image(nil)                // set to empty
            self.editProfileInfo.note.value = ProfileHeaderViewModel.normalize(note: self.displayProfileInfo.note.value)
            self.editProfileInfo.fields.value = account?.source?.fields?.compactMap { field in
                ProfileFieldItem.FieldValue(name: field.name, value: field.value)
            } ?? []
            self.editProfileInfoDidInitialized.send()
        }
        .store(in: &disposeBag)
        
        Publishers.CombineLatest4(
            isEditing.removeDuplicates(),
            displayProfileInfo.fields.removeDuplicates(),
            editProfileInfo.fields.removeDuplicates(),
            emojiMeta.removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isEditing, displayFields, editingFields, emojiMeta in
            guard let self = self else { return }
            guard let diffableDataSource = self.fieldDiffableDataSource else { return }
            
            var snapshot = NSDiffableDataSourceSnapshot<ProfileFieldSection, ProfileFieldItem>()
            snapshot.appendSections([.main])

            let oldSnapshot = diffableDataSource.snapshot()
            let oldFieldAttributeDict: [UUID: ProfileFieldItem.FieldItemAttribute] = {
                var dict: [UUID: ProfileFieldItem.FieldItemAttribute] = [:]
                for item in oldSnapshot.itemIdentifiers {
                    switch item {
                    case .field(let field, let attribute):
                        dict[field.id] = attribute
                    default:
                        continue
                    }
                }
                return dict
            }()
            let fields: [ProfileFieldItem.FieldValue] = isEditing ? editingFields : displayFields
            var items = fields.map { field -> ProfileFieldItem in
                os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: process field item ID: %s", ((#file as NSString).lastPathComponent), #line, #function, field.id.uuidString)

                let attribute = oldFieldAttributeDict[field.id] ?? ProfileFieldItem.FieldItemAttribute()
                attribute.isEditing = isEditing
                attribute.emojiMeta.value = emojiMeta
                attribute.isLast = false
                return ProfileFieldItem.field(field: field, attribute: attribute)
            }
            
            if isEditing, fields.count < ProfileHeaderViewModel.maxProfileFieldCount {
                items.append(.addEntry(attribute: ProfileFieldItem.AddEntryItemAttribute()))
            }
            
            if let last = items.last?.listSeparatorLineConfigurable {
                last.isLast = true
            }

            snapshot.appendItems(items, toSection: .main)
            
            diffableDataSource.apply(snapshot, animatingDifferences: false, completion: nil)
        }
        .store(in: &disposeBag)
    }
    
}

extension ProfileHeaderViewModel {
    struct ProfileInfo {
        let name = CurrentValueSubject<String?, Never>(nil)
        let avatarImageResource = CurrentValueSubject<ImageResource?, Never>(nil)
        let note = CurrentValueSubject<String?, Never>(nil)
        let fields = CurrentValueSubject<[ProfileFieldItem.FieldValue], Never>([])
        
        enum ImageResource {
            case url(URL?)
            case image(UIImage?)
        }
    }
}

extension ProfileHeaderViewModel {
    func appendFieldItem() {
        var fields = editProfileInfo.fields.value
        guard fields.count < ProfileHeaderViewModel.maxProfileFieldCount else { return }
        fields.append(ProfileFieldItem.FieldValue(name: "", value: ""))
        editProfileInfo.fields.value = fields
    }
    
    func removeFieldItem(item: ProfileFieldItem) {
        var fields = editProfileInfo.fields.value
        guard case let .field(field, _) = item else { return }
        guard let removeIndex = fields.firstIndex(of: field) else { return }
        fields.remove(at: removeIndex)
        editProfileInfo.fields.value = fields
    }
}

extension ProfileHeaderViewModel {
    
    static func normalize(note: String?) -> String? {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines),!note.isEmpty else {
            return nil
        }
        
        let html = try? HTML(html: note, encoding: .utf8)
        return html?.text
    }
    
    // check if profile change or not
    func isProfileInfoEdited() -> Bool {
        guard isEditing.value else { return false }
        
        guard editProfileInfo.name.value == displayProfileInfo.name.value else { return true }
        guard case let .image(image) =  editProfileInfo.avatarImageResource.value, image == nil else { return true }
        guard editProfileInfo.note.value == ProfileHeaderViewModel.normalize(note: displayProfileInfo.note.value) else { return true }
        let isFieldsEqual: Bool = {
            let originalFields = self.accountForEdit.value?.source?.fields?.compactMap { field in
                ProfileFieldItem.FieldValue(name: field.name, value: field.value)
            } ?? []
            let editFields = editProfileInfo.fields.value
            guard editFields.count == originalFields.count else { return false }
            for (editField, originalField) in zip(editFields, originalFields) {
                guard editField.name.value == originalField.name.value,
                      editField.value.value == originalField.value.value else {
                    return false
                }
            }
            return true
        }()
        guard isFieldsEqual else { return true }
        
        return false
    }
    
    func updateProfileInfo() -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Account>, Error> {
        guard let activeMastodonAuthenticationBox = context.authenticationService.activeMastodonAuthenticationBox.value else {
            return Fail(error: APIService.APIError.implicit(.badRequest)).eraseToAnyPublisher()
        }
        let domain = activeMastodonAuthenticationBox.domain
        let authorization = activeMastodonAuthenticationBox.userAuthorization
        
        let image: UIImage? = {
            guard case let .image(_image) = editProfileInfo.avatarImageResource.value else { return nil }
            guard let image = _image else { return nil }
            guard image.size.width <= MastodonRegisterViewController.avatarImageMaxSizeInPixel.width else {
                return image.af.imageScaled(to: MastodonRegisterViewController.avatarImageMaxSizeInPixel)
            }
            return image
        }()
        
        let fieldsAttributes = editProfileInfo.fields.value.map { fieldValue in
            Mastodon.Entity.Field(name: fieldValue.name.value, value: fieldValue.value.value)
        }
        
        let query = Mastodon.API.Account.UpdateCredentialQuery(
            discoverable: nil,
            bot: nil,
            displayName: editProfileInfo.name.value,
            note: editProfileInfo.note.value,
            avatar: image.flatMap { Mastodon.Query.MediaAttachment.png($0.pngData()) },
            header: nil,
            locked: nil,
            source: nil,
            fieldsAttributes: fieldsAttributes
        )
        return context.apiService.accountUpdateCredentials(
            domain: domain,
            query: query,
            authorization: authorization
        )
    }
    
}
