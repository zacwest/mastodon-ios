//
//  PublicTimelineViewController+Provider.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/1/27.
//

import os.log
import UIKit
import Combine
import CoreData
import CoreDataStack
import MastodonSDK

// MARK: - StatusProvider
extension PublicTimelineViewController: StatusProvider {

    func status() -> Future<Status?, Never> {
        return Future { promise in promise(.success(nil)) }
    }
    
    func status(for cell: UITableViewCell?, indexPath: IndexPath?) -> Future<Status?, Never> {
        return Future { promise in
            guard let diffableDataSource = self.viewModel.diffableDataSource else {
                assertionFailure()
                promise(.success(nil))
                return
            }
            guard let indexPath = indexPath ?? cell.flatMap({ self.tableView.indexPath(for: $0) }),
                  let item = diffableDataSource.itemIdentifier(for: indexPath) else {
                promise(.success(nil))
                return
            }
            
            switch item {
            case .status(let objectID, _):
                let managedObjectContext = self.viewModel.fetchedResultsController.managedObjectContext
                managedObjectContext.perform {
                    let status = managedObjectContext.object(with: objectID) as? Status
                    promise(.success(status))
                }
            default:
                promise(.success(nil))
            }
        }
    }
    
    func status(for cell: UICollectionViewCell) -> Future<Status?, Never> {
        return Future { promise in promise(.success(nil)) }
    }
    
    var managedObjectContext: NSManagedObjectContext {
        return viewModel.fetchedResultsController.managedObjectContext
    }
    
    var tableViewDiffableDataSource: UITableViewDiffableDataSource<StatusSection, Item>? {
        return viewModel.diffableDataSource
    }
    
    func item(for cell: UITableViewCell?, indexPath: IndexPath?) -> Item? {
        guard let diffableDataSource = self.viewModel.diffableDataSource else {
            assertionFailure()
            return nil
        }
        guard let indexPath = indexPath ?? cell.flatMap({ self.tableView.indexPath(for: $0) }),
              let item = diffableDataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        
        return item
    }
    
    func items(indexPaths: [IndexPath]) -> [Item] {
        guard let diffableDataSource = self.viewModel.diffableDataSource else {
            assertionFailure()
            return []
        }
        
        var items: [Item] = []
        for indexPath in indexPaths {
            guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { continue }
            items.append(item)
        }
        return items
    }

    func statusObjectItems(indexPaths: [IndexPath]) -> [StatusObjectItem] {
        guard let diffableDataSource = self.viewModel.diffableDataSource else { return [] }
        let items = indexPaths.compactMap { diffableDataSource.itemIdentifier(for: $0)?.statusObjectItem }
        return items
    }
    
}

extension PublicTimelineViewController: UserProvider {}
