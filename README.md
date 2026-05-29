# iAura

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-FA7343?logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Apple_Silicon-M1%2B-A2AAAD?logo=apple&logoColor=white" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/TTS-MLX_GPU-7B68EE?logo=mlflow&logoColor=white" alt="MLX GPU TTS">
  <img src="https://img.shields.io/badge/license-MIT-green?logo=opensourceinitiative&logoColor=white" alt="MIT">
</p>

<p align="center"><b>让 Claude / Codex / Pi 开口说话。</b></p>

---

> 写代码时懒得看屏幕？iAura 自动把你的 AI 助手的回复读给你听。  
> 音色自然、反应快、不打扰你正在播的音乐。

| 🗣️ 替我读 | ⚡ 秒回 | 🎵 不打断 | 🎭 让 Claude/Codex/Pi 开口 | 🔌 开箱即用 |
|:---:|:---:|:---:|:---:|:---:|
| AI 回复自动播报<br>不用盯着屏幕 | 开口不到半秒<br>听到的速度 | 播报前暂停音乐<br>播完自动恢复 | 换个音色<br>换种心情 | 一条命令装好<br>自动注册自启动 |

---

## 安装


```bash
git clone https://github.com/xdfnet/iAura && cd iAura
./install.sh              # 编译 + 签名 + 部署 + 守护
```

> 首次安装后去 **系统设置 → 隐私与安全性 → 辅助功能** 添加 iAura，  
> 播报时就能自动暂停音乐了（可选）。

## CLI

| 命令 | 说明 |
|------|------|
| `iaura speak [-s source] [-v voice] <文本>` | 一次性播报 |
| `iaura serve` | 启动守护进程 |
| `iaura stop` | 停止守护进程 |
| `iaura restart` | 重启守护进程 |
| `iaura status` | 查看运行状态 |
| `iaura version` | 显示版本信息 |
| `iaura voice list` | 列出所有可用音色 |
| `| `iaura setup` | 初始化环境 |

## 开发

```bash
make build         # 编译 release
make debug         # 编译 + 前台启动（看日志）
make install       # 编译 + 部署
make restart       # 重启 launchd 守护
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
- 播报期间用系统媒体键自动暂停/恢复音乐

## 部署结构

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
