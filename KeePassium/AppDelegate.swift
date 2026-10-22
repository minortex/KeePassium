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

class AppDelegate: UIResponder, UIApplicationDelegate {

    let helpURL = URL(string: "https://keepassium.com/faq")!

    var window: UIWindow?
    fileprivate var watchdog: Watchdog
    fileprivate var appCoverWindow: UIWindow?
    fileprivate var appLockWindow: UIWindow?
    fileprivate var biometricsBackgroundWindow: UIWindow?
    fileprivate var isBiometricAuthShown = false
    
    fileprivate let biometricAuthReuseDuration = TimeInterval(1.5)
    fileprivate var lastSuccessfulBiometricAuthTime: Date = .distantPast
    
    
    override init() {
        watchdog = Watchdog.shared 
        super.init()
        watchdog.delegate = self
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool
    {
        AppGroup.applicationShared = application
        SettingsMigrator.processAppLaunch(with: Settings.current)
        SystemIssueDetector.scanForIssues()
        Diag.info(AppInfo.description)
        
        let rootVC = window?.rootViewController as? FileKeeperDelegate
        assert(rootVC != nil, "FileKeeper needs a delegate")
        FileKeeper.shared.delegate = rootVC

        showAppCoverScreen()
        
        watchdog.didBecomeActive()
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
    }
    
    func application(
        _ application: UIApplication,
        open inputURL: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
        ) -> Bool
    {
        AppGroup.applicationShared = application
        guard inputURL.scheme == AppGroup.appURLScheme else {
            Diag.info("Ignored external URL: \(inputURL.redacted)")
            return false
        }
        Diag.info("Received internal app URL: \(inputURL.redacted)")
        return true
    }
    
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(showHelp(_:)):
            return true
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    @objc
    func showHelp(_ sender: Any) {
        UIApplication.shared.kp_open(helpURL)
    }
}

extension AppDelegate: WatchdogDelegate {
    var isAppCoverVisible: Bool {
        return appCoverWindow != nil
    }
    var isAppLockVisible: Bool {
        return appLockWindow != nil || isBiometricAuthShown
    }
    func showAppCover(_ sender: Watchdog) {
        showAppCoverScreen()
    }
    func hideAppCover(_ sender: Watchdog) {
        hideAppCoverScreen()
    }
    func showAppLock(_ sender: Watchdog) {
        showAppLockScreen()
    }
    func hideAppLock(_ sender: Watchdog) {
        hideAppLockScreen()
    }
    
    private func showAppCoverScreen()  {
        guard appCoverWindow == nil else { return }
        
        let _appCoverWindow = UIWindow(frame: UIScreen.main.bounds)
        #if compiler(>=5.1)
        _appCoverWindow.setScreen(UIScreen.main)
        _appCoverWindow.windowLevel = UIWindow.Level.alert
        #else
        _appCoverWindow.windowLevel = UIWindow.Level.alert
        #endif
        self.appCoverWindow = _appCoverWindow

        let coverVC = AppCoverVC.make()
        DispatchQueue.main.async { [_appCoverWindow, coverVC] in
            UIView.performWithoutAnimation {
                _appCoverWindow.rootViewController = coverVC
                _appCoverWindow.makeKeyAndVisible()
            }
            print("App cover shown")
            coverVC.view.accessibilityViewIsModal = true
            coverVC.view.snapshotView(afterScreenUpdates: true)
        }
    }
    
    private func hideAppCoverScreen() {
        guard let appCoverWindow = appCoverWindow else { return }
        appCoverWindow.isHidden = true
        self.appCoverWindow = nil
        print("App cover hidden")
    }
    
    private var canUseBiometrics: Bool {
        return isBiometricsAvailable() && Settings.current.isBiometricAppLockEnabled
    }
    
    private func showAppLockScreen() {
        guard !isAppLockVisible else { return }
        if canUseBiometrics {
            performBiometricUnlock()
        } else {
            showPasscodeRequest()
        }
    }
    
    private func hideAppLockScreen() {
        guard isAppLockVisible else { return }
        self.window?.makeKeyAndVisible()
        appLockWindow?.resignKey()
        appLockWindow?.isHidden = true
        appLockWindow = nil
        print("appLockWindow hidden")
    }
    
