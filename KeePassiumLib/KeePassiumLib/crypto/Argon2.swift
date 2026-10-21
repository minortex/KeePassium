//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class Argon2 {
    public static let version: UInt32 = 0x13
    
    public struct Params {
        let salt: ByteArray
        let parallelism: UInt32
        let memoryKiB: UInt32
        let iterations: UInt32
        let version: UInt32
    }
    
    public enum PrimitiveType {
        case argon2d
        case argon2id
        
        var rawValue: argon2_type {
            let result: argon2_type
            switch self {
            case .argon2d:
                result = Argon2_d
            case .argon2id:
                result = Argon2_id
            }
            return result
        }
    }
    
    private final class CancellationState {
        var isAbortProcessing: UInt8 = 0
    }

    private final class CancellationObserver: NSObject {
        private let progress: Progress
        private let state: CancellationState

        init(progress: Progress, state: CancellationState) {
            self.progress = progress
            self.state = state
            super.init()
            progress.addObserver(
                self,
                forKeyPath: "isCancelled",
                options: [.new],
                context: nil
            )
        }

        func stop() {
            progress.removeObserver(
                self,
                forKeyPath: "isCancelled"
            )
        }

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            state.isAbortProcessing = 1
        }
    }

    private init() {
    }
    
    public static func hash(
        data pwd: ByteArray,
        params: Params,
        type: PrimitiveType,
        progress: ProgressEx?
        ) throws -> ByteArray
    {

        let cancellationState = CancellationState()
        
        progress?.totalUnitCount = Int64(params.iterations)
        progress?.completedUnitCount = 0
        let cancellationObserver = progress.map {
            CancellationObserver(progress: $0, state: cancellationState)
        }
        
        let progressCallback: progress_fptr!   
        let progressObject: UnsafeRawPointer?  
        
        if let progress = progress {
            progressObject = UnsafeRawPointer(Unmanaged.passUnretained(progress).toOpaque())
            progressCallback = {
                (pass: UInt32, observer: Optional<UnsafeRawPointer>) -> Int32 in
                guard let observer = observer else { return 0 /* continue hashing */ }
                let progress = Unmanaged<Progress>.fromOpaque(observer).takeUnretainedValue()
                progress.completedUnitCount = Int64(pass)
                let isShouldStop: Int32 = progress.isCancelled ? 1 : 0
                return isShouldStop
            }
        } else {
            progressObject = nil
            progressCallback = nil
        }
        
        FLAG_clear_internal_memory = 1
        var outBytes = [UInt8](repeating: 0, count: 32)
        let statusCode = pwd.withBytes {
            (pwdBytes) in
            return params.salt.withBytes {
                (saltBytes) -> Int32 in
                return argon2_hash(
                    params.iterations,  
                    params.memoryKiB,   
                    params.parallelism, 
                    pwdBytes, pwdBytes.count,   
                    saltBytes, saltBytes.count, 
                    &outBytes, outBytes.count,  
                    nil, 0,             
                    type.rawValue,      
                    params.version,     
                    progressCallback,   
                    progressObject,     
                    &cancellationState.isAbortProcessing
                )
            }
        }
        cancellationObserver?.stop()
        if let progress = progress {
            progress.completedUnitCount = Int64(params.iterations) 
            if progress.isCancelled {
                throw ProgressInterruption.cancelled(reason: progress.cancellationReason)
            }
        }
        
        if statusCode != ARGON2_OK.rawValue {
            throw CryptoError.argon2Error(code: Int(statusCode))
        }
        return ByteArray(bytes: outBytes)
    }
}
