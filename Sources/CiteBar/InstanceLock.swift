import Foundation

/// One CiteBar process at a time works with the data files: the menu bar app or a background
/// `--refresh` run (#44). A file lock rather than a process check, because launchd and cron
/// jobs run where apps aren't visible. The lock lasts until the process exits.
enum InstanceLock {
    /// Takes the lock if it's free.
    static func tryAcquire() -> Bool {
        lock(waiting: false)
    }

    /// Runs `body` on the main actor once the lock is ours, right away unless a background
    /// refresh is mid-run. `waited` says the data files may have changed in the meantime.
    @MainActor static func whenAvailable(_ body: @escaping @MainActor @Sendable (_ waited: Bool) -> Void) {
        if tryAcquire() {
            body(false)
            return
        }
        AppLog.debug("A background refresh is running; loading data when it finishes")
        DispatchQueue.global(qos: .userInitiated).async {
            _ = lock(waiting: true)
            Task { @MainActor in body(true) }
        }
    }

    private static func lock(waiting: Bool) -> Bool {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return true
        }
        let folder = support.appendingPathComponent("CiteBar")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptor = open(folder.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else { return true }
        // The descriptor stays open on purpose: closing it would release the lock.
        if flock(descriptor, LOCK_EX | (waiting ? 0 : LOCK_NB)) == 0 {
            return true
        }
        close(descriptor)
        return false
    }
}
