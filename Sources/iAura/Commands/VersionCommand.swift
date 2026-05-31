import ArgumentParser
import Foundation

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "显示 iAura 版本",
        version: iAuraVersion
    )

    func run() throws {
        print("iAura v\(iAuraVersion)")
        print("macOS 本地语音播报守护进程")
        print("纯 Swift · MLX TTS · AVAudioEngine")
    }
}
