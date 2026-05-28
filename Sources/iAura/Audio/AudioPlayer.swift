import AVFoundation
import Foundation

final class AudioPlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let serialQueue = DispatchQueue(label: "iaura.audio")
    private var totalFrames: AVAudioFrameCount = 0
    private var started = false

    init() {
        format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: false)!
        serialQueue.sync {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.prepare()
        }
        do { try engine.start() } catch {
            Log.error("AudioEngine: \(error)")
            return
        }
        node.play()
        totalFrames = 0
        started = true
    }

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
            node.scheduleBuffer(buffer)
            totalFrames += frames
        }
    }

    func drain() async {
        let frames = serialQueue.sync { totalFrames }
        let sec = Double(frames) / format.sampleRate
        try? await Task.sleep(nanoseconds: UInt64(max(sec, 0.5) * 1_000_000_000) + 500_000_000)
        serialQueue.sync { totalFrames = 0 }
    }

    func stop() {
        serialQueue.sync {
            started = false
            node.stop()
            engine.stop()
        }
    }
}
