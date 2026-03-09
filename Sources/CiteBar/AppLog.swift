import Foundation

enum AppLog {
    static func debug(_ message: @autoclosure () -> String) {
#if DEBUG
        print(message())
#endif
    }
    
    static func error(_ message: @autoclosure () -> String) {
        print(message())
    }
}
