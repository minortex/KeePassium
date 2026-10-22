//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import MobileCoreServices
import KeePassiumLib


protocol FieldCopiedViewDelegate: class {
    func didPressExport(in view: FieldCopiedView, field: ViewableField)
}

class FieldCopiedView: UIView {
    weak var delegate: FieldCopiedViewDelegate?
    weak var field: ViewableField?
    
    weak var hidingTimer: Timer?
    
    public func show(in tableView: UITableView, at indexPath: IndexPath) {
        hide(animated: false)
        
        guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
        self.frame = cell.bounds
        self.layoutIfNeeded()
        cell.addSubview(self)
        
        self.alpha = 0.0
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: [.curveEaseOut, .allowUserInteraction] ,
            animations: { [weak self] in
                self?.backgroundColor = UIColor.actionTint
                self?.alpha = 0.9
            },
            completion: { [weak self] finished in
                guard let self = self else { return }
                tableView.deselectRow(at: indexPath, animated: false)
                self.hidingTimer = Timer.scheduledTimer(
                    timeInterval: 0.5,
                    target: self,
                    selector: #selector(self.hideCopiedView),
                    userInfo: nil,
                    repeats: false)
            }
        )
    }

    @objc private func hideCopiedView() {
        hide(animated: true)
    }
    
    public func hide(animated: Bool) {
        hidingTimer?.invalidate()
        hidingTimer = nil
        guard animated else {
            self.layer.removeAllAnimations()
            self.removeFromSuperview()
            return
        }
        UIView.animate(
            withDuration: 0.2,
            delay: 0.0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: { [weak self] in
                self?.backgroundColor = UIColor.actionTint
                self?.alpha = 0.0
            },
            completion: { [weak self] finished in
                if finished {
                    self?.removeFromSuperview()
                }
            }
        )
    }
    
    @IBAction func didPressExport(_ sender: UIButton) {
        guard let field = field else { return }
        delegate?.didPressExport(in: self, field: field)
    }
}


class ViewEntryFieldsVC: UITableViewController, Refreshable {
    @IBOutlet weak var copiedCellView: FieldCopiedView!
    
    private weak var entry: Entry?
    private var isHistoryMode = false
    private var sortedFields: [ViewableField] = []
    private var entryChangeNotifications: EntryChangeNotifications!
    
    static func make(with entry: Entry?, historyMode: Bool) -> ViewEntryFieldsVC {
        let viewEntryFieldsVC = ViewEntryFieldsVC.instantiateFromStoryboard()
        viewEntryFieldsVC.entry = entry
        viewEntryFieldsVC.isHistoryMode = historyMode
        return viewEntryFieldsVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = true
        
        copiedCellView.delegate = self
        
        entryChangeNotifications = EntryChangeNotifications(observer: self)
        entry?.touch(.accessed)
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.rightBarButtonItem = nil
        entryChangeNotifications.startObserving()
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        entryChangeNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }

    func refresh() {
        guard let entry = entry, let database = entry.database else { return }
        
        let category = ItemCategory.get(for: entry)
        let fields = ViewableEntryFieldFactory.makeAll(
            from: entry,
            in: database,
            excluding: [.title, .emptyValues]
        )
        self.sortedFields = fields.sorted {
            return category.compare($0.internalName, $1.internalName)
        }
        tableView.reloadData()
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedFields.count
    }

    override func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        let field = sortedFields[indexPath.row]
        if field is TOTPViewableField {
            return 80
        }

        let textScale = Settings.current.textScale
        let valueFont = UIFont.monospaceFont(ofSize: 17 * textScale, forTextStyle: .body)
        let availableWidth = tableView.bounds.width - 40
        let value = displayValue(for: field)
        let valueHeight = (value as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: valueFont],
            context: nil
        ).height
        let rowHeight = 8 + 20 + valueHeight + 24

        if field.internalName == EntryField.notes,
           field.isHeightConstrained,
           valueHeight > 150
        {
            return rowHeight - valueHeight + 150
        }
        return max(60, ceil(rowHeight))
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let fieldNumber = indexPath.row
        let field = sortedFields[fieldNumber]
        let cell = ViewableFieldCellFactory.dequeueAndConfigureCell(
            from: tableView,
            for: indexPath,
            field: field)
        cell.delegate = self
        return cell
    }

    func displayValue(for field: ViewableField) -> String {
        let shouldHideField =
            (field.isProtected || field.internalName == EntryField.password)
            && Settings.current.isHideProtectedFields
        if shouldHideField && field.isValueHidden {
            return "* * * *"
        }
        return field.decoratedValue ?? ""
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fieldNumber = indexPath.row
        let field = sortedFields[fieldNumber]
        guard let text = field.resolvedValue else { return }

        Clipboard.general.insert(text)
        entry?.touch(.accessed)
        animateCopyToClipboard(indexPath: indexPath, field: field)
    }
    
    func animateCopyToClipboard(indexPath: IndexPath, field: ViewableField) {
        copiedCellView.field = field
        HapticFeedback.play(.copiedToClipboard)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.copiedCellView.show(in: self.tableView, at: indexPath)
        }
    }
}

extension ViewEntryFieldsVC: EntryChangeObserver {
    func entryDidChange(entry: Entry) {
        refresh()
    }
}


extension ViewEntryFieldsVC: ViewableFieldCellDelegate {    
    func cellHeightDidChange(_ cell: ViewableFieldCell) {
        guard let viewableField = cell.field else { return }
        if let indexPath = tableView.indexPath(for: cell) {
            UIView.performWithoutAnimation { [weak self] in
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
        if viewableField.internalName == EntryField.notes {
            let isCollapsed = viewableField.isHeightConstrained
            Settings.current.isCollapseNotesField = isCollapsed
        }
    }
    
    func cellDidExpand(_ cell: ViewableFieldCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)
    }
    
    func didTapCellValue(_ cell: ViewableFieldCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    func didLongTapAccessoryButton(_ cell: ViewableFieldCell) {
        guard let value = cell.field?.resolvedValue else { return }
        guard let accessoryView = cell.accessoryView else { return }
        
        HapticFeedback.play(.contextMenuOpened)
        
        var items: [Any] = [value]
        if value.isOpenableURL, let url = URL(string: value) {
            items = [url]
        }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = accessoryView
            popover.sourceRect = accessoryView.bounds
        }
        present(activityVC, animated: true)
    }
}


extension ViewEntryFieldsVC: FieldCopiedViewDelegate {
    func didPressExport(in view: FieldCopiedView, field: ViewableField) {
        guard let value = field.resolvedValue else {
            assertionFailure()
            return
        }
        view.hide(animated: true)

        HapticFeedback.play(.contextMenuOpened)
        let activityController = UIActivityViewController(
            activityItems: [value],
            applicationActivities: nil)
        let popoverAnchor = PopoverAnchor(sourceView: view, sourceRect: view.bounds)
        popoverAnchor.apply(to: activityController.popoverPresentationController)
        present(activityController, animated: true)
    }
}
