//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppIconSwitcherCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    private let picker: AppIconPicker
    
    init(router: NavigationRouter) {
        picker = AppIconPicker.instantiateFromStoryboard()
        picker.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        dismissHandler?(self)
    }
}

extension AppIconSwitcherCoordinator: AppIconPickerDelegate {
    func didSelectIcon(_ appIcon: AppIcon, in appIconPicker: AppIconPicker) {
        guard #available(iOS 10.3, *), UIApplication.shared.supportsAlternateIcons else {
            return
        }
        setAppIcon(appIcon)
    }
    
    private func setAppIcon(_ appIcon: AppIcon) {
        guard #available(iOS 10.3, *) else { return }
        UIApplication.shared.setAlternateIconName(appIcon.key) { [weak self] error in
            if let error = error {
                Diag.error("Failed to switch app icon [message: \(error.localizedDescription)")
            } else {
                Diag.info("App icon switched to \(appIcon.key ?? "default")")
            }
            self?.picker.refresh()
        }
    }
}
