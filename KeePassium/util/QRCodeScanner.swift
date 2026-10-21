//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.
//
//  Created by Igor Kulman on 12.03.2021.

import Foundation
import KeePassiumLib

protocol QRCodeScanner: AnyObject {
    var deviceSupportsQRScanning: Bool { get }

    func scanQRCode(presenter: UIViewController, completion: @escaping (Result<String, Error>) -> Void)
}

final class YubiKitQRCodeScanner: QRCodeScanner {
    var deviceSupportsQRScanning: Bool {
        return false
    }

    func scanQRCode(presenter: UIViewController, completion: @escaping (Result<String, Error>) -> Void) {
        let error = NSError(
            domain: "KeePassium",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "QR code scanning is not supported on iOS 9."])
        completion(.failure(error))
    }
}
