import Darwin
import Foundation
import iAuraKit

actor Daemon {
    private let config: Config
    private let engine: TTSEngine
    private let queue: PlaybackQueue

    init(config: Config) {
        self.config = config
        self.engine = TTSEngine(config: config)
        self.queue = PlaybackQueue(engine: engine)
    }

    func run() async throws {
        Log.info("iAura 守护进程启动")

        try await engine.loadModel()
        await engine.warmup(voiceID: config.defaultVoice)

        signal(SIGINT) { _ in exit(0) }
        signal(SIGTERM) { _ in exit(0) }

        let socketPath = NSString(string: "~/.config/iaura/iaura.sock").expandingTildeInPath
        let dir = (socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)

        let handler = ConnectionHandler(queue: queue, config: config)
        let server = SocketServer()
        try await server.start(path: socketPath, handler: handler)

        Log.info("iAura 已启动，监听 \(socketPath)")

        while true {
            try await Task.sleep(for: .seconds(3600))
        }
    }
}
