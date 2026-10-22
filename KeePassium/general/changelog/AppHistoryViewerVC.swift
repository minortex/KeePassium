//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppHistoryItemCell: UITableViewCell {
    fileprivate static let storyboardID = "LogItemCell"
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
}

class AppHistoryFallbackCell: UITableViewCell {
    fileprivate static let storyboardID = "FallbackCell"
}

class AppHistoryViewerVC: UITableViewController {
    var appHistory: AppHistory? {
        didSet {
            updateSections()
        }
    }
    
    enum TableSection {
        case historySection(section: AppHistory.Section)
    }
    
    private var sections = [TableSection]()
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()
    
    private func updateSections() {
        sections.removeAll()
        defer {
            tableView.reloadData()
        }
        
        guard let appHistory = appHistory else { return }
        
        sections = appHistory.sections.map {
            TableSection.historySection(section: $0)
        }
    }
}


extension AppHistoryViewerVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .historySection(section: let appHistorySection):
            return appHistorySection.items.count
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int)
        -> String?
    {
        switch sections[section] {
        case .historySection(section: let sectionInfo):
            let formattedDate = dateFormatter.string(from: sectionInfo.releaseDate)
            return "v\(sectionInfo.version) (\(formattedDate))"
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.text = self.tableView(tableView, titleForHeaderInSection: section)
        }
    }
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        switch sections[indexPath.section] {
        case .historySection(section: let releaseInfo):
            let cell = tableView
                .dequeueReusableCell(withIdentifier: AppHistoryItemCell.storyboardID)
                as! AppHistoryItemCell
            let item = releaseInfo.items[indexPath.row]
            setupCell(cell, item: item)
            return cell
        }
    }
    
    private func setupCell(_ cell: AppHistoryItemCell, item: AppHistory.Item) {
        cell.titleLabel.text = item.title
        cell.detailLabel.text = ""
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.tintColor = .auxiliaryText
    }
}

private class PremiumBadgeAccessory: UIImageView {
    required init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
        image = UIImage(asset: .premiumFeatureBadge)
        contentMode = .scaleAspectFill
        accessibilityLabel = "Premium"
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
}
