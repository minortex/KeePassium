//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public class ProgressObserver: NSObject {
    internal let progress: ProgressEx
    private var isObservingProgress = false
    
    init(progress: ProgressEx) {
        self.progress = progress
    }
    
    func startObservingProgress() {
        assert(!isObservingProgress)
        isObservingProgress = true
        progress.addObserver(
            self,
            forKeyPath: "fractionCompleted",
            options: [.new],
            context: nil
        )
        progress.addObserver(
            self,
            forKeyPath: "localizedDescription",
            options: [.new],
            context: nil
        )
    }
    
    func stopObservingProgress() {
        guard isObservingProgress else { return }
        isObservingProgress = false
        progress.removeObserver(
            self,
            forKeyPath: "fractionCompleted"
        )
        progress.removeObserver(
            self,
            forKeyPath: "localizedDescription"
        )
    }

    deinit {
        stopObservingProgress()
    }

    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard let progress = object as? ProgressEx else { return }
        progressDidChange(progress: progress)
    }
    
    func progressDidChange(progress: ProgressEx) {
        assertionFailure("Override this")
    }
}
