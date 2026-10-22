//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class TableViewControllerWithContextActions: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13, *) {
        } else {
            let longPressGestureRecognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(didLongPressTableView))
            tableView.addGestureRecognizer(longPressGestureRecognizer)
        }
    }
    
    func getContextActionsForRow(at indexPath: IndexPath, forSwipe: Bool) -> [ContextualAction] {
        return []
    }
    
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let rowActions = getContextActionsForRow(at: indexPath, forSwipe: true)
        return rowActions.count > 0
    }

    override func tableView(
        _ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath
    ) -> [UITableViewRowAction]? {
        if #available(iOS 13, *) { return nil }
        let actions = getContextActionsForRow(at: indexPath, forSwipe: true)
        guard !actions.isEmpty else { return nil }
        return actions.map { action in
            UITableViewRowAction(
                style: action.style == .destructive ? .destructive : .normal,
                title: action.title,
                handler: { _, _ in action.handler() })
        }
    }
    
    @objc func didLongPressTableView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let point = gestureRecognizer.location(in: tableView)
        guard gestureRecognizer.state == .began,
              let indexPath = tableView.indexPathForRow(at: point),
              tableView(tableView, canEditRowAt: indexPath)
        else { return }
        let actions = getContextActionsForRow(at: indexPath, forSwipe: false)
        showActionsPopover(actions, at: indexPath)
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
        
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        if let popover = menu.popoverPresentationController {
            popoverAnchor.apply(to: popover)
        }
        present(menu, animated: true)
    }
}
