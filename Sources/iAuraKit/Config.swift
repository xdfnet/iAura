import Foundation

// MARK: - Codable 模型

public struct ModelConfig: Codable, Sendable {
    public var path: String
}

public struct VoiceInfo: Codable, Sendable {
    public var id: String
    public var name: String?
    public var refAudio: String?
    public var refText: String?
    public var description: String?
}

public struct Config: Codable, Sendable {
    public var model: ModelConfig
    public var defaultVoice: String
    public var sourceVoices: [String: String]
    public var voices: [VoiceInfo]
    public var configBaseDir: String?

    public var voiceByID: [String: VoiceInfo] {
        var map: [String: VoiceInfo] = [:]
        for v in voices { map[v.id] = v }
        return map
    }

    public func voice(id: String) -> VoiceInfo? {
        voiceByID[id]
    }
}

// MARK: - 加载

public enum ConfigError: Error {
    case fileNotFound(String)
    case invalidJSON(String)
    case invalidConfig(String)
}

public func loadConfig(from path: String? = nil) throws -> Config {
    let configPath = path ?? NSString(string: "~/.config/iaura/config.json").expandingTildeInPath
    guard FileManager.default.fileExists(atPath: configPath) else {
        throw ConfigError.fileNotFound(configPath)
    }
    let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
    let decoder = JSONDecoder()
    var config: Config
    do {
        config = try decoder.decode(Config.self, from: data)
    } catch {
        throw ConfigError.invalidJSON("\(configPath): \(error)")
    }
    config.configBaseDir = (configPath as NSString).deletingLastPathComponent
    try validate(config)
    return config
}

public func validate(_ config: Config) throws {
    if config.model.path.isEmpty {
        throw ConfigError.invalidConfig("model.path 未设置")
    }
    if config.defaultVoice.isEmpty {
        throw ConfigError.invalidConfig("defaultVoice 未设置")
    }
    if config.voice(id: config.defaultVoice) == nil {
        throw ConfigError.invalidConfig("defaultVoice 不存在: \(config.defaultVoice)")
    }
    for (source, id) in config.sourceVoices {
        if config.voice(id: id) == nil {
            throw ConfigError.invalidConfig("sourceVoices.\(source) 不存在: \(id)")
        }
    }
}
