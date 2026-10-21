//  KeePassium Password Manager
//  Copyright © 2018-2026 KeePassium Labs
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation
import Security

public final class WebDAVClient: NSObject {
    public static let shared = WebDAVClient()

    private enum CancelReason {
        case authenticationFailed(String)
        case untrustedCertificate(String)
    }

    private final class RequestContext {
        let credential: URLCredential
        let allowUntrustedCertificate: Bool
        let completion: (Result<WebDAVResponse, FileAccessError>) -> Void
        var cancelReason: CancelReason?
        var receivedData = Data()

        init(
            credential: URLCredential,
            allowUntrustedCertificate: Bool,
            completion: @escaping (Result<WebDAVResponse, FileAccessError>) -> Void
        ) {
            self.credential = credential
            self.allowUntrustedCertificate = allowUntrustedCertificate
            self.completion = completion
        }
    }

    private let delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.keepassium.WebDAVClient"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = URLReference.defaultTimeout
        configuration.timeoutIntervalForResource = URLReference.defaultTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCredentialStorage = nil
        return URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: delegateQueue
        )
    }()

    private let lock = NSLock()
    private var contexts = [Int: RequestContext]()

    private override init() {
        super.init()
    }

    public func getFileInfo(
        url: URL,
        credential: NetworkCredential,
        timeout: TimeInterval = URLReference.defaultTimeout,
        completion: @escaping (Result<FileInfo, FileAccessError>) -> Void
    ) {
        run(
            method: "HEAD",
            url: url,
            credential: credential,
            timeout: timeout
        ) { result in
            switch result {
            case .success(let response):
                let fileInfo = FileInfo(
                    fileName: url.lastPathComponent,
                    fileSize: response.contentLength,
                    creationDate: nil,
                    modificationDate: response.lastModified,
                    isExcludedFromBackup: nil,
                    isInTrash: false
                )
                completion(.success(fileInfo))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func downloadFile(
        url: URL,
        credential: NetworkCredential,
        timeout: TimeInterval = URLReference.defaultTimeout,
        completion: @escaping (Result<ByteArray, FileAccessError>) -> Void
    ) {
        run(
            method: "GET",
            url: url,
            credential: credential,
            timeout: timeout
        ) { result in
            switch result {
            case .success(let response):
                completion(.success(response.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func run(
        method: String,
        url: URL,
        credential: NetworkCredential,
        timeout: TimeInterval,
        completion: @escaping (Result<WebDAVResponse, FileAccessError>) -> Void
    ) {
        let requestURL = WebDAVFileURL.getNakedURL(from: url)
        var request = URLRequest(
            url: requestURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = method
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue(
            "Basic \(basicAuthToken(for: credential))",
            forHTTPHeaderField: "Authorization")

        let task = session.dataTask(with: request)
        let context = RequestContext(
            credential: credential.toURLCredential(),
            allowUntrustedCertificate: credential.allowUntrustedCertificate,
            completion: completion
        )
        lock.lock()
        contexts[task.taskIdentifier] = context
        lock.unlock()
        task.resume()
    }

    private func basicAuthToken(for credential: NetworkCredential) -> String {
        let login = "\(credential.username):\(credential.password)"
        return Data(login.utf8).base64EncodedString()
    }

    private func takeContext(for task: URLSessionTask) -> RequestContext? {
        lock.lock()
        defer { lock.unlock() }
        return contexts.removeValue(forKey: task.taskIdentifier)
    }

    private func context(for task: URLSessionTask) -> RequestContext? {
        lock.lock()
        defer { lock.unlock() }
        return contexts[task.taskIdentifier]
    }

    private func finish(task: URLSessionTask, error: Error?) {
        guard let context = takeContext(for: task) else { return }

        if let error = error {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                switch context.cancelReason {
                case .authenticationFailed(let message):
                    context.completion(.failure(.authenticationFailed(message: message)))
                case .untrustedCertificate(let message):
                    context.completion(.failure(.certificateError(message: message)))
                case .none:
                    context.completion(.failure(.noInfoAvailable))
                }
            } else if nsError.code == NSURLErrorTimedOut {
                context.completion(.failure(.timeout(fileProvider: .keepassiumWebDAV)))
            } else {
                context.completion(.failure(.systemError(error)))
            }
            return
        }

        guard let httpResponse = task.response as? HTTPURLResponse else {
            context.completion(.failure(.internalError))
            return
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let statusText = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            let message = "\(httpResponse.statusCode): \(statusText)"
            switch httpResponse.statusCode {
            case 401, 403:
                context.completion(.failure(.authenticationFailed(message: message)))
            case 404, 410:
                context.completion(.failure(.fileNotFound(message: message)))
            default:
                context.completion(.failure(
                    .serverSideError(statusCode: httpResponse.statusCode, message: message)
                ))
            }
            return
        }

        let response = WebDAVResponse(
            data: ByteArray(data: context.receivedData),
            contentLength: httpResponse.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init),
            lastModified: Date.parse(httpHeaderValue: httpResponse.value(forHTTPHeaderField: "Last-Modified"))
        )
        context.completion(.success(response))
    }

    private func evaluateTrust(_ trust: SecTrust, allowUntrusted: Bool) -> Bool {
        if allowUntrusted {
            return true
        }
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(trust, &result)
        return status == errSecSuccess
            && (result == .proceed || result == .unspecified)
    }
}

public struct WebDAVResponse {
    public let data: ByteArray
    public let contentLength: Int64?
    public let lastModified: Date?
}

extension WebDAVClient: URLSessionDataDelegate, URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let context = context(for: task) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        if challenge.previousFailureCount > 0 {
            let message = task.error?.localizedDescription
                ?? NSLocalizedString(
                    "[WebDAV] Authentication failed",
                    bundle: Bundle.framework,
                    value: "Authentication failed.",
                    comment: "Error message: WebDAV server rejected the supplied credentials.")
            context.cancelReason = .authenticationFailed(message)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic,
             NSURLAuthenticationMethodDefault:
            completionHandler(.useCredential, context.credential)
        case NSURLAuthenticationMethodServerTrust:
            guard let trust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            if evaluateTrust(trust, allowUntrusted: context.allowUntrustedCertificate) {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                let message = NSLocalizedString(
                    "[WebDAV] Untrusted certificate",
                    bundle: Bundle.framework,
                    value: "The server certificate is not trusted.",
                    comment: "Error message: WebDAV server uses an invalid TLS certificate.")
                context.cancelReason = .untrustedCertificate(message)
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        context(for: dataTask)?.receivedData.append(data)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        finish(task: task, error: error)
    }
}
