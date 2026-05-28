import XCTest
@testable import iAuraKit

final class ConfigTests: XCTestCase {

    func testValidationFailsOnMissingDefaultVoice() {
        let config = Config(
            model: ModelConfig(path: "/tmp/model"),
            defaultVoice: "missing",
            sourceVoices: [:],
            voices: [VoiceInfo(id: "voice", name: nil, refAudio: nil, refText: nil, description: nil)],
            configBaseDir: nil
        )
        XCTAssertThrowsError(try validate(config))
    }

    func testValidationFailsOnMissingSourceVoice() {
        let config = Config(
            model: ModelConfig(path: "/tmp/model"),
            defaultVoice: "voice",
            sourceVoices: ["codex": "missing"],
            voices: [VoiceInfo(id: "voice", name: nil, refAudio: nil, refText: nil, description: nil)],
            configBaseDir: nil
        )
        XCTAssertThrowsError(try validate(config))
    }

    func testValidationPassesOnValidConfig() {
        let config = Config(
            model: ModelConfig(path: "/tmp/model"),
            defaultVoice: "v1",
            sourceVoices: ["c": "v1"],
            voices: [VoiceInfo(id: "v1", name: nil, refAudio: nil, refText: nil, description: nil)],
            configBaseDir: nil
        )
        XCTAssertNoThrow(try validate(config))
    }
}
