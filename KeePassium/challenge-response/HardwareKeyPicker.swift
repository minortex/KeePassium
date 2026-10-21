//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol HardwareKeyPickerDelegate: class {
    func didDismiss(_ picker: HardwareKeyPicker)
    func didSelectKey(yubiKey: YubiKey?, in picker: HardwareKeyPicker)
}

class HardwareKeyPicker: UITableViewController, Refreshable {
    weak var delegate: HardwareKeyPickerDelegate?
    
    public var key: YubiKey? {
        didSet { refresh() }
    }
    
    public let dismissablePopoverDelegate = DismissablePopover(leftButton: .cancel, rightButton: nil)

    private enum Section: Int {
        static let allValues = [Section.noHardwareKey]
        case noHardwareKey
        var title: String? {
            switch self {
            case .noHardwareKey:
                return nil
            }
        }
    }
    private var isChoiceMade = false
    
    public static func create(delegate: HardwareKeyPickerDelegate?=nil) -> HardwareKeyPicker {
        let vc = HardwareKeyPicker.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        tableView.removeObserver(self, forKeyPath: "contentSize")
        super.viewWillDisappear(animated)
        if !isChoiceMade {
            delegate?.didDismiss(self)
        }
    }
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?)
    {
        var preferredSize = tableView.contentSize
        if #available(iOS 13, *) {
            preferredSize.width = 400
        }
        self.preferredContentSize = preferredSize
    }
    
    func refresh() {
        tableView.reloadData()
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allValues.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            assertionFailure()
            return 0
        }
        return section == .noHardwareKey ? 1 : 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            assertionFailure()
            return nil
        }
        return section.title
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let _section = Section(rawValue: section) else { assertionFailure(); return nil }

        return super.tableView(tableView, titleForFooterInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError()
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        cell.setEnabled(true)
        cell.isUserInteractionEnabled = true
        cell.textLabel?.text = getKeyDescription(nil)
        cell.accessoryType = self.key == nil ? .checkmark : .none
        return cell
    }
    
    private func getKeyDescription(_ key: YubiKey?) -> String {
        return NSLocalizedString(
            "[HardwareKey/None] No Hardware Key",
            value: "No Hardware Key",
            comment: "Master key/unlock option: don't use hardware keys")
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) != nil else {
            assertionFailure()
            return
        }
        
        didSelectKey(nil)
    }
    
    private func didSelectKey(_ key: YubiKey?) {
        isChoiceMade = true
        delegate?.didSelectKey(yubiKey: key, in: self)
        dismiss(animated: true, completion: nil)
    }
}

extension HardwareKeyPicker: UIPopoverPresentationControllerDelegate {

    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle
        ) -> UIViewController?
    {
        if style != .popover {
            let navVC = controller.presentedViewController as? UINavigationController
            let cancelButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(dismissPopover))
            navVC?.topViewController?.navigationItem.leftBarButtonItem = cancelButton
        }
        return nil // "keep existing"
    }
    
    @objc func dismissPopover() {
        dismiss(animated: true, completion: nil)
    }
}
