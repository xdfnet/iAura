import Foundation
import iAuraKit
import MLX
import MLXAudioCore
import MLXAudioTTS

actor TTSEngine {
    private var model: (any SpeechGenerationModel)?
    private var config: Config

    init(config: Config) {
        self.config = config
    }

    var isLoaded: Bool { model != nil }

    func loadModel() async throws {
        let modelPath = expandPath(config.model.path)
        Log.info("加载 TTS 模型: \(modelPath)")
        model = try await TTS.loadModel(modelRepo: modelPath)
        Log.info("TTS 模型加载完成")
    }

    /// 流式生成 — 返回 float32 采样序列 (24kHz mono)
    func synthesize(text: String, voiceID: String) async throws -> [Data] {
        guard let model = model else { throw TTSError.notLoaded }

        let voice = config.voice(id: voiceID)
        let refText = voice?.refText
        let refAudio = try loadRefAudio(voice?.refAudio, sampleRate: model.sampleRate)
        Log.info("TTS 请求: voice=\(voiceID) text_chars=\(text.count) has_ref_audio=\(refAudio != nil) has_ref_text=\(refText != nil)")
        let stream = model.generateStream(
            text: text,
            voice: nil,
            refAudio: refAudio,
            refText: refText,
            language: "Chinese",
            generationParameters: model.defaultGenerationParameters,
            streamingInterval: 0.08
        )

        var chunks: [Data] = []
        var sampleCount = 0
        for try await event in stream {
            if case .audio(let chunk) = event {
                let samples: [Float] = chunk.asArray(Float.self)
                sampleCount += samples.count
                chunks.append(audioToPCM(samples))
            }
        }
        Log.info("TTS 生成完成: chunks=\(chunks.count) samples=\(sampleCount)")
        return chunks
    }

    private func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private func resolveRefAudioPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let expanded = expandPath(path)
        if expanded.hasPrefix("/") {
            return expanded
        }
        if let base = config.configBaseDir, !base.isEmpty {
            return (base as NSString).appendingPathComponent(expanded)
        }
        return expanded
    }

    private func loadRefAudio(_ path: String?, sampleRate: Int) throws -> MLXArray? {
        guard let resolvedPath = resolveRefAudioPath(path) else { return nil }
        let url = URL(fileURLWithPath: resolvedPath)
        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            Log.info("参考音频不存在，跳过: \(resolvedPath)")
            return nil
        }
        let (_, refAudio) = try loadAudioArray(from: url, sampleRate: sampleRate)
        return refAudio
    }
}

enum TTSError: Error {
    case notLoaded
}
