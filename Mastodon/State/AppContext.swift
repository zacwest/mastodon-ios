//
//  AppContext.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-1-27.
//

import os.log
import UIKit
import Combine
import CoreData
import CoreDataStack
import AlamofireImage

class AppContext: ObservableObject {
    
    var disposeBag = Set<AnyCancellable>()
    
    @Published var viewStateStore = ViewStateStore()
        
    let coreDataStack: CoreDataStack
    let managedObjectContext: NSManagedObjectContext
    let backgroundManagedObjectContext: NSManagedObjectContext
    
    let apiService: APIService
    let authenticationService: AuthenticationService
    let emojiService: EmojiService
    let audioPlaybackService = AudioPlaybackService()
    let videoPlaybackService = VideoPlaybackService()
    let statusPrefetchingService: StatusPrefetchingService
    let statusPublishService = StatusPublishService()
    let notificationService: NotificationService
    let settingService: SettingService
    let instanceService: InstanceService

    let blockDomainService: BlockDomainService    
    let statusFilterService: StatusFilterService
    let photoLibraryService = PhotoLibraryService()

    let placeholderImageCacheService = PlaceholderImageCacheService()
    let blurhashImageCacheService = BlurhashImageCacheService()

    let documentStore: DocumentStore
    private var documentStoreSubscription: AnyCancellable!
    
    let overrideTraitCollection = CurrentValueSubject<UITraitCollection?, Never>(nil)
    let timestampUpdatePublisher = Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .share()
        .eraseToAnyPublisher()

    init() {
        let _coreDataStack = CoreDataStack()
        let _managedObjectContext = _coreDataStack.persistentContainer.viewContext
        let _backgroundManagedObjectContext = _coreDataStack.persistentContainer.newBackgroundContext()
        coreDataStack = _coreDataStack
        managedObjectContext = _managedObjectContext
        backgroundManagedObjectContext = _backgroundManagedObjectContext
        
        let _apiService = APIService(backgroundManagedObjectContext: _backgroundManagedObjectContext)
        apiService = _apiService
        
        let _authenticationService = AuthenticationService(
            managedObjectContext: _managedObjectContext,
            backgroundManagedObjectContext: _backgroundManagedObjectContext,
            apiService: _apiService
        )
        authenticationService = _authenticationService
        
        emojiService = EmojiService(
            apiService: apiService
        )
        
        statusPrefetchingService = StatusPrefetchingService(
            managedObjectContext: _managedObjectContext,
            backgroundManagedObjectContext: _backgroundManagedObjectContext,
            apiService: _apiService
        )
        let _notificationService = NotificationService(
            apiService: _apiService,
            authenticationService: _authenticationService
        )
        notificationService = _notificationService
        
        settingService = SettingService(
            apiService: _apiService,
            authenticationService: _authenticationService,
            notificationService: _notificationService
        )
        
        instanceService = InstanceService(
            apiService: _apiService,
            authenticationService: _authenticationService
        )
        
        blockDomainService = BlockDomainService(
            backgroundManagedObjectContext: _backgroundManagedObjectContext,
            authenticationService: _authenticationService
        )

        statusFilterService = StatusFilterService(
            apiService: _apiService,
            authenticationService: _authenticationService
        )
        
        documentStore = DocumentStore()
        documentStoreSubscription = documentStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                self.objectWillChange.send()
            }
        
        backgroundManagedObjectContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: backgroundManagedObjectContext)
            .sink { [weak self] notification in
                guard let self = self else { return }
                self.managedObjectContext.perform {
                    self.managedObjectContext.mergeChanges(fromContextDidSave: notification)
                }
            }
            .store(in: &disposeBag)
    }
    
}

extension AppContext {
    
    typealias ByteCount = Int
    
    static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        return formatter
    }()
    
    private static let purgeCacheWorkingQueue = DispatchQueue(label: "org.joinmastodon.app.AppContext.purgeCacheWorkingQueue")
    
    func purgeCache() -> AnyPublisher<ByteCount, Never> {
        Publishers.MergeMany([
            AppContext.purgeAlamofireImageCache(),
            AppContext.purgeTemporaryDirectory(),
        ])
        .reduce(0, +)
        .eraseToAnyPublisher()
    }
    
    private static func purgeAlamofireImageCache() -> AnyPublisher<ByteCount, Never> {
        Future<ByteCount, Never> { promise in
            AppContext.purgeCacheWorkingQueue.async {
                // clean image cache for AlamofireImage
                let diskBytes = ImageDownloader.defaultURLCache().currentDiskUsage
                ImageDownloader.defaultURLCache().removeAllCachedResponses()
                let currentDiskBytes = ImageDownloader.defaultURLCache().currentDiskUsage
                let purgedDiskBytes = max(0, diskBytes - currentDiskBytes)
                os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: purge AlamofireImage cache bytes: %ld -> %ld (%ld)", ((#file as NSString).lastPathComponent), #line, #function, diskBytes, currentDiskBytes, purgedDiskBytes)
                promise(.success(purgedDiskBytes))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private static func purgeTemporaryDirectory() -> AnyPublisher<ByteCount, Never> {
        Future<ByteCount, Never> { promise in
            AppContext.purgeCacheWorkingQueue.async {
                let fileManager = FileManager.default
                let temporaryDirectoryURL = fileManager.temporaryDirectory
                
                let resourceKeys = Set<URLResourceKey>([.fileSizeKey, .isDirectoryKey])
                guard let directoryEnumerator = fileManager.enumerator(
                    at: temporaryDirectoryURL,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: .skipsHiddenFiles
                ) else {
                    promise(.success(0))
                    return
                }
                 
                var fileURLs: [URL] = []
                var totalFileSizeInBytes = 0
                for case let fileURL as URL in directoryEnumerator {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                          let isDirectory = resourceValues.isDirectory else {
                        continue
                    }
                    
                    guard !isDirectory else {
                        continue
                    }
                    fileURLs.append(fileURL)
                    totalFileSizeInBytes += resourceValues.fileSize ?? 0
                }
                
                for fileURL in fileURLs {
                    try? fileManager.removeItem(at: fileURL)
                }
                
                promise(.success(totalFileSizeInBytes))
            }
        }
        .eraseToAnyPublisher()
    }

}
