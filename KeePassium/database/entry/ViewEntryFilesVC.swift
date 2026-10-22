//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class ViewEntryFilesVC: UITableViewController, Refreshable {
    private enum CellID {
        static let fileItem = "FileItemCell"
        static let noFiles = "NoFilesCell"
    }
    
    private weak var entry: Entry?
    private var exportController: UIDocumentInteractionController!

    static func make(
        with entry: Entry?,
        historyMode: Bool
    ) -> ViewEntryFilesVC {
        let viewEntryFilesVC = ViewEntryFilesVC.instantiateFromStoryboard()
        viewEntryFilesVC.entry = entry
        return viewEntryFilesVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        entry?.touch(.accessed)
        
        navigationItem.rightBarButtonItem = nil
        tableView.rowHeight = 58
        
        exportController = UIDocumentInteractionController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        tableView.isEditing = false
        refresh()
    }
    
    func refresh() {
        tableView.reloadData()
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1 
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let entry = entry else { return 0 }
        return max(1, entry.attachments.count) // at least one for "Nothing here"
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        guard let entry = entry else { fatalError() }
        guard entry.attachments.count > 0 else {
            return tableView.dequeueReusableCell(withIdentifier: CellID.noFiles, for: indexPath)
        }
        
        if indexPath.row < entry.attachments.count {
            let att = entry.attachments[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.fileItem, for: indexPath)
            cell.imageView?.image = att.getSystemIcon()
            cell.textLabel?.text = att.name
            cell.detailTextLabel?.text = ByteCountFormatter.string(
                fromByteCount: Int64(att.size),
                countStyle: .file
            )
            return cell
        }
        return tableView.dequeueReusableCell(withIdentifier: CellID.noFiles, for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let attachments = entry?.attachments else { return }
        guard let sourceCell = tableView.cellForRow(at: indexPath) else { return }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        entry?.touch(.accessed)
        let row = indexPath.row
        if row < attachments.count {
            didPressExportAttachment(attachments[row], sourceCell: sourceCell)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    

    private func didPressExportAttachment(_ att: Attachment, sourceCell: UITableViewCell) {
        
        guard let encodedAttName = att.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let fileName = URL(string: encodedAttName)?.lastPathComponent else
        {
            Diag.warning("Failed to create a URL from attachment name [att.name: \(att.name)]")
            let alert = UIAlertController.make(title: LString.titleFileExportError, message: nil)
            present(alert, animated: true, completion: nil)
            return
        }
        
        do {
            let exportFileURL = (try TemporaryFileURL(fileName: fileName)).url
            let uncompressedBytes = att.isCompressed ? try att.data.gunzipped() : att.data
            try uncompressedBytes.write(to: exportFileURL, options: [.completeFileProtection])
            exportController.url = exportFileURL
            exportController.delegate = self
            Diag.info("Will present attachment")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !self.exportController.presentPreview(animated: true) {
                    Diag.verbose("Preview not available, showing menu")
                    self.exportController.presentOptionsMenu(
                        from: sourceCell.frame,
                        in: self.tableView,
                        animated: true)
                }
            }
        } catch {
            Diag.error("Failed to write attachment [reason: \(error.localizedDescription)]")
            let alert = UIAlertController.make(
                title: LString.titleFileExportError,
                message: error.localizedDescription)
            present(alert, animated: true, completion: nil)
        }
    }
}

extension ViewEntryFilesVC: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
        ) -> UIViewController
    {
        return navigationController! 
    }
}
