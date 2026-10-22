//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class UnlockDatabaseVC: UIViewController, Refreshable {
    @IBOutlet private weak var databaseNameLabel: UILabel!
    @IBOutlet private weak var inputPanel: UIView!
    @IBOutlet private weak var passwordField: UITextField!
    @IBOutlet private weak var keyFileField: KeyFileTextField!
    @IBOutlet private weak var keyboardAdjView: UIView!
    @IBOutlet private weak var errorMessagePanel: UIView!
    @IBOutlet private weak var errorLabel: UILabel!
    @IBOutlet private weak var errorDetailButton: UIButton!
    @IBOutlet private weak var watchdogTimeoutLabel: UILabel!
    @IBOutlet private weak var databaseIconImage: UIImageView!
    @IBOutlet weak var masterKeyKnownLabel: UILabel!
    @IBOutlet weak var lockDatabaseButton: UIButton!
    @IBOutlet weak var announcementButton: UIButton!
    
    public var databaseRef: URLReference! {
        didSet {
            guard isViewLoaded else { return }
            hideErrorMessage(animated: false)
            refresh()
        }
    }
    
    private var keyFileRef: URLReference?
    private var fileKeeperNotifications: FileKeeperNotifications!
    
    private var canUseFinalKey = true
    
    var isJustLaunched = false 
    var isAutoUnlockEnabled = true
    fileprivate var isAutomaticUnlock = false

    private var diagnosticsViewerCoordinator: DiagnosticsViewerCoordinator?
    
    private var isViewAppeared = false
    
    static func make(databaseRef: URLReference) -> UnlockDatabaseVC {
        let vc = UnlockDatabaseVC.instantiateFromStoryboard()
        vc.databaseRef = databaseRef
        return vc
    }
    
    deinit {
        diagnosticsViewerCoordinator = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        passwordField.delegate = self
        keyFileField.delegate = self
        
        fileKeeperNotifications = FileKeeperNotifications(observer: self)

        view.backgroundColor = UIColor(patternImage: UIImage(asset: .backgroundPattern))
        view.layer.isOpaque = false

        watchdogTimeoutLabel.alpha = 0.0
        errorMessagePanel.alpha = 0.0
        errorMessagePanel.isHidden = true
        
        let lockDatabaseButton = UIBarButtonItem(
            title: LString.actionCloseDatabase,
            style: .plain,
            target: nil,
            action: nil)
        navigationItem.backBarButtonItem = lockDatabaseButton
        
        refreshNews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        if isMovingToParent && canAutoUnlock() {
            showProgressOverlay(animated: false)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !isViewAppeared else {
            Diag.warning("Unbalanced call to viewDidAppear, ignoring")
            assertionFailure("Unbalanced call to viewDidAppear")
            return
        }
        isViewAppeared = true

        canUseFinalKey = true

        fileKeeperNotifications.startObserving()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        onAppDidBecomeActive()
        
        if isMovingToParent && canAutoUnlock() {
            DispatchQueue.main.async { [weak self] in
                self?.tryToUnlockDatabase(isAutomaticUnlock: true)
            }
        } else {
            hideProgressOverlay(quickly: true)
            refreshInputMode()
        }

        if FileKeeper.shared.hasPendingFileOperations {
            processPendingFileOperations()
        }
        
        maybeFocusOnPassword()
    }
    
    @objc func onAppDidBecomeActive() {
        if Watchdog.shared.isDatabaseTimeoutExpired {
            showWatchdogTimeoutMessage()
        } else {
            hideWatchdogTimeoutMessage(animated: false)
        }
        refreshInputMode()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        fileKeeperNotifications.stopObserving()
        super.viewWillDisappear(animated)
        isViewAppeared = false
    }
    
    override func didReceiveMemoryWarning() {
        Diag.error("Received a memory warning")
        DatabaseManager.shared.progress.cancel(reason: .lowMemoryWarning)
    }
    
    func refresh() {
        guard isViewLoaded else { return }
        
        databaseIconImage.image = databaseRef.getIcon(fileType: .database)
        databaseNameLabel.text = databaseRef.visibleFileName
        if databaseRef.hasError {
            let text = databaseRef.error?.localizedDescription
            if databaseRef.hasPermissionError257 || databaseRef.hasFileMissingError {
                showErrorMessage(text, suggestion: LString.tryToReAddFile)
            } else {
                showErrorMessage(text)
            }
        }
        
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: databaseRef)
        if let associatedKeyFileRef = dbSettings?.associatedKeyFile {
            let allAvailableKeyFiles = FileKeeper.shared
                .getAllReferences(fileType: .keyFile, includeBackup: false)
            if let availableKeyFileRef = associatedKeyFileRef
                .find(in: allAvailableKeyFiles, fallbackToNamesake: true)
            {
                setKeyFile(availableKeyFileRef)
            }
        }
        refreshNews()
        refreshInputMode()
    }
    
    private func refreshInputMode() {
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: databaseRef)
        let isDatabaseKeyStored = dbSettings?.hasMasterKey ?? false
        Diag.verbose("isDatabaseKeyStored: \(isDatabaseKeyStored)")
        
        let shouldInputMasterKey = !isDatabaseKeyStored
        masterKeyKnownLabel.isHidden = shouldInputMasterKey
        lockDatabaseButton.isHidden = masterKeyKnownLabel.isHidden
        inputPanel.isHidden = !shouldInputMasterKey
    }

    private func maybeFocusOnPassword() {
        if !inputPanel.isHidden {
            passwordField.becomeFirstResponder()
        }
    }
    
    private func clearPasswordField() {
        passwordField.text = ""
    }
    
    
    private var newsItem: NewsItem?
    
    private func refreshNews() {
        let nc = NewsCenter.shared
        if let newsItem = nc.getTopItem() {
            announcementButton.titleLabel?.numberOfLines = 0
            announcementButton.setTitle(newsItem.title, for: .normal)
            announcementButton.isHidden = false
            self.newsItem = newsItem
        } else {
            announcementButton.isHidden = true
            self.newsItem = nil
        }
    }

    @IBAction func didPressAnouncementButton(_ sender: Any) {
        newsItem?.show(in: self)
    }
    

    func showErrorMessage(
        _ text: String?,
        details: String?=nil,
        suggestion: String?=nil,
        haptics: HapticFeedback.Kind?=nil
    ) {
        guard let text = text else { return }
        let message = [text, details, suggestion]
            .compactMap{ return $0 }
            .joined(separator: "\n")
        errorLabel.text = message
        Diag.error(message)
        if #available(iOS 11.0, *) {
            UIAccessibility.post(notification: .layoutChanged, argument: errorLabel)
        } else {
            UIAccessibility.post(
                notification: UIAccessibility.Notification(rawValue: 1000),
                argument: errorLabel)
        }
        
        guard errorMessagePanel.isHidden else { return }
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: .curveEaseIn,
            animations: {
                [weak self] in
                self?.errorMessagePanel.isHidden = false
                self?.errorMessagePanel.alpha = 1.0
            },
            completion: {
                [weak self] (finished) in
                self?.errorMessagePanel.shake()
                if let hapticsKind = haptics {
                    HapticFeedback.play(hapticsKind)
                }
            }
        )
    }
    
    func hideErrorMessage(animated: Bool) {
        guard !errorMessagePanel.isHidden else { return }

        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0.0,
                options: .curveEaseOut,
                animations: {
                    [weak self] in
                    self?.errorMessagePanel.alpha = 0.0
                    self?.errorMessagePanel.isHidden = true
                },
                completion: {
                    [weak self] (finished) in
                    self?.errorLabel.text = nil
                }
            )
        } else {
            errorMessagePanel.isHidden = true
            errorLabel.text = nil
        }
    }
    
    func showWatchdogTimeoutMessage() {
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            options: .curveEaseOut,
            animations: {
                [weak self] in
                self?.watchdogTimeoutLabel.alpha = 1.0
            },
            completion: nil)
    }
    
    func hideWatchdogTimeoutMessage(animated: Bool) {
        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.0,
                options: .curveEaseOut,
                animations: {
                    [weak self] in
                    self?.watchdogTimeoutLabel.alpha = 0.0
                },
                completion: nil)
        } else {
            watchdogTimeoutLabel.alpha = 0.0
        }
    }
    
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

    private var progressOverlay: ProgressOverlay?
    fileprivate func showProgressOverlay(animated: Bool) {
        guard progressOverlay == nil else { return }
        progressOverlay = ProgressOverlay.addTo(
            keyboardAdjView,
            title: LString.databaseStatusLoading,
            animated: animated)
        progressOverlay?.isCancellable = true
        progressOverlay?.unresponsiveCancelHandler = { [weak self] in
            self?.showDiagnostics()
        }
        
        if let leftNavController = splitViewController?.viewControllers.first as? UINavigationController,
            let chooseDatabaseVC = leftNavController.topViewController as? ChooseDatabaseVC {
                chooseDatabaseVC.isEnabled = false
        }
        navigationItem.hidesBackButton = true
    }
    
    fileprivate func hideProgressOverlay(quickly: Bool) {
        UIView.animateKeyframes(
            withDuration: quickly ? 0.2 : 0.6,
            delay: quickly ? 0.0 : 0.6,
            options: [.beginFromCurrentState],
            animations: {
                [weak self] in
                self?.progressOverlay?.alpha = 0.0
            },
            completion: {
                [weak self] finished in
                guard let _self = self else { return }
                _self.progressOverlay?.removeFromSuperview()
                _self.progressOverlay = nil
            }
        )
        navigationItem.hidesBackButton = false
        if let leftNavController = splitViewController?.viewControllers.first as? UINavigationController,
            let chooseDatabaseVC = leftNavController.topViewController as? ChooseDatabaseVC {
            chooseDatabaseVC.isEnabled = true
        }

        let p = DatabaseManager.shared.progress
        Diag.verbose("Final progress: \(p.completedUnitCount) of \(p.totalUnitCount)")
    }

    
    func selectKeyFileAction(_ sender: Any) {
        hideErrorMessage(animated: true)
        showErrorAlert(
            NSLocalizedString(
                "[Unlock/KeyFile/ReadOnly] Key-file selection is unavailable. Put the key file in KeePassium Documents with iTunes File Sharing.",
                value: "Key-file selection is unavailable. Put the key file in KeePassium Documents with iTunes File Sharing.",
                comment: "Message shown when selecting a key file in the iOS 9 read-only build")
        )
    }
    
    
    @IBAction func didPressErrorDetails(_ sender: Any) {
        showDiagnostics()
    }
    
    @IBAction func didPressUnlock(_ sender: Any) {
        tryToUnlockDatabase(isAutomaticUnlock: false)
    }
    
    @IBAction func didPressLockDatabase(_ sender: Any) {
        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) {
            $0.clearMasterKey()
        }
        refreshInputMode()
    }
    
    
    func canAutoUnlock() -> Bool {
        guard isAutoUnlockEnabled &&
            Settings.current.isAutoUnlockStartupDatabase &&
            !FileKeeper.shared.hasPendingFileOperations else
        {
            return false
        }
        guard let splitVC = splitViewController, splitVC.isCollapsed else { return isJustLaunched }
        
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: databaseRef)
        let hasKey = dbSettings?.hasMasterKey ?? false
        Diag.verbose("canAutoUnlock: \(hasKey)")
        return hasKey
    }
    
    func tryToUnlockDatabase(isAutomaticUnlock: Bool) {
        Diag.clear()
        Diag.verbose("Will try to unlock database [automatically: \(isAutomaticUnlock)]")
        self.isAutomaticUnlock = isAutomaticUnlock
        let password = passwordField.text ?? ""
        passwordField.resignFirstResponder()
        hideWatchdogTimeoutMessage(animated: true)
        DatabaseManager.shared.addObserver(self)
        
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: databaseRef)
        if let databaseKey = dbSettings?.masterKey {
            DatabaseManager.shared.startLoadingDatabase(
                database: databaseRef,
                compositeKey: databaseKey,
                canUseFinalKey: canUseFinalKey)
        } else {
            canUseFinalKey = false 
            guard !isAutomaticUnlock else {
                Diag.debug("Aborting auto-unlock, there is no stored key")
                refreshInputMode()
                hideProgressOverlay(quickly: true)
                return
            }
            DatabaseManager.shared.startLoadingDatabase(
                database: databaseRef,
                password: password,
                keyFile: keyFileRef,
                challengeHandler: nil)
        }
    }
    
    func showDatabaseRoot(loadingWarnings: DatabaseLoadingWarnings) {
        guard let database = DatabaseManager.shared.database else {
            assertionFailure()
            return
        }
        let viewGroupVC = ViewGroupVC.make(group: database.root, loadingWarnings: loadingWarnings)
        guard let splitVC = splitViewController,
            let firstVC = splitVC.viewControllers.first,
            let leftNavController = firstVC as? UINavigationController else
        {
            let splitVC = splitViewController
            let firstVC = splitViewController?.viewControllers.first
            Diag.writeToPersistentLog("splitVC: \(splitVC.debugDescription)\nfirstVC: \(firstVC.debugDescription)")
            
            fatalError("No leftNavController?!")
        }
        if leftNavController.topViewController is UnlockDatabaseVC {
            var viewControllers = leftNavController.viewControllers
            viewControllers[viewControllers.count - 1] = viewGroupVC
            leftNavController.setViewControllers(viewControllers, animated: true)
        } else {
            leftNavController.show(viewGroupVC, sender: self)
        }
    }
}

