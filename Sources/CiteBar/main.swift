import Cocoa
import SwiftUI

// Set up global error handling
NSSetUncaughtExceptionHandler { exception in
    print("Uncaught exception: \(exception)")
    print("Stack trace: \(exception.callStackSymbols)")
    // Don't crash, just log the error
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.setActivationPolicy(.accessory)
app.run()