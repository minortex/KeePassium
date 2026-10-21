//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol DatabaseCreatorDelegate: class {
    func didPressCancel(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressContinue(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressErrorDetails(in databaseCreatorVC: DatabaseCreatorVC)
}

class DatabaseCreatorVC: UIViewController {

    public var databaseFileName: String { return fileNameField.text ?? "" }
    public var password: String { return passwordField.text ?? "" }

    @IBOutlet weak var fileNameField: ValidatingTextField!
    @IBOutlet weak var passwordField: ProtectedTextField!
    @IBOutlet weak var keyFileField: KeyFileTextField!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet var errorMessagePanel: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var keyboardLayoutConstraint: KeyboardLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    
    weak var delegate: DatabaseCreatorDelegate?

    private var containerView: UIView {
        return navigationController?.view ?? self.view
    }
    private var progressOverlay: ProgressOverlay?
    
    public static func create() -> DatabaseCreatorVC {
        return DatabaseCreatorVC.instantiateFromStoryboard()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = LString.titleCreateDatabase
        
        setError(message: nil, animated: false)
        
        view.backgroundColor = UIColor(patternImage: UIImage(asset: .backgroundPattern))
        view.layer.isOpaque = false

        disableForReadOnlyMode()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateKeyboardLayoutConstraints()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async {
            self.updateKeyboardLayoutConstraints()
        }
    }
    
    private func updateKeyboardLayoutConstraints() {
        let view = containerView
        if let window = view.window {
            let viewTop = view.convert(view.frame.origin, to: window).y
            let viewHeight = view.frame.height
            let windowHeight = window.frame.height
            let viewBottomOffset = windowHeight - (viewTop + viewHeight)
            keyboardLayoutConstraint.viewOffset = viewBottomOffset
        }
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        return passwordField.becomeFirstResponder()
    }
    
    func disableForReadOnlyMode() {
        fileNameField.isEnabled = false
        passwordField.isEnabled = false
        keyFileField.isEnabled = false
        continueButton.isHidden = true
    }

    func showReadOnlyMessage() {
        let alert = UIAlertController.make(
            title: LString.titleCreateDatabase,
            message: NSLocalizedString(
                "[Database/Create/ReadOnly] Creating databases is unavailable in this read-only version.",
                value: "Creating databases is unavailable in this read-only version.",
                comment: "Message shown when trying to create a database in the read-only iOS 9 backport"),
            dismissButtonTitle: LString.actionOK)
        present(alert, animated: true, completion: nil)
    }
    
    func setError(message: String?, animated: Bool) {
        errorLabel.text = message
        let isToShow = message?.isNotEmpty ?? false
        let isToHide = !isToShow
        
        if isToShow {
            self.scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: animated)
        }

        guard errorMessagePanel.isHidden != isToHide else {
            return
        }
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.errorMessagePanel.isHidden = isToHide
                self.errorMessagePanel.superview?.layoutIfNeeded()
            }
        } else {
            errorMessagePanel.isHidden = isToHide
            errorMessagePanel.superview?.layoutIfNeeded()
        }
    }
    
    
    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    @IBAction func didPressErrorDetails(_ sender: Any) {
        delegate?.didPressErrorDetails(in: self)
    }
    
    @IBAction func didPressContinue(_ sender: Any) {
        showReadOnlyMessage()
    }
}