extension UnlockDatabaseVC {
    func setKeyFile(_ fileRef: URLReference?) {
        self.keyFileRef = fileRef
        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) { (dbSettings) in
            dbSettings.maybeSetAssociatedKeyFile(keyFileRef)
        }

        guard let keyFileRef = keyFileRef else {
            Diag.debug("No key file selected")
            keyFileField.text = ""
            return
        }
        if let errorDetails = keyFileRef.error?.localizedDescription {
            let errorMessage = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database/Unlock] Key file error: %@",
                    value: "Key file error: %@",
                    comment: "Error message related to key file. [errorDetails: String]"),
                errorDetails)
            Diag.warning(errorMessage)
            showErrorMessage(errorMessage)
            keyFileField.text = ""
        } else {
            Diag.info("Key file set successfully")
            keyFileField.text = keyFileRef.visibleFileName
        }
    }
}

extension UnlockDatabaseVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.passwordField {
            tryToUnlockDatabase(isAutomaticUnlock: false)
        }
        return true
    }
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String) -> Bool
    {
        hideErrorMessage(animated: true)
        hideWatchdogTimeoutMessage(animated: true)
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField === keyFileField {
            passwordField.becomeFirstResponder()
            selectKeyFileAction(textField)
            return false
        }
        return true
    }
}


