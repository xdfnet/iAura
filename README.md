# iAura

macOS 本地语音播报守护进程，纯 Swift 实现。

## 特性

- **纯 Swift** — 无 Python、无 Go，单进程运行
- **原生 AVAudioEngine** — 直接调用 Apple 音频框架，零跨语言桥接
- **MLX 推理** — 通过 mlx-audio-swift 在 Apple Silicon GPU 上运行 Qwen3-TTS 模型
- **流式合成+播放** — 边合成边播，`scheduleBuffer` 首帧延迟 ~300ms
- **多音色** — 4 种内置音色，支持按来源自动匹配 + 显式覆盖
- **AI 工具集成** — 自动接入 Claude Code / Codex / Pi，Stop Hook 回复自动播报
- **launchd 守护** — `KeepAlive` 挂了自动拉起，开机自启

## 安装

```bash
git clone <repo> && cd iAura
make install      # 编译 + 部署到 ~/.local
iaura setup       # 初始化配置、Hook、launchd
```

## CLI

| 命令 | 说明 |
|------|------|
| `iaura speak [-s source] [-v voice] <文本>` | 一次性播报 |
| `iaura serve` | 启动守护进程 |
| `iaura stop` | 停止守护进程 |
| `iaura restart` | 重启守护进程（launchd kickstart） |
| `iaura status` | 查看运行状态 |
| `iaura version` | 显示版本信息 |
| `iaura voice list` | 列出所有可用音色 |
| `iaura setup` | 初始化环境 |

## 开发

```bash
make build         # 编译 release
make debug         # 编译 + 前台启动（看日志）
make install       # 编译 + 部署
make restart       # 重启 launchd daemon
make clean         # 清理 .build
```

## 配置

`~/.config/iaura/config.json`：

```json
{
  "model": { "path": "~/.config/iaura/models/Qwen3-TTS-12Hz-1.7B-Base-8bit" },
  "defaultVoice": "mizai",
  "sourceVoices": { "claude": "taozi", "codex": "wanwan", "pi": "dayi" },
  "voices": [
    { "id": "mizai", "name": "米仔", "refAudio": "voices/ref_mizai.wav", "refText": "大家好…" }
  ]
}
```

- `sourceVoices` — 按 AI 工具自动匹配音色
- 播报时 `--voice` 显式指定优先级最高

## 部署结构

所有运行时文件在 `~` 下，删掉项目目录无影响：

```
~/.local/bin/iaura                         # CLI 入口
~/.local/share/iaura/runtime/iAura         # 二进制
~/.local/share/iaura/runtime/default.metallib  # MLX Metal 库
~/.config/iaura/config.json                # 配置
~/.config/iaura/voices/*.wav               # 参考音色
~/.config/iaura/hook-speak.sh              # Claude Code / Codex Hook
~/.config/iaura/iaura.ts                   # Pi 扩展
~/Library/LaunchAgents/com.user.iaura.plist # launchd 守护
```

## 架构

```
iaura speak --source codex "文本"
  → Unix Socket {source:codex}文本
  → ConnectionHandler 解析 source/voice
  → PlaybackQueue 入队
  → TTSEngine.synthesizeStream()  流式生成 PCM
  → AudioPlayer.write()           scheduleBuffer 流式播放
```

详见 `docs/architecture.md`

## 依赖

- macOS 14 Sonoma+
- Apple Silicon (M1+)
- Swift 6 / Xcode 15+

## 许可

MIT
