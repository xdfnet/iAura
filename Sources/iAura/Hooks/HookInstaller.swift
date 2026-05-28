import Foundation
import CryptoKit

enum HookInstaller {
    private static let iauraDir = NSString(string: "~/.config/iaura").expandingTildeInPath
    private static let hookShPath = "\(iauraDir)/hook-speak.sh"
    private static let piExtensionPath = "\(iauraDir)/iaura.ts"

    static func installAll() throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: iauraDir, withIntermediateDirectories: true, attributes: nil)

        try copyResource(named: "hook-speak.sh", toDir: iauraDir, executable: true)
        try copyResource(named: "iaura.ts", toDir: iauraDir, executable: false)
        try installClaude()
        try installCodex()
        try installPi()
        Log.info("Hook 脚本已安装到 \(iauraDir)")
    }

    private static func copyResource(named: String, toDir: String, executable: Bool) throws {
        guard let src = Bundle.module.url(forResource: named, withExtension: nil, subdirectory: "Resources") else {
            throw NSError(domain: "iAura", code: 1, userInfo: [NSLocalizedDescriptionKey: "缺少资源文件: \(named)"])
        }
        let dst = URL(fileURLWithPath: toDir).appendingPathComponent(named)
        let fm = FileManager.default
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
        if executable {
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst.path)
        }
    }

    private static func installClaude() throws {
        let path = NSString(string: "~/.claude/settings.json").expandingTildeInPath
        let command = "bash \(hookShPath) claude"
        var root = try readJSONDictionary(path: path)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        hooks["Stop"] = [stopHook(command: command, timeout: nil)]
        root["hooks"] = hooks
        try writeJSONDictionary(root, path: path)
    }

    private static func installCodex() throws {
        let hooksPath = NSString(string: "~/.codex/hooks.json").expandingTildeInPath
        let command = "bash \(hookShPath) codex"
        var root = try readJSONDictionary(path: hooksPath)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        hooks["Stop"] = [stopHook(command: command, timeout: 30)]
        root["hooks"] = hooks
        try writeJSONDictionary(root, path: hooksPath)

        let hash = try codexTrustedHash(command: command, timeout: 30)
        let configPath = NSString(string: "~/.codex/config.toml").expandingTildeInPath
        try installCodexTrust(configPath: configPath, trustedHash: hash)
    }

    private static func installPi() throws {
        let path = NSString(string: "~/.pi/agent/settings.json").expandingTildeInPath
        var root = try readJSONDictionary(path: path)
        let current = root["extensions"] as? [Any] ?? []
        var filtered: [String] = []
        for item in current {
            guard let s = item as? String else { continue }
            let lower = s.lowercased()
            if lower.contains("ispeak") || lower.contains("/.config/ivox/") || lower.contains("/.config/iaura/") {
                continue
            }
            filtered.append(s)
        }
        filtered.append(piExtensionPath)
        root["extensions"] = filtered
        try writeJSONDictionary(root, path: path)
    }

    private static func stopHook(command: String, timeout: Int?) -> [String: Any] {
        var hook: [String: Any] = ["type": "command", "command": command]
        if let timeout {
            hook["timeout"] = timeout
        }
        return ["hooks": [hook]]
    }

    private static func readJSONDictionary(path: String) throws -> [String: Any] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return [:] }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        if data.isEmpty { return [:] }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw NSError(domain: "iAura", code: 2, userInfo: [NSLocalizedDescriptionKey: "JSON 结构异常: \(path)"])
        }
        return dict
    }

    private static func writeJSONDictionary(_ dict: [String: Any], path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: path) {
            let backupPath = path + ".iaura.bak"
            if !FileManager.default.fileExists(atPath: backupPath) {
                try FileManager.default.copyItem(atPath: path, toPath: backupPath)
            }
        }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        var text = String(data: data, encoding: .utf8) ?? "{}"
        text = text.replacingOccurrences(of: "\\/", with: "/")
        text.append("\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func codexTrustedHash(command: String, timeout: Int) throws -> String {
        let identity: [String: Any] = [
            "event_name": "stop",
            "hooks": [
                [
                    "async": false,
                    "command": command,
                    "timeout": timeout,
                    "type": "command",
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: identity, options: [.sortedKeys])
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "sha256:\(hex)"
    }

    private static func installCodexTrust(configPath: String, trustedHash: String) throws {
        let key = "\(NSHomeDirectory())/.codex/hooks.json:stop:0:0"
        let blockHeader = "[hooks.state.\"\(key)\"]"
        let backupPath = configPath + ".iaura.bak"
        let fm = FileManager.default
        var text = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
        if fm.fileExists(atPath: configPath), !fm.fileExists(atPath: backupPath) {
            try fm.copyItem(atPath: configPath, toPath: backupPath)
        }

        if text.contains(blockHeader) {
            let escapedKey = NSRegularExpression.escapedPattern(for: key)
            let pattern = "(\\[hooks\\.state\\.\"\(escapedKey)\"\\]\\n)(.*?)(?=\\n\\[|\\z)"
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let bodyRange = Range(match.range(at: 2), in: text),
               let fullRange = Range(match.range(at: 0), in: text),
               let headerRange = Range(match.range(at: 1), in: text) {
                var body = String(text[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if body.range(of: #"(?m)^enabled\s*="#, options: .regularExpression) == nil {
                    body = "enabled = true\n" + body
                }
                if body.range(of: #"(?m)^trusted_hash\s*="#, options: .regularExpression) != nil {
                    body = body.replacingOccurrences(
                        of: #"(?m)^trusted_hash\s*=.*$"#,
                        with: #"trusted_hash = "\#(trustedHash)""#,
                        options: .regularExpression
                    )
                } else {
                    body += "\ntrusted_hash = \"\(trustedHash)\""
                }
                text.replaceSubrange(fullRange, with: text[headerRange] + body + "\n")
            }
        } else {
            if !text.contains("[hooks.state]") {
                text = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n[hooks.state]\n"
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text += "\n\n\(blockHeader)\n"
            text += "enabled = true\n"
            text += "trusted_hash = \"\(trustedHash)\"\n"
        }

        try FileManager.default.createDirectory(atPath: (configPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try text.write(toFile: configPath, atomically: true, encoding: .utf8)
    }
}
