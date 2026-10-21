//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.
//
//  Created by Igor Kulman on 19.03.2021.

import Foundation
import KeePassiumLib

typealias PhotoPickerCompletion = (Result<UIImage?, Error>) ->Void

protocol PhotoPicker {
    func pickImage(from viewController: UIViewController, completion: @escaping PhotoPickerCompletion)
}

final class PhotoPickerFactory {

    static func makePhotoPicker() -> PhotoPicker {
        return UIImagePickerControllerPhotoPicker()
    }
}

private final class UIImagePickerControllerPhotoPicker:
    NSObject,
    PhotoPicker,
    UIImagePickerControllerDelegate & UINavigationControllerDelegate
{
    var viewController: UIViewController?
    var completion: PhotoPickerCompletion?
    let imagePicker = UIImagePickerController()

    override init() {
        imagePicker.sourceType = .savedPhotosAlbum
        imagePicker.allowsEditing = false
        imagePicker.modalPresentationStyle = .overCurrentContext

        super.init()
        imagePicker.delegate = self
    }

    func pickImage(
        from viewController: UIViewController,
        completion: @escaping PhotoPickerCompletion
    ) {
        self.viewController = viewController
        self.completion = completion

        viewController.present(imagePicker, animated: true, completion: nil)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [String : Any])
    {
        imagePicker.dismiss(animated: true) { [weak self] in
            self?.completion?(.success(info[UIImagePickerControllerOriginalImage] as? UIImage))
        }
    }
}
