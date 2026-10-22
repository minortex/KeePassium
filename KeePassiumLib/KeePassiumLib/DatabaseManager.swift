//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

enum DatabaseLockReason {
    case userRequest
    case timeout
}

fileprivate enum ProgressSteps {
    static let start: Int64 = -1 
    static let all: Int64 = 100 

}


public class DatabaseManager {
    public static let shared = DatabaseManager()

    public var progress = ProgressEx()
    
    public private(set) var databaseRef: URLReference?
    public var database: Database? { return databaseDocument?.database }

    public var isDatabaseOpen: Bool { return database != nil }
    public var isDatabaseReadOnly: Bool { return true }
    
    private var databaseDocument: DatabaseDocument?
    private var databaseLoader: DatabaseLoader?
    
    private var serialDispatchQueue = DispatchQueue(
        label: "com.keepassium.DatabaseManager",
        qos: .userInitiated)
    
    public init() {
    }

    
    
    public func closeDatabase(
        clearStoredKey: Bool,
        ignoreErrors: Bool,
        completion callback: ((FileAccessError?) -> Void)?)
    {
        guard database != nil else {
            callback?(nil)
            return
        }
        Diag.verbose("Will queue close database")

        if clearStoredKey, let urlRef = databaseRef {
            DatabaseSettingsManager.shared.updateSettings(for: urlRef) { (dbSettings) in
                dbSettings.clearMasterKey()
                Diag.verbose("Master key cleared")
            }
        }

        serialDispatchQueue.async {
            DispatchQueue.main.async {
                guard let dbDoc = self.databaseDocument else {
                    callback?(nil)
                    return
                }
                Diag.debug("Will close database")
                dbDoc.close { [self] result in
                    switch result {
                    case .success:
                        self.handleDatabaseClosing()
                        callback?(nil)
                    case .failure(let fileAccessError):
                        Diag.error("Failed to close database document [message: \(fileAccessError.localizedDescription)]")
                        if ignoreErrors {
                            Diag.warning("Ignoring errors and closing anyway")
                            self.handleDatabaseClosing()
                            callback?(nil)
                        } else {
                            callback?(fileAccessError)
                        }
                    }
                }
            }
        }
    }
    
    private func handleDatabaseClosing() {
        guard let dbRef = self.databaseRef else { assertionFailure(); return }
        
        self.notifyDatabaseWillClose(database: dbRef)
        self.databaseDocument = nil
        self.databaseRef = nil
        self.notifyDatabaseDidClose(database: dbRef)
        Diag.info("Database closed")
    }

    public func startLoadingDatabase(
        database dbRef: URLReference,
        password: String,
        keyFile keyFileRef: URLReference?,
        challengeHandler: ChallengeHandler?)
    {
        Diag.verbose("Will queue load database")
        let compositeKey = CompositeKey(
            password: password,
            keyFileRef: keyFileRef,
            challengeHandler: challengeHandler
        )
        serialDispatchQueue.async {
            self._loadDatabase(dbRef: dbRef, compositeKey: compositeKey)
        }
    }
    
    public func startLoadingDatabase(
        database dbRef: URLReference,
        compositeKey: CompositeKey,
        canUseFinalKey: Bool)
    {
        Diag.verbose("Will queue load database")
        
        let compositeKeyClone = compositeKey.clone()
        if !canUseFinalKey {
            compositeKeyClone.eraseFinalKeys()
        }
        serialDispatchQueue.async {
            self._loadDatabase(dbRef: dbRef, compositeKey: compositeKeyClone)
        }
    }
    
    private func _loadDatabase(dbRef: URLReference, compositeKey: CompositeKey) {
        if database != nil {
            databaseDocument?.database = nil
            databaseDocument = nil
            databaseRef = nil
        }

        Diag.info("Will load database")
        progress = ProgressEx()
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = ProgressSteps.start
        
        databaseLoader = nil
        databaseLoader = DatabaseLoader(
            dbRef: dbRef,
            compositeKey: compositeKey,
            progress: progress,
            delegate: self)
        databaseLoader!.load()
    }

    public func rememberDatabaseKey(onlyIfExists: Bool = false) throws {
        guard let databaseRef = databaseRef, let database = database else { return }
        let dsm = DatabaseSettingsManager.shared
        let dbSettings = dsm.getOrMakeSettings(for: databaseRef)
        if onlyIfExists && !dbSettings.hasMasterKey {
            return
        }
        
        Diag.info("Saving database key in keychain.")
        dbSettings.setMasterKey(database.compositeKey)
        dsm.setSettings(dbSettings, for: databaseRef)
    }
    
    public func startSavingDatabase() {
        Diag.warning("Database saving is disabled in the read-only build")
    }
    
    public func changeCompositeKey(to _: CompositeKey) {
        Diag.warning("Changing the database master key is disabled in the read-only build")
    }
    