    private func showPasscodeRequest() {
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .verification
        passcodeInputVC.isCancelAllowed = false 
        passcodeInputVC.isBiometricsAllowed = canUseBiometrics
        
        let _appLockWindow = UIWindow(frame: UIScreen.main.bounds)
        #if compiler(>=5.1)
        _appLockWindow.setScreen(UIScreen.main)
        _appLockWindow.windowLevel = UIWindow.Level.alert
        #else
        _appLockWindow.windowLevel = UIWindow.Level.alert
        #endif
        UIView.performWithoutAnimation { [weak self] in
            _appLockWindow.rootViewController = passcodeInputVC
            _appLockWindow.makeKeyAndVisible()
            self?.window?.isHidden = true
        }
        passcodeInputVC.view.accessibilityViewIsModal = true
        passcodeInputVC.view.snapshotView(afterScreenUpdates: true)
        
        self.appLockWindow = _appLockWindow
        print("passcode request shown")
    }
    
    private func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        return context.canEvaluatePolicy(policy, error: nil)
    }
    
    private func performBiometricUnlock() {
        assert(isBiometricsAvailable())
        guard Settings.current.isBiometricAppLockEnabled else { return }
        guard !isBiometricAuthShown else { return }
        
        let timeSinceLastSuccess = abs(Date().timeIntervalSince(lastSuccessfulBiometricAuthTime))
        if timeSinceLastSuccess < biometricAuthReuseDuration {
            print("Skipping repeated biometric prompt")
            watchdog.unlockApp()
            return
        }
        
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        context.localizedFallbackTitle = "" // hide "Enter (System) Password" fallback; nil won't work
        if #available(iOS 10, *) {
            context.localizedCancelTitle = LString.actionUsePasscode
        }
        print("Showing biometrics request")
        
        showBiometricsBackground()
        lastSuccessfulBiometricAuthTime = .distantPast
        context.evaluatePolicy(policy, localizedReason: LString.titleTouchID) {
            [weak self] (authSuccessful, authError) in
            DispatchQueue.main.async { [weak self] in
                if authSuccessful {
                    self?.lastSuccessfulBiometricAuthTime = Date()
                    self?.watchdog.unlockApp()
                } else {
                    Diag.warning("TouchID failed [message: \(authError?.localizedDescription ?? "nil")]")
                    self?.lastSuccessfulBiometricAuthTime = .distantPast
                    self?.showPasscodeRequest()
                }
                self?.hideBiometricsBackground()
                self?.isBiometricAuthShown = false
            }
        }
        isBiometricAuthShown = true
    }
    
    private func showBiometricsBackground()  {
        guard biometricsBackgroundWindow == nil else { return }
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        #if compiler(>=5.1)
        window.setScreen(UIScreen.main)
        window.windowLevel = UIWindow.Level.alert + 1
        #else
        window.windowLevel = UIWindow.Level.alert + 1
        #endif
        let coverVC = AppCoverVC.make()
        
        UIView.performWithoutAnimation {
            window.rootViewController = coverVC
            window.makeKeyAndVisible()
        }
        print("Biometrics background shown")
        self.biometricsBackgroundWindow = window
        
        coverVC.view.snapshotView(afterScreenUpdates: true)
    }
    
    private func hideBiometricsBackground() {
        guard let window = biometricsBackgroundWindow else { return }
        window.isHidden = true
        self.biometricsBackgroundWindow = nil
        print("Biometrics background hidden")
    }
    
}

extension AppDelegate: PasscodeInputDelegate {
    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        do {
            if try Keychain.shared.isAppPasscodeMatch(passcode) { 
                HapticFeedback.play(.appUnlocked)
                watchdog.unlockApp()
            } else {
                HapticFeedback.play(.wrongPassword)
                sender.animateWrongPassccode()
                if Settings.current.isLockAllDatabasesOnFailedPasscode {
                    DatabaseSettingsManager.shared.eraseAllMasterKeys()
                    DatabaseManager.shared.closeDatabase(
                        clearStoredKey: true,
                        ignoreErrors: true,
                        completion: nil)
                }
            }
        } catch {
            let alert = UIAlertController.make(
                title: LString.titleKeychainError,
                message: error.localizedDescription)
            sender.present(alert, animated: true, completion: nil)
        }
    }
    
    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC) {
        assert(canUseBiometrics)
        performBiometricUnlock()
    }
}
