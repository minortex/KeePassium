//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

private final class WebDAVTextFieldCell: UITableViewCell {
    let textField = UITextField()
    var textDidChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(onEditingChanged), for: .editingChanged)
        contentView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc private func onEditingChanged() {
        textDidChange?(textField.text ?? "")
    }

    func configure(
        text: String,
        placeholder: String,
        isSecure: Bool,
        keyboardType: UIKeyboardType,
        returnKeyType: UIReturnKeyType,
        accessibilityLabel: String,
        textDidChange: @escaping (String) -> Void
    ) {
        self.textDidChange = textDidChange
        textField.text = text
        textField.placeholder = placeholder
        textField.isSecureTextEntry = isSecure
        textField.keyboardType = keyboardType
        textField.returnKeyType = returnKeyType
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.accessibilityLabel = accessibilityLabel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WebDAVSetupVC: UITableViewController {
    private enum Section: Int, CaseIterable {
        case server
        case credentials
        case certificate
        case instructions
    }

    private var serverURLText = ""
    private var userNameText = ""
    private var passwordText = ""
    private let allowUntrustedCertificateSwitch = UISwitch()
    private var saveButton: UIBarButtonItem!
    private var isSaving = false
    private var completion: () -> Void

    static func make(completion: @escaping () -> Void) -> UIViewController {
        let setupVC = WebDAVSetupVC(style: .grouped)
        setupVC.completion = completion
        let navigationVC = UINavigationController(rootViewController: setupVC)
        navigationVC.modalPresentationStyle = .formSheet
        return navigationVC
    }

    private init(style: UITableView.Style) {
        self.completion = {}
        super.init(style: style)
        tableView.register(
            WebDAVTextFieldCell.self,
            forCellReuseIdentifier: "WebDAVTextFieldCell")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "WebDAV"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: LString.actionCancel,
            style: .plain,
            target: self,
            action: #selector(didPressCancel))
        saveButton = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(didPressSave))
        navigationItem.rightBarButtonItem = saveButton

        allowUntrustedCertificateSwitch.accessibilityLabel = "Allow self-signed certificate"
    }

    @objc private func didPressCancel() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func didPressSave() {
        guard !isSaving else { return }
        view.endEditing(true)

        guard let serverURL = validatedServerURL() else {
            showErrorAlert(
                NSLocalizedString(
                    "[WebDAV/InvalidURL] Enter a valid http or https server URL.",
                    value: "Enter a valid http or https server URL.",
                    comment: "Validation error for a WebDAV server URL"))
            return
        }

        isSaving = true
        saveButton.isEnabled = false
        let credential = NetworkCredential(
            username: userNameText,
            password: passwordText,
            allowUntrustedCertificate: allowUntrustedCertificateSwitch.isOn)
        CredentialManager.shared.store(credential: credential, for: serverURL)

        FileKeeper.shared.addFile(
            url: WebDAVFileURL.build(nakedURL: serverURL),
            fileType: .database,
            mode: .openInPlace,
            success: { [weak self] _ in
                guard let self = self else { return }
                let completion = self.completion
                self.dismiss(animated: true) {
                    completion()
                }
            },
            error: { [weak self] error in
                guard let self = self else { return }
                self.isSaving = false
                self.saveButton.isEnabled = true
                self.showErrorAlert(error)
            })
    }

    private func validatedServerURL() -> URL? {
        let text = serverURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              WebDAVFileURL.schemes.contains(scheme),
              let host = components.host,
              !host.isEmpty
        else {
            return nil
        }
        return components.url
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .server:
            return 1
        case .credentials:
            return 2
        case .certificate, .instructions:
            return 1
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .server:
            return "Server"
        case .credentials:
            return "Credentials"
        case .certificate:
            return "Certificate"
        case .instructions:
            return "Local databases"
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Unexpected WebDAV setup section")
        }
        switch section {
        case .server:
            return textFieldCell(
                at: indexPath,
                text: serverURLText,
                placeholder: "https://server.example.com/path/database.kdbx",
                isSecure: false,
                keyboardType: .URL,
                returnKeyType: .next,
                accessibilityLabel: "Server URL"
            ) { [weak self] text in
                self?.serverURLText = text
            }
        case .credentials:
            if indexPath.row == 0 {
                return textFieldCell(
                    at: indexPath,
                    text: userNameText,
                    placeholder: "Username",
                    isSecure: false,
                    keyboardType: .default,
                    returnKeyType: .next,
                    accessibilityLabel: "Username"
                ) { [weak self] text in
                    self?.userNameText = text
                }
            } else {
                return textFieldCell(
                    at: indexPath,
                    text: passwordText,
                    placeholder: "Password",
                    isSecure: true,
                    keyboardType: .default,
                    returnKeyType: .done,
                    accessibilityLabel: "Password"
                ) { [weak self] text in
                    self?.passwordText = text
                }
            }
        case .certificate:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Allow self-signed certificate"
            cell.selectionStyle = .none
            cell.accessoryView = allowUntrustedCertificateSwitch
            return cell
        case .instructions:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "To use a local database, copy it into KeePassium Documents with iTunes File Sharing or Finder, then reopen the app."
            cell.textLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            return cell
        }
    }

    private func textFieldCell(
        at indexPath: IndexPath,
        text: String,
        placeholder: String,
        isSecure: Bool,
        keyboardType: UIKeyboardType,
        returnKeyType: UIReturnKeyType,
        accessibilityLabel: String,
        textDidChange: @escaping (String) -> Void
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "WebDAVTextFieldCell",
            for: indexPath) as! WebDAVTextFieldCell
        cell.configure(
            text: text,
            placeholder: placeholder,
            isSecure: isSecure,
            keyboardType: keyboardType,
            returnKeyType: returnKeyType,
            accessibilityLabel: accessibilityLabel,
            textDidChange: textDidChange)
        return cell
    }
}
