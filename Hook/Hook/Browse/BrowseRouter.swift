//
//  BrowseRouter.swift
//  Hook
//
//  Created by Yeojin Yoon on 2022/01/02.
//

import RIBs

protocol BrowseInteractable: Interactable, TagListener, BookmarkListener {
    var router: BrowseRouting? { get set }
    var listener: BrowseListener? { get set }
}

protocol BrowseViewControllable: ViewControllable {
    func addChild(_ view: ViewControllable)
    func push(_ view: ViewControllable)
    func pop()
}

final class BrowseRouter: ViewableRouter<BrowseInteractable, BrowseViewControllable>, BrowseRouting {
    
    private let tag: TagBuildable
    private let bookmark: BookmarkBuildable
    
    private var tagRouter: Routing?
    private var bookmarkRouter: Routing?
    
    init(interactor: BrowseInteractable,
         viewController: BrowseViewControllable,
         tag: TagBuildable,
         bookmark: BookmarkBuildable) {
        self.tag = tag
        self.bookmark = bookmark
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }
    
    func attachTag() {
        guard tagRouter == nil else { return }
        let router = tag.build(withListener: interactor)
        tagRouter = router
        attachChild(router)
    }
    
    func attachBookmark() {
        guard bookmarkRouter == nil else { return }
        let router = bookmark.build(withListener: interactor)
        bookmarkRouter = router
        attachChild(router)
    }
}
