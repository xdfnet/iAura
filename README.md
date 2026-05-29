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
./install.sh              # 编译 + 签名 + 部署，一条命令搞定
```

> 首次安装后去 **系统设置 → 隐私与安全性 → 辅助功能** 添加 iAura，  
> 播报时就能自动暂停音乐了（可选）。

## 使用

安装完成后，服务已经在后台运行，无需任何操作。AI 助手回复时会自动播报。

### 基本命令

```bash
iaura status              # 查看服务是否在跑
iaura version             # 版本信息
iaura speak "你好"         # 手动播报一段文本
iaura speak -s codex "文本" # 指定来源（匹配音色）
iaura speak -v dayi "文本"  # 指定音色
```

### 管理命令

```bash
iaura restart             # 重启服务
iaura stop                # 停止服务
iaura serve               # 前台启动（调试用）
```

### 音色

```bash
iaura voice list          # 列出所有音色
iaura voice add -i my -n "我的音色" --ref-audio voice.wav --ref-text "参考文本"
iaura voice remove my     # 删除音色
```

| 音色 ID | 名称 | 说明 |
|---------|------|------|
| mizai | 米仔 | 温暖自然，默认音色 |
| taozi | 甜妹桃子 | 活泼甜美，Claude 默认 |
| wanwan | 湾湾小何 | 温柔知性，Codex 默认 |
| dayi | 大易 | 沉稳可靠，Pi 默认 |

音色匹配规则：`显式指定 --voice` > `sourceVoices 映射` > `defaultVoice`

### 模型

```bash
iaura model pull          # 下载 Qwen3-TTS 模型（首次必做）
```

### Hook 集成

安装后自动接入三个 AI 工具：

- **Claude Code** → `~/.claude/settings.json` — Stop Hook
- **Codex** → `~/.codex/hooks.json` — Stop Hook（首次触发时授权即可）
- **Pi** → `~/.pi/agent/settings.json` — Extension 注册

Codex 用户注意：首次触发 Hook 时需要确认允许，之后自动生效。

## 开发

```bash
make build                # 编译 release
make debug                # 编译 + 前台启动（看日志）
make install              # 编译 + 签名 + 部署
make restart              # 重启 launchd 守护
make clean                # 清理 .build
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

部署文件全部在 `~` 下，删掉项目目录不影响运行。

## 依赖

- macOS 14 Sonoma+
- Apple Silicon (M1+)
- Swift 6 / Xcode 15+

## 许可

MIT
