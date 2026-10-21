//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class GroupViewListCell: UITableViewCell {
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
}

final class ViewGroupVC:
    TableViewControllerWithContextActions,
    Refreshable
{
    private enum CellID {
        static let emptyGroup = "EmptyGroupCell"
        static let group = "GroupCell"
        static let entry = "EntryCell"
        static let nothingFound = "NothingFoundCell"
    }
    
    @IBOutlet fileprivate weak var groupIconView: UIImageView!
    @IBOutlet fileprivate weak var groupTitleLabel: UILabel!
    @IBOutlet weak var sortOrderButton: UIBarButtonItem!

    weak var group: Group? {
        didSet {
            if let group = group {
                groupTitleLabel.setText(group.name, strikethrough: group.isExpired)
                groupIconView.image = UIImage.kpIcon(forGroup: group)
            } else {
                groupTitleLabel.text = nil
                groupIconView.image = nil
            }
            sortGroupItems()
        }
    }

    var isGroupEmpty: Bool {
        return groupsSorted.isEmpty && entriesSorted.isEmpty
    }
    
    private var groupsSorted = Array<Weak<Group>>()
    private var entriesSorted = Array<Weak<Entry>>()

    private var isActivateSearch: Bool = false
    private var searchHelper = SearchHelper()
    private var searchResults = [GroupedEntries]()
    private var searchController: UISearchController!
    var isSearchActive: Bool {
        guard let searchController = searchController else { return false }
        return searchController.isActive && (searchController.searchBar.text?.isNotEmpty ?? false)
    }
    
    private var loadingWarnings: DatabaseLoadingWarnings?
    
    private var groupChangeNotifications: GroupChangeNotifications!
    private var entryChangeNotifications: EntryChangeNotifications!
    private var settingsNotifications: SettingsNotifications!

    static func make(group: Group?, loadingWarnings: DatabaseLoadingWarnings?=nil) -> ViewGroupVC {
        let viewGroupVC = ViewGroupVC.instantiateFromStoryboard()
        viewGroupVC.group = group
        viewGroupVC.loadingWarnings = loadingWarnings
        group?.touch(.accessed)
        return viewGroupVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        
        tableView.delegate = self
        tableView.dataSource = self
        if !(splitViewController?.isCollapsed ?? true) {
            handleItemSelection(indexPath: nil)
        }

        toolbarItems?.removeAll {
            $0.action == #selector(didPressChangeDatabaseSettings(_:))
        }
        
        isActivateSearch = Settings.current.isStartWithSearch && (group?.isRoot ?? false)
        
        groupChangeNotifications = GroupChangeNotifications(observer: self)
        entryChangeNotifications = EntryChangeNotifications(observer: self)
        settingsNotifications = SettingsNotifications(observer: self)
        
        searchController = UISearchController(searchResultsController: nil)
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = true
        } else {
            tableView.tableHeaderView = searchController.searchBar
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        entryChangeNotifications.startObserving()
        groupChangeNotifications.startObserving()
        settingsNotifications.startObserving()
        refresh()
        
        DispatchQueue.main.async { [weak self] in
            self?.setupSearch()
        }
        
        if let warnings = loadingWarnings, !warnings.isEmpty {
            showLoadingWarnings(warnings)
            loadingWarnings = nil 
        }
        
    }
    
    override func didMove(toParent parent: UIViewController?) {
        guard let group = group else { return }
        
        if DatabaseManager.shared.isDatabaseOpen {
            if parent == nil && group.isRoot {
                DatabaseManager.shared.closeDatabase(clearStoredKey: false, ignoreErrors: false) {
                    [weak self] (error) in
                    if let error = error {
                        self?.navigationController?.showErrorAlert(error)
                    } else {
                        Diag.debug("Database locked on leaving the root group")
                    }
                }
            }
        }
        super.didMove(toParent: parent)
    }

    override func viewDidDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        groupChangeNotifications.stopObserving()
        entryChangeNotifications.stopObserving()
        
        super.viewDidDisappear(animated)
    }
    
    private func showLoadingWarnings(_ warnings: DatabaseLoadingWarnings) {
        guard !warnings.isEmpty else { return }
        
        let alert = UIAlertController(
            title: NSLocalizedString(
                "[Database/Opened/Warning/title] Your database is ready, but there was an issue.",
                value: "Your database is ready, but there was an issue.",
                comment: "Title of a warning message, shown after opening a problematic database"),
            message: warnings.messages.joined(separator: "\n\n"),
            preferredStyle: .alert)
        let continueAction = UIAlertAction(
            title: NSLocalizedString(
                "[Database/Opened/Warning/action] Ignore and Continue",
                value: "Ignore and Continue",
                comment: "Action: ignore warnings and proceed to work with the database"),
            style: .default,
            handler: nil)
        let lockDatabaseAction = UIAlertAction(
            title: NSLocalizedString(
                "[Database/Opened/Warning/action] Close Database",
                value: "Close Database",
                comment: "Action: lock database"),
            style: .cancel,
            handler: { (action) in
                DatabaseManager.shared.closeDatabase(clearStoredKey: true, ignoreErrors: false) {
                    [weak self] (error) in
                    if let error = error {
                        self?.showErrorAlert(error)
                    } else {
                        Diag.debug("Database locked from a loading warning")
                    }
                }
            }
        )
        alert.addAction(continueAction)
        alert.addAction(lockDatabaseAction)
        present(alert, animated: true, completion: nil)
    }
        
    
    private func setupSearch() {
        searchController.searchBar.searchBarStyle = .default
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.barStyle = .default
        if #available(iOS 13, *) {
        } else {
            searchController.dimsBackgroundDuringPresentation = false
        }
        if #available(iOS 9.0, *) {
            searchController.obscuresBackgroundDuringPresentation = false
        }
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.delegate = self

        definesPresentationContext = true
        searchController.searchResultsUpdater = self

        if isActivateSearch {
            isActivateSearch = false 
            searchController.searchBar.becomeFirstResponder()
        }
    }

    
    func refresh() {
        refreshSortOrderButton()
        if isSearchActive {
            updateSearchResults(for: searchController)
        } else {
            sortGroupItems()
        }
        tableView.reloadData()
    }

    private func sortGroupItems() {
        groupsSorted.removeAll()
        entriesSorted.removeAll()
        guard let group = self.group else { return }
        
        let groupSortOrder = Settings.current.groupSortOrder
        let _groupsSorted = group.groups.sorted { return groupSortOrder.compare($0, $1) }
        let _entriesSorted = group.entries.sorted { return groupSortOrder.compare($0, $1) }
        
        for subgroup in _groupsSorted {
            groupsSorted.append(Weak(subgroup))
        }
        for entry in _entriesSorted {
            entriesSorted.append(Weak(entry))
        }
    }
    
    private func refreshSortOrderButton() {
        sortOrderButton.image = Settings.current.groupSortOrder.toolbarIcon
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if isSearchActive {
            return searchResults.isEmpty ? 1 : searchResults.count
        } else {
            return 1
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int) -> String?
    {
        if isSearchActive {
            return searchResults.isEmpty ? nil : searchResults[section].group.name
        } else {
            return nil
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int) -> Int
    {
        if isSearchActive {
            if section < searchResults.count {
                return searchResults[section].entries.count
            } else {
                return (section == 0 ? 1 : 0)
            }
        } else {
            if isGroupEmpty {
                return 1 // for "Nothing here" cell
            } else {
                return groupsSorted.count + entriesSorted.count
            }
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if isSearchActive {
            return getSearchResultCell(at: indexPath)
        } else {
            return getGroupItemCell(at: indexPath)
        }
    }
    
    private func getSearchResultCell(at indexPath: IndexPath) -> UITableViewCell {
        if isSearchActive && searchResults.isEmpty {
            return tableView.dequeueReusableCell(
                withIdentifier: CellID.nothingFound,
                for: indexPath)
        }

        let entry = searchResults[indexPath.section].entries[indexPath.row].entry
        let entryCell = tableView.dequeueReusableCell(
            withIdentifier: CellID.entry,
            for: indexPath)
            as! GroupViewListCell
        setupCell(
            entryCell,
            title: entry.resolvedTitle,
            subtitle: getDetailInfo(forEntry: entry),
            image: UIImage.kpIcon(forEntry: entry),
            isExpired: entry.isExpired,
            itemCount: nil)
        setupAccessibilityActions(entryCell, entry: entry)
        return entryCell
    }
    
    private func getGroupItemCell(at indexPath: IndexPath) -> UITableViewCell {
        if isGroupEmpty {
            return tableView.dequeueReusableCell(withIdentifier: CellID.emptyGroup, for: indexPath)
        }
        
        if indexPath.row < groupsSorted.count {
            guard let group = groupsSorted[indexPath.row].value else {
                assertionFailure()
                return tableView.dequeueReusableCell(withIdentifier: CellID.group, for: indexPath)
            }
            let groupCell = tableView.dequeueReusableCell(
                withIdentifier: CellID.group,
                for: indexPath)
                as! GroupViewListCell
            let itemCount = group.groups.count + group.entries.count
            setupCell(
                groupCell,
                title: group.name,
                subtitle: "\(itemCount)",
                image: UIImage.kpIcon(forGroup: group),
                isExpired: group.isExpired,
                itemCount: itemCount)
            return groupCell
        } else {
            let entryIndex = indexPath.row - groupsSorted.count
            guard let entry = entriesSorted[entryIndex].value else {
                assertionFailure()
                return tableView.dequeueReusableCell(withIdentifier: CellID.entry, for: indexPath)
            }
            
            let entryCell = tableView.dequeueReusableCell(
                withIdentifier: CellID.entry,
                for: indexPath)
                as! GroupViewListCell
            setupCell(
                entryCell,
                title: entry.resolvedTitle,
                subtitle: getDetailInfo(forEntry: entry),
                image: UIImage.kpIcon(forEntry: entry),
                isExpired: entry.isExpired,
                itemCount: nil)
            setupAccessibilityActions(entryCell, entry: entry)
            return entryCell
        }
    }
    
    private func setupCell(
        _ cell: GroupViewListCell,
        title: String,
        subtitle: String?,
        image: UIImage?,
        isExpired: Bool,
        itemCount: Int?)
    {
        cell.titleLabel.setText(title, strikethrough: isExpired)
        cell.subtitleLabel?.setText(subtitle, strikethrough: isExpired)
        cell.iconView?.image = image
        
        if itemCount != nil {
            cell.accessibilityLabel = String.localizedStringWithFormat(
                LString.titleGroupDescriptionTemplate,
                title)
        }
    }
    
    private func setupAccessibilityActions(_ cell: GroupViewListCell, entry: Entry) {
        guard #available(iOS 13, *) else { return }
        
        var actions = [UIAccessibilityCustomAction]()
        
        let nonTitleFields = entry.fields.filter { $0.name != EntryField.title }
        nonTitleFields.reversed().forEach { (field) in
            let actionName = String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                field.name)
            let action = UIAccessibilityCustomAction(name: actionName) {
                [weak field] _ -> Bool in
                if let fieldValue = field?.resolvedValue {
                    Clipboard.general.insert(fieldValue)
                    if #available(iOS 11.0, *) {
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: LString.titleCopiedToClipboard
                        )
                    } else {
                        UIAccessibilityPostNotification(
                            UIAccessibilityAnnouncementNotification,
                            LString.titleCopiedToClipboard
                        )
                    }
                }
                return true
            }
            actions.append(action)
        }
        cell.accessibilityCustomActions = actions
    }

    func getDetailInfo(forEntry entry: Entry) -> String? {
        switch Settings.current.entryListDetail {
        case .none:
            return nil
        case .userName:
            return entry.getField(EntryField.userName)?.resolvedValue
        case .password:
            return entry.getField(EntryField.password)?.resolvedValue
        case .url:
            return entry.getField(EntryField.url)?.resolvedValue
        case .notes:
            return entry.getField(EntryField.notes)?
                .resolvedValue
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
        case .lastModifiedDate:
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: entry.lastModificationTime)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSearchActive {
            handleItemSelection(indexPath: indexPath)
        } else {
            if !isGroupEmpty {
                handleItemSelection(indexPath: indexPath)
            }
        }
    }
    
    func getGroup(at indexPath: IndexPath) -> Group? {
        if isSearchActive {
            return nil
        } else {
            guard indexPath.row < groupsSorted.count else { return nil }
            return groupsSorted[indexPath.row].value
        }
    }
    
    func getEntry(at indexPath: IndexPath) -> Entry? {
        if isSearchActive {
            guard indexPath.section < searchResults.count else { return  nil }
            let searchResult = searchResults[indexPath.section]
            guard indexPath.row < searchResult.entries.count else { return nil }
            return searchResult.entries[indexPath.row].entry
        } else {
            let entryIndex = indexPath.row - groupsSorted.count
            guard entryIndex >= 0 && entryIndex < entriesSorted.count else { return nil }
            return entriesSorted[entryIndex].value
        }
    }

    func getItem(at indexPath: IndexPath) -> DatabaseItem? {
        if let entry = getEntry(at: indexPath) {
            return entry
        }
        if let group = getGroup(at: indexPath) {
            return group
        }
        return nil
    }
    
    func handleItemSelection(indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            let placeholderVC = PlaceholderVC.make()
            showDetailViewController(placeholderVC, sender: self)
            return
        }
        
        if let selectedGroup = getGroup(at: indexPath) {
            
            tableView.deselectRow(at: indexPath, animated: false)
            
            let viewGroupVC = ViewGroupVC.make(group: selectedGroup)
            guard let leftNavController = splitViewController?.viewControllers.first
                as? UINavigationController else
            {
                assertionFailure()
                return
            }
            leftNavController.show(viewGroupVC, sender: self)
        } else if let selectedEntry = getEntry(at: indexPath) {
            if splitViewController?.isCollapsed ?? false {
                tableView.deselectRow(at: indexPath, animated: false)
            }
            let viewEntryVC = ViewEntryVC.make(with: selectedEntry)
            showDetailViewController(viewEntryVC, sender: self)
        }
    }
    
    
    override func getContextActionsForRow(
        at indexPath: IndexPath,
        forSwipe: Bool
    ) -> [ContextualAction] {
        return []
    }

    var diagnosticsViewerCoordinator: DiagnosticsViewerCoordinator?
    func showDiagnostics() {
        assert(diagnosticsViewerCoordinator == nil)
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator!.dismissHandler = { [weak self] coordinator in
            self?.diagnosticsViewerCoordinator = nil
        }
        diagnosticsViewerCoordinator!.start()
        present(modalRouter, animated: true, completion: nil)
    }
    
    @IBAction func didPressItemListSettings(_ sender: Any) {
        let itemListSettingsVC = SettingsItemListVC.make(
            barPopoverSource: sender as? UIBarButtonItem)
        present(itemListSettingsVC, animated: true, completion: nil)
    }
    
    @IBAction func didPressSettings(_ sender: Any) {
        let settingsVC = SettingsVC.make(popoverFromBar: sender as? UIBarButtonItem)
        present(settingsVC, animated: true, completion: nil)
    }
    
    @IBAction func didPressLockDatabase(_ sender: UIBarButtonItem) {
        let confirmationAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let lockDatabaseAction = UIAlertAction(title: LString.actionLockDatabase, style: .destructive) {
            (action) in
            DatabaseManager.shared.closeDatabase(clearStoredKey: true, ignoreErrors: false) {
                [weak self] (error) in
                if let error = error {
                    self?.showErrorAlert(error)
                } else {
                    Diag.debug("Database locked on user request")
                }
            }
        }
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        confirmationAlert.addAction(lockDatabaseAction)
        confirmationAlert.addAction(cancelAction)
        confirmationAlert.modalPresentationStyle = .popover
        if let popover = confirmationAlert.popoverPresentationController {
            popover.barButtonItem = sender
        }
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    @IBAction func didPressChangeDatabaseSettings(_ sender: Any) {
        // The database is read-only, so changing its master key is unavailable.
    }
}

extension ViewGroupVC: SettingsObserver {
    public func settingsDidChange(key: Settings.Keys) {
        let isRelevantChange =
                key == .entryListDetail ||
                key == .groupSortOrder ||
                key == .searchFieldNames ||
                key == .searchProtectedValues ||
                key == .databaseIconSet
        if isRelevantChange {
            refresh()
        }
    }
}

extension ViewGroupVC: EntryChangeObserver {
    func entryDidChange(entry: Entry) {
        refresh()
    }
}

extension ViewGroupVC: GroupChangeObserver {
    func groupDidChange(group: Group) {
        refresh()
    }
}


extension ViewGroupVC: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        guard let database = group?.database else { return }
        searchResults = searchHelper.find(database: database, searchText: searchText)
        sortSearchResults()
        tableView.reloadData()
    }
    
    private func sortSearchResults() {
        let groupSortOrder = Settings.current.groupSortOrder
        searchResults.sort { return groupSortOrder.compare($0.group, $1.group) }
    }
}

extension ViewGroupVC: UISearchControllerDelegate {
    public func didDismissSearchController(_ searchController: UISearchController) {
        refresh()
    }
}