    public static func createCompositeKey(
        keyHelper: KeyHelper,
        password: String,
        keyFile keyFileRef: URLReference?,
        challengeHandler: ChallengeHandler?,
        success successHandler: @escaping((_ compositeKey: CompositeKey) -> Void),
        error errorHandler: @escaping((_ errorMessage: String) -> Void))
    {
        let mainQueueSuccessHandler: (_ compositeKey: CompositeKey)->Void = { (compositeKey) in
            DispatchQueue.main.async {
                successHandler(compositeKey)
            }
        }
        let mainQueueErrorHandler: (_ errorMessage: String)->Void = { (errorMessage) in
            DispatchQueue.main.async {
                errorHandler(errorMessage)
            }
        }
        
        let dataReadyHandler = { (keyFileData: ByteArray) -> Void in
            let passwordData = keyHelper.getPasswordData(password: password)
            if passwordData.isEmpty && keyFileData.isEmpty && challengeHandler == nil {
                Diag.error("Password and key file are both empty")
                mainQueueErrorHandler(LString.Error.passwordAndKeyFileAreBothEmpty)
                return
            }
            do {
                let staticComponents = try keyHelper.combineComponents(
                    passwordData: passwordData, 
                    keyFileData: keyFileData    
                ) 
                let compositeKey = CompositeKey(
                    staticComponents: staticComponents,
                    challengeHandler: challengeHandler)
                Diag.debug("New composite key created successfully")
                mainQueueSuccessHandler(compositeKey)
            } catch let error as KeyFileError {
                Diag.error("Key file error [reason: \(error.localizedDescription)]")
                mainQueueErrorHandler(error.localizedDescription)
            } catch {
                let message = "Caught unrecognized exception" 
                assertionFailure(message)
                Diag.error(message)
                mainQueueErrorHandler(message)
            }
        }
        
        guard let keyFileRef = keyFileRef else {
            dataReadyHandler(ByteArray())
            return
        }
        
        keyFileRef.resolveAsync { result in 
            switch result {
            case .success(let keyFileURL):
                let keyDoc = BaseDocument(fileURL: keyFileURL, fileProvider: keyFileRef.fileProvider)
                keyDoc.open { result in
                    switch result {
                    case .success(let keyFileData):
                        dataReadyHandler(keyFileData)
                    case .failure(let fileAccessError):
                        Diag.error("Failed to open key file [error: \(fileAccessError.localizedDescription)]")
                        mainQueueErrorHandler(LString.Error.failedToOpenKeyFile)
                    }
                }
            case .failure(let accessError):
                Diag.error("Failed to open key file [error: \(accessError.localizedDescription)]")
                mainQueueErrorHandler(LString.Error.failedToOpenKeyFile)
            }
        }
    }
    
    public func createDatabase(
        databaseURL: URL,
        password: String,
        keyFile: URLReference?,
        challengeHandler: ChallengeHandler?,
        template templateSetupHandler: @escaping (Group2) -> Void,
        success successHandler: @escaping () -> Void,
        error errorHandler: @escaping ((String?) -> Void))
    {
        Diag.warning("Database creation is disabled in the read-only build")
        errorHandler(
            NSLocalizedString(
                "[DatabaseManager] Database creation is disabled",
                bundle: Bundle.framework,
                value: "Database creation is not available.",
                comment: "Error message shown when database creation is attempted in the read-only build.")
        )
    }

    public func abortDatabaseCreation() {
        assert(self.databaseDocument != nil)
        self.databaseDocument?.database = nil
        self.databaseDocument = nil
        self.databaseRef = nil

    }
    
    internal static func shouldUpdateLatestBackup(for dbRef: URLReference) -> Bool {
        switch dbRef.location {
        case .external, .internalDocuments:
            return true
        case .internalBackup, .internalInbox, .remote:
            return false
        }
    }
    
    
    fileprivate struct WeakObserver {
        weak var observer: DatabaseManagerObserver?
    }
    private var observers = [ObjectIdentifier: WeakObserver]()
    private var notificationQueue = DispatchQueue(
        label: "com.keepassium.DatabaseManager.notifications",
        qos: .default
    )
    
    public func addObserver(_ observer: DatabaseManagerObserver) {
        let id = ObjectIdentifier(observer)
        notificationQueue.async(flags: .barrier) { 
            self.observers[id] = WeakObserver(observer: observer)
        }
    }
    
    public func removeObserver(_ observer: DatabaseManagerObserver) {
        let id = ObjectIdentifier(observer)
        notificationQueue.async(flags: .barrier) { 
            self.observers.removeValue(forKey: id)
        }
    }

    
    fileprivate func notifyDatabaseWillCreate(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willCreateDatabase: urlRef)
                }
            }
        }
    }

    fileprivate func notifyDatabaseWillClose(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willCloseDatabase: urlRef)
                }
            }
        }
    }
    
    fileprivate func notifyDatabaseDidClose(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(didCloseDatabase: urlRef)
                }
            }
        }
    }
}

fileprivate extension DatabaseManager {
    func databaseOperationProgressDidChange(
        database dbRef: URLReference,
        progress: ProgressEx)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(progressDidChange: progress)
                }
            }
        }
    }
    
    func databaseOperationCancelled(database dbRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(database: dbRef, isCancelled: true)
                }
            }
        }
    }
}

extension DatabaseManager: DatabaseLoaderDelegate {
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        willLoadDatabase dbRef: URLReference)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willLoadDatabase: dbRef)
                }
            }
        }
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didChangeProgress progress: ProgressEx,
        for dbRef: URLReference)
    {
        databaseOperationProgressDidChange(database: dbRef, progress: progress)
    }
    
    func databaseLoader(_ databaseLoader: DatabaseLoader, didCancelLoading dbRef: URLReference) {
        databaseOperationCancelled(database: dbRef)
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        withInvalidMasterKeyMessage message: String)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(database: dbRef, invalidMasterKey: message)
                }
            }
        }
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        message: String,
        reason: String?)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(
                        database: dbRef,
                        loadingError: message,
                        reason: reason)
                }
            }
        }
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didLoadDatabase dbRef: URLReference,
        withWarnings warnings: DatabaseLoadingWarnings)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(didLoadDatabase: dbRef, warnings: warnings)
                }
            }
        }
    }
    
    func databaseLoaderDidFinish(
        _ databaseLoader: DatabaseLoader,
        for dbRef: URLReference,
        withResult databaseDocument: DatabaseDocument?)
    {
        self.databaseRef = dbRef
        self.databaseDocument = databaseDocument
        self.databaseLoader = nil
    }
}
