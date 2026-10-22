//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class CollectionViewControllerWithContextActions: UICollectionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13, *) {
        } else {
            let longPressGestureRecognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(didLongPressCollectionView))
            collectionView.addGestureRecognizer(longPressGestureRecognizer)
        }
    }
    
    func getContextActionsForItem(at indexPath: IndexPath) -> [ContextualAction] {
        return []
    }
    
    #if compiler(>=5.1)
    @available(iOS 9, *)
    func collectionView(
        _ collectionView: UICollectionView,
        canEditItemAt indexPath: IndexPath
    ) -> Bool {
        let itemActions = getContextActionsForItem(at: indexPath)
        return itemActions.count > 0
    }
    #endif
    
    
    @objc
    func didLongPressCollectionView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let point = gestureRecognizer.location(in: collectionView)
        guard gestureRecognizer.state == .began,
              let indexPath = collectionView.indexPathForItem(at: point),
              canEditItem(at: indexPath)
        else { return }
        let actions = getContextActionsForItem(at: indexPath)
        showActionsPopover(actions, at: indexPath)
    }

    private func canEditItem(at indexPath: IndexPath) -> Bool {
        #if compiler(>=5.1)
        return collectionView(collectionView, canEditItemAt: indexPath)
        #else
        return getContextActionsForItem(at: indexPath).count > 0
        #endif
    }
    
    internal func showActionsPopover(_ actions: [ContextualAction], at indexPath: IndexPath) {
        guard actions.count > 0 else { 
            return
        }
        
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actions.forEach {
            menu.addAction($0.toAlertAction())
        }
        
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        menu.addAction(cancelAction)
        
        let popoverAnchor = PopoverAnchor(collectionView: collectionView, at: indexPath)
        if let popover = menu.popoverPresentationController {
            popoverAnchor.apply(to: popover)
        }
        present(menu, animated: true)
    }
}
