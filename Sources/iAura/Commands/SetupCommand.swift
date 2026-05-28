import ArgumentParser
import Darwin
import Foundation

struct SetupCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "初始化 iAura 环境（配置、模型下载、Hook 安装）"
    )

    func run() async throws {
        let fm = FileManager.default
        let iauraDir = NSString(string: "~/.config/iaura").expandingTildeInPath
        try fm.createDirectory(atPath: iauraDir, withIntermediateDirectories: true, attributes: nil)

        let iauraConfigPath = (iauraDir as NSString).appendingPathComponent("config.json")
        if !fm.fileExists(atPath: iauraConfigPath) {
            guard let exampleURL = Bundle.module.url(forResource: "config.example", withExtension: "json", subdirectory: "Resources") else {
                throw RuntimeError("找不到内置配置模板")
            }
            try fm.copyItem(at: exampleURL, to: URL(fileURLWithPath: iauraConfigPath))
            try rewriteModelPath(in: iauraConfigPath)
            print("[✓] 已生成配置: \(iauraConfigPath)")
        } else {
            print("[i] 已存在配置: \(iauraConfigPath)")
        }
        try installVoices()
        print("[✓] 已初始化音色文件: ~/.config/iaura/voices")

        try HookInstaller.installAll()
        print("[✓] Hook 脚本已安装到 \(iauraDir)")
        try installLaunchAgent()
        print("[✓] 已注册并拉起 launchd: com.user.iaura")
        print("[i] 请确认模型目录存在: ~/.config/iaura/models/Qwen3-TTS-12Hz-1.7B-Base-8bit")
    }

    private func installLaunchAgent() throws {
        let fm = FileManager.default
        let runtime = try installRuntimeArtifacts()

        let launchAgentsDir = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath
        try fm.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
        let plistPath = (launchAgentsDir as NSString).appendingPathComponent("com.user.iaura.plist")

        guard let templateURL = Bundle.module.url(forResource: "com.user.iaura", withExtension: "plist", subdirectory: "Resources") else {
            throw RuntimeError("找不到 launchd 模板")
        }
        let template = try String(contentsOf: templateURL, encoding: .utf8)
        let rendered = template
            .replacingOccurrences(of: "BINARY_PATH_PLACEHOLDER", with: runtime.launcherPath)
            .replacingOccurrences(of: "WORKING_DIR_PLACEHOLDER", with: runtime.workingDirectory)
        try rendered.write(toFile: plistPath, atomically: true, encoding: .utf8)

        let uid = String(getuid())
        _ = runLaunchctl(["bootout", "gui/\(uid)", "com.user.iaura"])
        _ = runLaunchctl(["bootstrap", "gui/\(uid)", plistPath])
        _ = runLaunchctl(["kickstart", "-k", "gui/\(uid)/com.user.iaura"])
    }

    private func installRuntimeArtifacts() throws -> (launcherPath: String, workingDirectory: String) {
        let fm = FileManager.default
        let root = fm.currentDirectoryPath
        let releaseDir = (root as NSString).appendingPathComponent(".build/arm64-apple-macosx/release")
        let releaseBinary = (releaseDir as NSString).appendingPathComponent("iAura")
        let releaseMetallib = (releaseDir as NSString).appendingPathComponent("default.metallib")

        guard fm.fileExists(atPath: releaseBinary), fm.fileExists(atPath: releaseMetallib) else {
            throw RuntimeError("缺少 release 运行时，请先执行: swift build -c release")
        }

        let runtimeDir = NSString(string: "~/.local/share/iaura/runtime").expandingTildeInPath
        try fm.createDirectory(atPath: runtimeDir, withIntermediateDirectories: true, attributes: nil)
        let runtimeBinary = (runtimeDir as NSString).appendingPathComponent("iAura")
        let runtimeMetallib = (runtimeDir as NSString).appendingPathComponent("default.metallib")

        if fm.fileExists(atPath: runtimeBinary) { try fm.removeItem(atPath: runtimeBinary) }
        if fm.fileExists(atPath: runtimeMetallib) { try fm.removeItem(atPath: runtimeMetallib) }
        try fm.copyItem(atPath: releaseBinary, toPath: runtimeBinary)
        try fm.copyItem(atPath: releaseMetallib, toPath: runtimeMetallib)
        _ = chmod(runtimeBinary, 0o755)

        let launcherPath = NSString(string: "~/.local/bin/iaura").expandingTildeInPath
        let launcherDir = (launcherPath as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: launcherDir, withIntermediateDirectories: true, attributes: nil)
        let launcherScript = """
        #!/bin/bash
        exec "\(runtimeBinary)" "$@"
        """
        try launcherScript.write(toFile: launcherPath, atomically: true, encoding: .utf8)
        _ = chmod(launcherPath, 0o755)

        return (launcherPath, runtimeDir)
    }

    private func installVoices() throws {
        let fm = FileManager.default
        let voicesDir = NSString(string: "~/.config/iaura/voices").expandingTildeInPath
        try fm.createDirectory(atPath: voicesDir, withIntermediateDirectories: true, attributes: nil)

        let voiceFiles = ["ref_mizai.wav", "ref_taozi.wav", "ref_dayi.wav", "ref_wanwan.wav"]
        for file in voiceFiles {
            let dst = URL(fileURLWithPath: voicesDir).appendingPathComponent(file)
            if fm.fileExists(atPath: dst.path) { continue }
            guard let src = Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "Resources/voices") else {
                throw RuntimeError("缺少内置音色文件: \(file)")
            }
            try fm.copyItem(at: src, to: dst)
        }
    }

    private func rewriteModelPath(in configPath: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        var model = root["model"] as? [String: Any] ?? [:]
        model["path"] = "\(NSHomeDirectory())/.config/iaura/models/Qwen3-TTS-12Hz-1.7B-Base-8bit"
        root["model"] = model
        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let fixed = String(data: out, encoding: .utf8)!.replacingOccurrences(of: "\\/", with: "/")
        try (fixed + "\n").write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    @discardableResult
    private func runLaunchctl(_ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus
        } catch {
            return -1
        }
    }
}

private struct RuntimeError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
