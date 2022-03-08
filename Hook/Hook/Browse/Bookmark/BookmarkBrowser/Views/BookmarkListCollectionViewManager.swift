//
//  BookmarkListCollectionViewManager.swift
//  Hook
//
//  Created by Yeojin Yoon on 2022/02/22.
//

import CoreData
import UIKit

final class BookmarkListCollectionViewManager: NSObject {
    
    private let bookmarkRepository = BookmarkRepository.shared
    private let fetchedResultsControllerDelegate: FetchedResultsControllerDelegate

    private var isForAll = false
    private var fetchedResultsControllerForAll: NSFetchedResultsController<BookmarkEntity>?
    private var fetchedResultsControllerForTag: NSFetchedResultsController<BookmarkTagEntity>?
    private var bookmarkEntityForContextMenu: BookmarkEntity?

    init(collectionView: UICollectionView, tag: Tag) {
        self.fetchedResultsControllerDelegate = FetchedResultsControllerDelegate(collectionView: collectionView)
        super.init()
        if tag.name == TagName.all {
            self.isForAll = true
            self.fetchedResultsControllerForAll = bookmarkRepository.fetchedResultsController()
            self.fetchedResultsControllerForAll?.delegate = fetchedResultsControllerDelegate
            try? self.fetchedResultsControllerForAll?.performFetch()
        } else {
            self.fetchedResultsControllerForTag = bookmarkRepository.fetchedResultsController(for: tag)
            self.fetchedResultsControllerForTag?.delegate = fetchedResultsControllerDelegate
            try? self.fetchedResultsControllerForTag?.performFetch()
        }
    }
    
    private func bookmarkEntity(at indexPath: IndexPath) -> BookmarkEntity? {
        return isForAll ? fetchedResultsControllerForAll?.object(at: indexPath) : fetchedResultsControllerForTag?.object(at: indexPath).bookmark
    }
}

// MARK: - Data Source

extension BookmarkListCollectionViewManager: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isForAll {
            guard let fetchedObjects = fetchedResultsControllerForAll?.fetchedObjects else { return 0 }
            return fetchedObjects.count
        } else {
            guard let fetchedObjects = fetchedResultsControllerForTag?.fetchedObjects else { return 0 }
            return fetchedObjects.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: BookmarkListCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath)
        guard let bookmarkEntity = bookmarkEntity(at: indexPath) else { return cell }
        let viewModel = BookmarkViewModel(with: bookmarkEntity)
        cell.configure(with: viewModel)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                               withReuseIdentifier: String(describing: UICollectionReusableView.self),
                                                               for: indexPath)
    }
}

// MARK: - Prefetching

extension BookmarkListCollectionViewManager: UICollectionViewDataSourcePrefetching {
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach {
            guard let bookmarkEntity = bookmarkEntity(at: $0) else { return }
            guard let url = URL(string: bookmarkEntity.urlString) else { return }
            ThumbnailLoader.shared.loadThumbnail(for: url) { _ in }
        }
    }
}

// MARK: - Delegate

extension BookmarkListCollectionViewManager: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let collectionView = collectionView as? BookmarkListCollectionView else { return nil }
        guard let listener = collectionView.listener else { return nil }
        bookmarkEntityForContextMenu = bookmarkEntity(at: indexPath)
        
        let shareAction = UIAction(title: LocalizedString.ActionTitle.share, image: UIImage(systemName: "square.and.arrow.up")) { _ in }
        let copyURLAction = UIAction(title: LocalizedString.ActionTitle.copyURL, image: UIImage(systemName: "link")) { _ in }
        let addToFavoritesAction = UIAction(title: LocalizedString.ActionTitle.addToFavorites, image: UIImage(systemName: "bookmark")) { _ in }
        
        let editAction = UIAction(title: LocalizedString.ActionTitle.edit, image: UIImage(systemName: "pencil")) { _ in
            guard let bookmark = self.bookmarkEntityForContextMenu?.converted() else { return }
            listener.contextMenuEditDidTap(bookmark: bookmark)
        }
        
        let deleteAction = UIAction(title: LocalizedString.ActionTitle.delete, image: UIImage(systemName: "minus.circle"), attributes: .destructive) { _ in
            listener.contextMenuDeleteDidTap(title: LocalizedString.AlertTitle.deleteBookmark,
                                             message: LocalizedString.AlertMessage.deleteBookmark,
                                             action: AlertAction(title: LocalizedString.ActionTitle.delete, handler: self.delete))
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            return UIMenu(title: "", children: [shareAction, copyURLAction, addToFavoritesAction, editAction, deleteAction])
        }
    }
    
    @objc
    private func delete() {
        guard let bookmarkEntity = bookmarkEntityForContextMenu else { return }
        let result = bookmarkRepository.delete(bookmarkEntity)
        switch result {
        case .success(()): break
        case .failure(_): NotificationCenter.post(named: NotificationName.Bookmark.didFailToDeleteBookmark)
        }
    }
}

// MARK: - Layout

extension BookmarkListCollectionViewManager: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let defaultHeight = CGFloat(84)
        let defaultSize = CGSize(width: collectionView.frame.width - 40, height: defaultHeight)
        guard let bookmarkEntity = bookmarkEntity(at: indexPath) else { return defaultSize }
        let fittingSize = BookmarkListCollectionViewCell.fittingSize(with: bookmarkEntity, width: defaultSize.width)
        return fittingSize.height > defaultHeight ? fittingSize : defaultSize
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 100)
    }
}
