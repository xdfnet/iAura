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

    func warmup(voiceID: String) async {
        do {
            Log.info("模型预热 [\(voiceID)]...")
            let stream = synthesizeStream(text: "你好，模型预热完成。", voiceID: voiceID)
            for try await _ in stream { /* GPU pipeline 预热 */ }
            Log.info("模型预热完成 [\(voiceID)]")
        } catch {
            Log.info("模型预热跳过 [\(voiceID)]: \(error)")
        }
    }

    func synthesizeStream(text: String, voiceID: String) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let model = model else { throw TTSError.notLoaded }

                    let voice = config.voice(id: voiceID)
                    let refText = voice?.refText
                    let refAudio = try loadRefAudio(voice?.refAudio, sampleRate: model.sampleRate)
                    Log.info("TTS 请求: voice=\(voiceID) text_chars=\(text.count) stream=true")

                    let stream = model.generateStream(
                        text: text,
                        voice: nil,
                        refAudio: refAudio,
                        refText: refText,
                        language: "Chinese",
                        generationParameters: model.defaultGenerationParameters,
                        streamingInterval: 0.08
                    )

                    var chunkIdx = 0
                    for try await event in stream {
                        if case .audio(let chunk) = event {
                            let samples: [Float] = chunk.asArray(Float.self)
                            let pcm = audioToPCM(samples)
                            Log.debug("TTS 流式 [\(chunkIdx)]: samples=\(samples.count) pcm_bytes=\(pcm.count)")
                            continuation.yield(pcm)
                            chunkIdx += 1
                        }
                    }
                    Log.info("TTS 流式完成: chunks=\(chunkIdx)")
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private func resolveRefAudioPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let expanded = expandPath(path)
        if expanded.hasPrefix("/") { return expanded }
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