extension UnlockDatabaseVC: DatabaseManagerObserver {
    func databaseManager(willLoadDatabase urlRef: URLReference) {
        showProgressOverlay(animated: true)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        DatabaseSettingsManager.shared.updateSettings(for: urlRef) { (dbSettings) in
            dbSettings.clearMasterKey()
        }
        
        refresh()
        clearPasswordField()
        hideProgressOverlay(quickly: true)
        maybeFocusOnPassword()
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        progressOverlay?.update(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, invalidMasterKey message: String) {
        DatabaseManager.shared.removeObserver(self)
        if canUseFinalKey {
            Diag.info("Express unlock failed, retrying slow")
            canUseFinalKey = false
            tryToUnlockDatabase(isAutomaticUnlock: isAutomaticUnlock)
        } else {
            DatabaseSettingsManager.shared.updateSettings(for: urlRef) { (dbSettings) in
                dbSettings.clearMasterKey()
            }
            refresh()
            hideProgressOverlay(quickly: true)
            
            showErrorMessage(message, haptics: .wrongPassword)
            maybeFocusOnPassword()
        }
    }
    
    func databaseManager(didLoadDatabase urlRef: URLReference, warnings: DatabaseLoadingWarnings) {
        DatabaseManager.shared.removeObserver(self)
        
        HapticFeedback.play(.databaseUnlocked)
        
        if Settings.current.isRememberDatabaseKey {
            do {
                try DatabaseManager.shared.rememberDatabaseKey() 
            } catch {
                Diag.error("Failed to remember database key [message: \(error.localizedDescription)]")
            }
        }
        clearPasswordField()
        hideProgressOverlay(quickly: false)
        showDatabaseRoot(loadingWarnings: warnings)
    }

    func databaseManager(database urlRef: URLReference, loadingError message: String, reason: String?) {
        DatabaseManager.shared.removeObserver(self)
        refresh()
        hideProgressOverlay(quickly: true)
        
        isAutoUnlockEnabled = false
        if databaseRef.hasPermissionError257 || databaseRef.hasFileMissingError {
            showErrorMessage(
                message,
                details: reason,
                suggestion: LString.tryToReAddFile,
                haptics: .error
            )
        } else {
            showErrorMessage(message, details: reason, haptics: .error)
        }
        maybeFocusOnPassword()
    }
}

extension UnlockDatabaseVC: FileKeeperObserver {
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {
        if fileType == .database {
            navigationController?.popViewController(animated: true)
        }
    }

    func fileKeeperHasPendingOperation() {
        if isViewLoaded {
            processPendingFileOperations()
        }
    }

    private func processPendingFileOperations() {
        FileKeeper.shared.processPendingOperations(
            success: nil,
            error: { [weak self] (error) in
                self?.showErrorAlert(error)
            }
        )
    }
}
