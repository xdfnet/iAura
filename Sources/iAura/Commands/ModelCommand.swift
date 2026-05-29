import ArgumentParser
import Foundation

struct ModelCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "model",
        abstract: "模型管理",
        subcommands: [ModelPull.self]
    )
}

struct ModelPull: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pull",
        abstract: "从 ModelScope 下载 Qwen3-TTS 模型"
    )

    func run() async throws {
        let modelDir = NSString(string: "~/.config/iaura/models").expandingTildeInPath
        let modelPath = (modelDir as NSString).appendingPathComponent("Qwen3-TTS-12Hz-1.7B-Base-8bit")
        let fm = FileManager.default

        if fm.fileExists(atPath: modelPath) {
            print("[i] 模型已存在: \(modelPath)")
            return
        }

        try fm.createDirectory(atPath: modelDir, withIntermediateDirectories: true, attributes: nil)
        print("[i] 下载模型到 \(modelDir) ...")

        let repoURL = "https://www.modelscope.cn/models/mlx-community/Qwen3-TTS-12Hz-1.7B-Base-8bit.git"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["clone", "--depth", "1", repoURL, modelPath]
        p.standardOutput = Pipe()
        p.standardError = Pipe()

        do {
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus == 0 {
                print("[✓] 模型已下载: \(modelPath)")
            } else {
                let errData = (p.standardError as! Pipe).fileHandleForReading.readDataToEndOfFile()
                let err = String(data: errData, encoding: .utf8) ?? "未知错误"
                print("[✗] 下载失败: \(err)")
            }
        } catch {
            print("[✗] 无法启动 git: \(error)")
            print("[i] 请手动 clone: git clone --depth 1 \(repoURL) \(modelPath)")
        }
    }
}
