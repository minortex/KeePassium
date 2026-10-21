//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class ChangeMasterKeyVC: UIViewController {
   
    @IBOutlet weak var keyboardAdjView: UIView!
    @IBOutlet weak var databaseNameLabel: UILabel!
    @IBOutlet weak var databaseIcon: UIImageView!
    @IBOutlet weak var passwordField: ValidatingTextField!
    @IBOutlet weak var repeatPasswordField: ValidatingTextField!
    @IBOutlet weak var keyFileField: KeyFileTextField!
    @IBOutlet weak var passwordMismatchImage: UIImageView!
    @IBOutlet weak var keyboardAdjConstraint: KeyboardLayoutConstraint!
    
    private var databaseRef: URLReference!
    static func make(dbRef: URLReference) -> UIViewController {
        let vc = ChangeMasterKeyVC.instantiateFromStoryboard()
        vc.databaseRef = dbRef
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .formSheet
        return navVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        databaseNameLabel.text = databaseRef.visibleFileName
        databaseIcon.image = databaseRef.getIcon(fileType: .database)
        
        passwordField.invalidBackgroundColor = nil
        repeatPasswordField.invalidBackgroundColor = nil
        keyFileField.invalidBackgroundColor = nil
        view.backgroundColor = UIColor(patternImage: UIImage(asset: .backgroundPattern))
        view.layer.isOpaque = false
        
        passwordField.isEnabled = false
        repeatPasswordField.isEnabled = false
        keyFileField.isEnabled = false
        navigationItem.rightBarButtonItem = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateKeyboardLayoutConstraints()
        let alert = UIAlertController.make(
            title: LString.titleError,
            message: NSLocalizedString(
                "[ChangeMasterKey/ReadOnly] Changing the master key is unavailable in this read-only version.",
                value: "Changing the master key is unavailable in this read-only version.",
                comment: "Message shown when trying to change the database master key in the read-only iOS 9 backport"),
            dismissButtonTitle: LString.actionOK)
        present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async { [weak self] in
            self?.updateKeyboardLayoutConstraints()
        }
    }
    
    private func updateKeyboardLayoutConstraints() {
        if let window = view.window {
            let viewTop = view.convert(view.frame.origin, to: window).y
            let viewHeight = view.frame.height
            let windowHeight = window.frame.height
            let viewBottomOffset = windowHeight - (viewTop + viewHeight)
            keyboardAdjConstraint.viewOffset = viewBottomOffset
        }
    }
    
    
    @IBAction func didPressCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didPressSaveChanges(_ sender: Any) {
        let alert = UIAlertController.make(
            title: LString.titleError,
            message: NSLocalizedString(
                "[ChangeMasterKey/ReadOnly] Changing the master key is unavailable in this read-only version.",
                value: "Changing the master key is unavailable in this read-only version.",
                comment: "Message shown when trying to change the database master key in the read-only iOS 9 backport"),
            dismissButtonTitle: LString.actionOK)
        present(alert, animated: true, completion: nil)
    }
}
