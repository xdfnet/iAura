import Foundation
import os.log

enum Log {
    private static let subsystem = "com.user.iaura"
    private static let log = OSLog(subsystem: subsystem, category: "daemon")
    private static let fileQueue = DispatchQueue(label: "com.user.iaura.filelog")
    private static let filePath = NSString(string: "~/.config/iaura/daemon.log").expandingTildeInPath

    static func info(_ message: String) {
        os_log("%{public}s", log: log, type: .info, message)
        writeFile("INFO", message)
    }

    static func error(_ message: String) {
        os_log("%{public}s", log: log, type: .error, message)
        writeFile("ERROR", message)
    }

    static func debug(_ message: String) {
        os_log("%{public}s", log: log, type: .debug, message)
        writeFile("DEBUG", message)
    }

    private static func writeFile(_ level: String, _ message: String) {
        fileQueue.async {
            let line = "\(timestamp()) [\(level)] \(message)\n"
            let data = Data(line.utf8)
            let dir = (filePath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            if !FileManager.default.fileExists(atPath: filePath) {
                FileManager.default.createFile(atPath: filePath, contents: data)
                return
            }
            guard let handle = FileHandle(forWritingAtPath: filePath) else { return }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }

    private static func timestamp() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df.string(from: Date())
    }
}
