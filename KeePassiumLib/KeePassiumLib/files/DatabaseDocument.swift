//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public class DatabaseDocument: BaseDocument {
    var database: Database?

    public override func save(
        _ completion: @escaping ((Result<Void, FileAccessError>) -> Void)
    ) {
        completion(.failure(.targetFileIsReadOnly(fileProvider: fileProvider ?? .localStorage)))
    }

    public override func close(
        _ completion: @escaping ((Result<Void, FileAccessError>) -> Void)
    ) {
        if fileProvider == .keepassiumWebDAV {
            completion(.success)
        } else {
            super.close(completion)
        }
    }
}
