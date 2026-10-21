//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib
import LocalAuthentication

class SettingsVC: UITableViewController, Refreshable {

    @IBOutlet weak var appSafetyCell: UITableViewCell!
    @IBOutlet weak var dataSafetyCell: UITableViewCell!
    @IBOutlet weak var dataBackupCell: UITableViewCell!
    @IBOutlet weak var autoFillCell: UITableViewCell!
    
    @IBOutlet weak var searchCell: UITableViewCell!
    @IBOutlet weak var autoUnlockStartupDatabaseSwitch: UISwitch!
    @IBOutlet weak var appearanceCell: UITableViewCell!
    
    @IBOutlet weak var diagnosticLogCell: UITableViewCell!
    @IBOutlet weak var contactSupportCell: UITableViewCell!
    @IBOutlet weak var rateTheAppCell: UITableViewCell!
    @IBOutlet weak var aboutAppCell: UITableViewCell!
    
    @IBOutlet weak var premiumTrialCell: UITableViewCell!
    @IBOutlet weak var premiumStatusCell: UITableViewCell!
    @IBOutlet weak var manageSubscriptionCell: UITableViewCell!
    @IBOutlet weak var appHistoryCell: UITableViewCell!
    
    private var settingsNotifications: SettingsNotifications!
    
    private var router: NavigationRouter! 
    private let isPremiumSectionHidden = true
    
    private enum CellIndexPath {
        static let premiumSectionIndex = 0
        static let premiumTrial = IndexPath(row: 0, section: premiumSectionIndex)
        static let premiumStatus = IndexPath(row: 1, section: premiumSectionIndex)
        static let manageSubscription = IndexPath(row: 2, section: premiumSectionIndex)
        static let appHistoryCell = IndexPath(row: 3, section: premiumSectionIndex)
    }
    private var hiddenIndexPaths = Set<IndexPath>()
    
    static func make(popoverFromBar barButtonSource: UIBarButtonItem?=nil) -> UIViewController {
        let vc = SettingsVC.instantiateFromStoryboard()
        
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .popover
        if let popover = navVC.popoverPresentationController {
            popover.barButtonItem = barButtonSource
        }
        navVC.presentationController?.delegate = vc
        vc.router = NavigationRouter(navVC)
        return navVC
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        
        settingsNotifications = SettingsNotifications(observer: self)
        hidePremiumCells()
        autoFillCell.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsNotifications.startObserving()
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }
    
    deinit {
        diagnosticsViewerCoordinator = nil
    }
    
    func dismissPopover(animated: Bool) {
        self.dismiss(animated: animated) { [self] in 
            self.diagnosticsViewerCoordinator = nil
        }
    }
    
    func refresh() {
        let settings = Settings.current
        
        autoUnlockStartupDatabaseSwitch.isOn = settings.isAutoUnlockStartupDatabase
        let biometryType = LAContext.getBiometryType()
        if let biometryTypeName = biometryType.name {
            appSafetyCell.detailTextLabel?.text = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Settings/AppLock/subtitle] App Lock, %@, timeout",
                    value: "App Lock, %@, timeout",
                    comment: "Settings: subtitle of the `App Protection` section. biometryTypeName will be either 'Touch ID' or 'Face ID'. [biometryTypeName: String]"),
                biometryTypeName)
        } else {
            appSafetyCell.detailTextLabel?.text =
                NSLocalizedString(
                    "[Settings/AppLock/subtitle] App Lock, passcode, timeout",
                    value: "App Lock, passcode, timeout",
                    comment: "Settings: subtitle of the `App Protection` section when biometric auth is not available.")
        }
        contactSupportCell.accessibilityValue = SupportEmailComposer.getSupportEmail()
    }

    private func hidePremiumCells() {
        premiumTrialCell.isHidden = true
        premiumStatusCell.isHidden = true
        manageSubscriptionCell.isHidden = true
        appHistoryCell.isHidden = true
        hiddenIndexPaths = Set([
            CellIndexPath.premiumTrial,
            CellIndexPath.premiumStatus,
            CellIndexPath.manageSubscription,
            CellIndexPath.appHistoryCell
        ])
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if hiddenIndexPaths.contains(indexPath) {
            return 0.01
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == CellIndexPath.premiumSectionIndex && isPremiumSectionHidden {
            return 0.01
        }
        return super.tableView(tableView, heightForFooterInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == CellIndexPath.premiumSectionIndex && isPremiumSectionHidden {
            return 0.01
        }
        return super.tableView(tableView, heightForHeaderInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == CellIndexPath.premiumSectionIndex && isPremiumSectionHidden {
            return nil
        }
        return super.tableView(tableView, titleForHeaderInSection: section)
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case appSafetyCell:
            let appLockSettingsVC = SettingsAppLockVC.instantiateFromStoryboard()
            show(appLockSettingsVC, sender: self)
        case dataSafetyCell:
            let dataProtectionSettingsVC = SettingsDataProtectionVC.instantiateFromStoryboard()
            show(dataProtectionSettingsVC, sender: self)
        case searchCell:
            let searchSettingsVC = SettingsSearchVC.instantiateFromStoryboard()
            show(searchSettingsVC, sender: self)
        case appearanceCell:
            showAppearanceSettings()
        case dataBackupCell:
            let dataBackupSettingsVC = SettingsBackupVC.instantiateFromStoryboard()
            show(dataBackupSettingsVC, sender: self)
        case diagnosticLogCell:
            didPressShowDiagnostics()
        case contactSupportCell:
            let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
            SupportEmailComposer.show(subject: .supportRequest, parent: self, popoverAnchor: popoverAnchor)
        case rateTheAppCell:
            break
        case aboutAppCell:
            let aboutVC = AboutVC.make()
            show(aboutVC, sender: self)
        default:
            break
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath)
    {
    }
    

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == CellIndexPath.premiumSectionIndex else {
            return super.tableView(tableView, titleForFooterInSection: section)
        }
        
        return nil
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        dismissPopover(animated: true)
    }
    
    @IBAction func didToggleAutoUnlockStartupDatabase(_ sender: UISwitch) {
        Settings.current.isAutoUnlockStartupDatabase = sender.isOn
    }
    
    
    private func showAppearanceSettings() {
        let appearanceVC = SettingsAppearanceVC.instantiateFromStoryboard()
        appearanceVC.router = router
        router.push(appearanceVC, animated: true, onPop: nil)
    }
    
    var diagnosticsViewerCoordinator: DiagnosticsViewerCoordinator?
    func didPressShowDiagnostics() {
        assert(diagnosticsViewerCoordinator == nil)
        diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator!.dismissHandler = { [weak self] coordinator in
            self?.diagnosticsViewerCoordinator = nil
        }
        diagnosticsViewerCoordinator!.start()
    }
    
}

extension SettingsVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}

 
extension SettingsVC: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        dismissPopover(animated: false)
    }
}

extension DateComponentsFormatter {
    static func format(
        _ interval: TimeInterval,
        allowedUnits: NSCalendar.Unit,
        maxUnitCount: Int = 3,
        style: DateComponentsFormatter.UnitsStyle = .abbreviated,
        addRemainingPhrase: Bool = false
        ) -> String?
    {
        let timeFormatter = DateComponentsFormatter()
        timeFormatter.allowedUnits = allowedUnits
        timeFormatter.collapsesLargestUnit = true
        timeFormatter.includesTimeRemainingPhrase = addRemainingPhrase
        timeFormatter.maximumUnitCount = maxUnitCount
        timeFormatter.unitsStyle = style
        return timeFormatter.string(from: interval)
    }
}
