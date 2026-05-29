import XCTest
@testable import iAuraKit

final class ConfigRoundTripTests: XCTestCase {

    func testSaveAndLoadRoundTrip() throws {
        let original = Config(
            model: ModelConfig(path: "/tmp/test-model"),
            defaultVoice: "v1",
            sourceVoices: ["s": "v1"],
            voices: [
                VoiceInfo(id: "v1", name: "测试", refAudio: "a.wav", refText: "你好", description: "desc"),
            ],
            configBaseDir: nil
        )

        let tmpPath = NSTemporaryDirectory() + "iaura-test-config.json"

        try saveConfig(original, to: tmpPath)
        let loaded = try loadConfig(from: tmpPath)

        XCTAssertEqual(loaded.defaultVoice, "v1")
        XCTAssertEqual(loaded.model.path, "/tmp/test-model")
        XCTAssertEqual(loaded.sourceVoices["s"], "v1")
        let v = try XCTUnwrap(loaded.voice(id: "v1"))
        XCTAssertEqual(v.name, "测试")
        XCTAssertEqual(v.refAudio, "a.wav")
        XCTAssertEqual(v.refText, "你好")

        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    func testVoiceAddAndRemoveRoundTrip() throws {
        let original = Config(
            model: ModelConfig(path: "/tmp/m"),
            defaultVoice: "a",
            sourceVoices: [:],
            voices: [VoiceInfo(id: "a", name: "AA", refAudio: nil, refText: nil, description: nil)],
            configBaseDir: nil
        )
        let tmpPath = NSTemporaryDirectory() + "iaura-test-voices.json"
        try saveConfig(original, to: tmpPath)

        var reloaded = try loadConfig(from: tmpPath)
        reloaded.voices.append(VoiceInfo(id: "b", name: "BB", refAudio: "b.wav", refText: "hi", description: "new"))
        try saveConfig(reloaded, to: tmpPath)

        let final = try loadConfig(from: tmpPath)
        XCTAssertEqual(final.voices.count, 2)
        XCTAssertNotNil(final.voice(id: "b"))
        XCTAssertEqual(final.voice(id: "b")?.name, "BB")

        try? FileManager.default.removeItem(atPath: tmpPath)
    }
}
