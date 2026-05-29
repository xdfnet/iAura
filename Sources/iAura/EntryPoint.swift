import ArgumentParser
import Foundation

@main
struct iAura: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "iaura",
        abstract: "macOS 本地语音播报守护进程",
        subcommands: [
            ServeCommand.self,
            SpeakCommand.self,
            VoiceCommand.self,
            StopCommand.self,
            StatusCommand.self,
            VersionCommand.self,
            RestartCommand.self,
        ],
        defaultSubcommand: ServeCommand.self
    )
}
