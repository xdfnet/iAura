// @unchecked Sendable: AVAudioEngine 需要在实时音频线程操作，不能使用 actor。
// 所有可变状态通过 serialQueue 串行化，线程安全由手工保证。
import AVFoundation
import Foundation

final class AudioPlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let serialQueue = DispatchQueue(label: "iaura.audio")
    private var pendingCount = 0
    private var started = false
    private var initError: String?

    init() {
        format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: false)!

        var ok = true
        serialQueue.sync {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.prepare()
            do {
                try engine.start()
            } catch {
                initError = "AudioEngine 启动失败: \(error)"
                Log.error(initError!)
                ok = false
                return
            }
        }
        guard ok else { return }
        node.play()
        started = true
    }

    var isStarted: Bool { started }

    func write(_ pcm: Data) {
        guard started, !pcm.isEmpty else { return }
        let frames = AVAudioFrameCount(pcm.count / 2)
        serialQueue.sync {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
            buffer.frameLength = frames
            pcm.withUnsafeBytes { src in
                guard let srcPtr = src.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
                if let dst = buffer.int16ChannelData?.pointee {
                    dst.initialize(from: srcPtr, count: Int(frames))
                }
            }
            pendingCount += 1
            node.scheduleBuffer(buffer) { [weak self] in
                guard let self else { return }
                self.serialQueue.async { self.pendingCount -= 1 }
            }
        }
    }

    func drain() async {
        for _ in 0..<1200 {
            let done = serialQueue.sync { pendingCount == 0 }
            if done { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func stop() {
        serialQueue.sync {
            started = false
            node.stop()
            engine.stop()
        }
    }
}
