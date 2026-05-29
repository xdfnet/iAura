# iAura v1.0.0 发布说明

> 让 Claude / Codex / Pi 开口说话。

---

## 🎉 首个正式版本

经过一个月的密集迭代，iAura 正式发布 v1.0.0。
这是一个纯 Swift 实现的 macOS 本地 TTS 守护进程，专为 AI 编程助手打造。

## ✨ 核心特性

### 🗣️ 替我读
自动朗读 Claude Code、Codex、Pi 的回复，写代码不用盯着屏幕。

### ⚡ 流式合成，秒回
基于 MLX GPU 推理 `Qwen3-TTS-12Hz-1.7B` 模型，边合成边播放，首帧延迟仅 ~300ms。

### 🎵 不打断音乐
播报前自动暂停 Music / Spotify / QQ音乐 / 网易云，播完恢复。
通过 CGEvent 模拟系统媒体键，无外部依赖。

### 🎭 四色音色，认得清谁在说话
| 音色 | 名称 | 适用工具 |
|------|------|----------|
| 米仔 | 温暖自然 | 默认 |
| 甜妹桃子 | 活泼甜美 | Claude |
| 湾湾小何 | 温柔知性 | Codex |
| 大易 | 沉稳可靠 | Pi |

支持自定义音色 — 提供参考音频即可克隆。

### 🔌 开箱即用
```bash
brew tap xdfnet/iaura && brew install iaura
iaura model pull
```
Homebrew 安装 → 自动注册 launchd 守护 → 开机自启，无需装 Xcode。

### 🧠 智能文本清洗
自动过滤 Markdown、代码块、URL、UUID、进度条等不适合朗读的内容。

---

## 🚀 新增功能（v1.0.0 完整列表）

| 模块 | 内容 |
|------|------|
| 核心引擎 | MLX 流式 TTS、AVAudioEngine 播放、模型预热 |
| CLI | 9 个子命令：speak / serve / stop / restart / status / version / voice / model / setup |
| 守护进程 | launchd KeepAlive + RunAtLoad，Unix Socket 通信 |
| 媒体控制 | CGEvent 系统媒体键，播报暂停/恢复音乐 |
| Hook 集成 | Claude Code / Codex Stop Hook + Pi Extension |
| 音色管理 | 4 内置音色 + `voice add` 自定义 |
| 模型管理 | `model pull` 从 ModelScope 下载 |
| 文本清洗 | Markdown/URL/代码块/进度条/表格自动过滤 |
| 日志 | 自动轮转（5MB → .old） |
| 部署 | Homebrew + 源码 `install.sh` 双通道 |
| 代码签名 | Apple Development 证书签名，辅助功能权限绑定 |

---

## 📦 安装

### Homebrew（推荐）
```bash
brew tap xdfnet/iaura && brew install iaura
iaura model pull
```

### 从源码
```bash
git clone https://github.com/xdfnet/iAura && cd iAura
./install.sh
```

---

## 💡 使用提示

1. **辅助功能权限** — 系统设置 → 隐私与安全性 → 辅助功能，添加 iAura 后可自动暂停音乐
2. **自定义音色** — `iaura voice add --id myvoice --name "我的音色" --ref-audio voice.wav --ref-text "参考文本"`
3. **查看状态** — `iaura status`
4. **调试** — `make debug` 前台启动看实时日志

---

## 🔮 下一步

- 根据播放状态智能判断暂停/恢复（当前为切换键）
- 更多内置音色
- 音量 / 语速调节
- Windows / Linux 支持

---

## 👤 作者

飞哥 ([xdfnet](https://github.com/xdfnet))

## 📄 许可

MIT
