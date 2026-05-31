# iAura 开发日志

## v1.1.1 — 2026-05-31

### 播放队列优化
- 新播报请求入队时自动丢弃队列中所有未开始的待播任务
- 正在合成/播放的不打断，播完自动切到最新一条
- 避免连续对话中旧回复堆积，始终优先播最新内容

### 媒体控制重构
- 从 `CGEvent` 系统媒体键改为调用 [iDict](https://github.com/xdfnet/iDict) HTTP API
- 移除 `entitlements.plist`，不再需要辅助功能权限
- 不再需要 Apple Development 证书签名
- `install.sh` 简化：跳过代码签名步骤

### 文档
- 更新 README、架构文档、CHANGELOG
- `install.sh` 移除过时的辅助功能权限提示

## v1.1.0 — 2026-05-29

### 安装简化
- Codex hook 不再修改 `~/.codex/config.toml`，首次触发时由 Codex 自动引导授权
- 移除旧版 Swift HookInstaller（逻辑迁入 Python 脚本）
- 清理 Installer 中的 `hashlib`/`re` 等已不需要的导入

### 文档
- 重构 README：从用户视角按命令分组，特性卡片 + shields.io 徽章
- 架构文档随代码同步更新
- 移除冗余的 release-notes 文件，内容已合并到 CHANGELOG
- 移除 Homebrew 安装方式说明

## v1.0.0 — 2026-05-29

### 正式发布
- 首个正式版本 v1.0.0
- GitHub Release + Git tag
- 发布说明：`docs/release-notes-v1.0.0.md`

### 媒体控制
- `MediaController`: CGEvent 系统媒体键，播报时自动暂停/恢复音乐
- 用 Apple Development 证书签名，辅助功能权限持久绑定
- Makefile 集成 `codesign` 步骤

### 播放队列
- `PlaybackQueue`: 竞态修复，尾递归重检查，防止处理期间新任务丢失
- 批量处理：while 循环替代递归 processNext
- 媒体控制集成：pause → 播放 → resume

### 安装脚本
- `install.sh`: 一键编译+签名+部署+初始化

### 文档
- README: shields.io 徽章 + 特性卡片 + 用户视角介绍
- `docs/release-notes-v1.0.0.md` 发布说明
- `docs/architecture.md` 更新：媒体控制、尾递归、部署结构
- `docs/CHANGELOG.md` 本日志

---

## 2026-05-29（开发期）

### 基础建设
- 修复 `setup` 时 `JSONSerialization` 写入 `\/` 的问题
- 模板 `config.example.json` 与运行配置对齐
- `hook-speak.sh` 从 90 行 Node.js 精简到 31 行 bash + python3
- `iaura.ts` Pi 扩展改为走 `iaura speak --source pi`，不再直连 socket
- Claude Code / Codex / Pi 三个工具统一走 `iaura speak --source`

### 参数链路
- `SpeakCommand`: `--voice` 参数修复，拼入 `{source:xxx,voice:yyy}` payload
- `ConnectionHandler.extractVoicePrefix`: 键值对解析，优先级 显式 voice > sourceVoices > defaultVoice

### 音频引擎
- `AudioPlayer` 重写：串行队列解决 AVAudioEngine 多 actor SIGSEGV
- `drain()` 改用 `scheduleBuffer` 完成回调 + 轮询等待，消除播放切尾
- 初始化保护：`initError` 状态 + `isStarted` 检查

### 流式合成
- `TTSEngine.synthesizeStream()`: `AsyncThrowingStream<Data>` 替换批量返回
- 重试机制：TTS 合成失败自动重试 2 次，每次间隔 500ms

### 模型预热
- `TTSEngine.warmup()`: daemon 启动后预热 GPU pipeline
- `Daemon.run()`: `loadModel()` 后立即 `await engine.warmup(voiceID:)`

### 新命令
- `iaura status` — socket 连接检查
- `iaura version` — v1.0.0
- `iaura restart` — launchd kickstart
- `iaura voice list` — 读 config 列出音色
- `iaura voice add` — 添加自定义音色
- `iaura voice remove` — 删除音色
- `iaura model pull` — 从 ModelScope 克隆 Qwen3-TTS 模型

### 运维
- 日志轮转：`daemon.log` 超过 5MB 自动归档 `.old`
- `saveConfig()` 公共 API，`\/` 自动清理
- `VoiceInfo` memberwise init

### 工程
- Git 初始化（main 分支），`.gitignore`
- Makefile: `build` / `debug` / `install` / `restart` / `clean`
- launchd plist 模板补完日志路径 + HOME 环境变量
- `installRuntimeArtifacts` 路径改为 `.build/release`
- 部署结构全部在 `~` 下，删项目无影响
