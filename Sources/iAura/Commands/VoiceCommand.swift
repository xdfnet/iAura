import ArgumentParser
import Foundation
import iAuraKit

struct VoiceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "voice",
        abstract: "音色管理",
        subcommands: [VoiceList.self]
    )
}

struct VoiceList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "列出所有可用音色"
    )

    func run() throws {
        guard let config = try? loadConfig() else {
            print("无法加载配置 ~/.config/iaura/config.json")
            return
        }
        for v in config.voices {
            let mark = v.id == config.defaultVoice ? " ●" : "  "
            let name = v.name ?? v.id
            let desc = v.description.map { " — \($0)" } ?? ""
            print("\(mark) \(name) (\(v.id))\(desc)")
        }
    }
}
