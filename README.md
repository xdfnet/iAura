# iAura

macOS 本地语音播报守护进程，纯 Swift 实现。

## 特性

- **纯 Swift** — 无 Python、无 Go、无 CGo，单进程运行
- **原生 AVAudioEngine** — 不跨语言桥接，直接调用 Apple 音频框架
- **MLX 推理** — 通过 mlx-audio-swift 在 Apple Silicon GPU 上运行 TTS 模型
- **流式播放** — 边合成边播，首帧延迟 ~300ms
- **AI 工具集成** — 自动接入 Claude Code / Codex / Pi，回复完成自动播报

## 安装

```bash
# 编译
swift build -c release

# 安装
cp .build/release/iAura ~/.local/bin/iaura

# 初始化（下载模型 + 安装 Hook）
iaura setup

# 启动守护进程
iaura serve
```

## 使用

```bash
# 启动守护进程（默认）
iaura serve

# 一次性播报
iaura speak "你好，我是 iAura。"

# 音色列表
iaura voice list

# 停止守护进程
iaura stop
```

## 配置

`~/.config/iaura/config.json`：

```json
{
  "model": { "path": "~/.config/iaura/models/Qwen3-TTS-12Hz-1.7B-Base-8bit" },
  "defaultVoice": "wanwan",
  "sourceVoices": { "claude": "taozi", "codex": "wanwan", "pi": "dayi" },
  "voices": [{ "id": "mizai", "refAudio": "voices/ref_mizai.wav", "refText": "大家好..." }]
}
```

## 依赖

- macOS 14 Sonoma+
- Apple Silicon (M1+)
- Xcode 15+ / Swift 6

## 架构

详见 [docs/architecture.md](docs/architecture.md)

## 许可

MIT
