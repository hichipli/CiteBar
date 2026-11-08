import Cocoa
import SwiftUI

// Set up global error handling
NSSetUncaughtExceptionHandler { exception in
    print("Uncaught exception: \(exception)")
    print("Stack trace: \(exception.callStackSymbols)")
    // Don't crash, just log the error
}

// `--refresh` runs one update without the menu bar app: from the background task that
// Settings › General turns on, or from cron (#44).
if CommandLine.arguments.contains("--refresh") {
    // The menu bar app holds the lock while it runs and keeps the data current itself.
    guard InstanceLock.tryAcquire() else {
        print("CiteBar is running and keeps itself up to date.")
        exit(0)
    }
    Task { @MainActor in
        let result = await CitationManager().refreshFromCommandLine()
        print(result.message)
        exit(result.succeeded ? 0 : 1)
    }
    // Not dispatchMain(): that retires the main thread, and MainActor code must run on it.
    RunLoop.main.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.setActivationPolicy(.accessory)
app.run()
