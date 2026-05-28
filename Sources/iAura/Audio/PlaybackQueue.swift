import Foundation
import iAuraKit

struct PlaybackJob: Sendable {
    let text: String
    let voiceID: String
    let source: String
}

actor PlaybackQueue {
    private var jobs: [PlaybackJob] = []
    private var isProcessing = false
    private let player = AudioPlayer()
    private let engine: TTSEngine

    init(engine: TTSEngine) {
        self.engine = engine
    }

    func enqueue(_ job: PlaybackJob) {
        jobs.append(job)
        Log.info("队列状态: pending=\(jobs.count) processing=\(isProcessing)")
        if !isProcessing {
            Task { await processNext() }
        }
    }

    private func processNext() async {
        guard !jobs.isEmpty else { isProcessing = false; return }
        isProcessing = true
        let job = jobs.removeFirst()

        Log.info("TTS 播放开始 [\(job.source)] \(job.text.prefix(30))...")
        let startedAt = Date()

        do {
            let chunks = try await engine.synthesize(text: job.text, voiceID: job.voiceID)
            var totalBytes = 0
            for chunk in chunks {
                totalBytes += chunk.count
                player.write(chunk)
            }
            Log.info("播放写入: chunks=\(chunks.count) bytes=\(totalBytes)")
            await player.drain()
            Log.info("TTS 播放完成 [\(job.source)] \(String(format: "%.1f", -startedAt.timeIntervalSinceNow))s")
        } catch {
            Log.error("TTS 合成失败: \(error)")
        }

        await processNext()
    }
}
