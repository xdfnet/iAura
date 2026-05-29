import ArgumentParser
import Foundation
import iAuraKit

struct VoiceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "voice",
        abstract: "音色管理",
        subcommands: [VoiceList.self, VoiceAdd.self, VoiceRemove.self]
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

struct VoiceAdd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "添加自定义音色"
    )

    @Option(name: .shortAndLong, help: "音色 ID")
    var id: String

    @Option(name: .shortAndLong, help: "音色名称")
    var name: String?

    @Option(name: .long, help: "参考音频路径 (.wav)")
    var refAudio: String

    @Option(name: .long, help: "参考文本（对应 refAudio 内容）")
    var refText: String

    @Option(name: .shortAndLong, help: "音色描述")
    var description: String?

    func run() throws {
        let fm = FileManager.default
        let configPath = NSString(string: "~/.config/iaura/config.json").expandingTildeInPath
        var config = try loadConfig(from: configPath)

        guard config.voice(id: id) == nil else {
            print("[✗] 音色 ID \(id) 已存在")
            return
        }

        let voicesDir = NSString(string: "~/.config/iaura/voices").expandingTildeInPath
        try fm.createDirectory(atPath: voicesDir, withIntermediateDirectories: true, attributes: nil)
        let audioFilename = "ref_\(id).wav"
        let dstAudio = (voicesDir as NSString).appendingPathComponent(audioFilename)

        let srcURL = URL(fileURLWithPath: refAudio.expandingTilde)
        guard fm.fileExists(atPath: srcURL.path) else {
            print("[✗] 参考音频不存在: \(refAudio)")
            return
        }
        if !fm.fileExists(atPath: dstAudio) {
            try fm.copyItem(at: srcURL, to: URL(fileURLWithPath: dstAudio))
            print("[✓] 音频已复制: \(dstAudio)")
        }

        let voice = VoiceInfo(
            id: id,
            name: name ?? id,
            refAudio: "voices/\(audioFilename)",
            refText: refText,
            description: description
        )
        config.voices.append(voice)
        try saveConfig(config, to: configPath)
        print("[✓] 已添加音色: \(voice.name ?? id) (\(id))")
    }
}

struct VoiceRemove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "删除自定义音色"
    )

    @Option(name: .shortAndLong, help: "音色 ID")
    var id: String

    func run() throws {
        let configPath = NSString(string: "~/.config/iaura/config.json").expandingTildeInPath
        var config = try loadConfig(from: configPath)

        guard let voice = config.voice(id: id) else {
            print("[✗] 音色 ID \(id) 不存在")
            return
        }
        guard id != config.defaultVoice else {
            print("[✗] 不能删除默认音色 (\(id))")
            return
        }

        config.voices.removeAll { $0.id == id }
        config.sourceVoices = config.sourceVoices.filter { $0.value != id }
        try saveConfig(config, to: configPath)

        // 清理音频文件
        if let ref = voice.refAudio, ref.hasPrefix("voices/") {
            let audioPath = NSString(string: "~/.config/iaura/\(ref)").expandingTildeInPath
            try? FileManager.default.removeItem(atPath: audioPath)
        }
        print("[✓] 已删除音色: \(voice.name ?? id) (\(id))")
    }
}

private extension String {
    var expandingTilde: String {
        NSString(string: self).expandingTildeInPath
    }
}
