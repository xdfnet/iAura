# iAura 开发日志

## 2026-05-29

### 基础建设
- 修复 `setup` 时 `JSONSerialization` 写入 `\/` 的问题
- 模板 `config.example.json` 与运行配置对齐
- `hook-speak.sh` 从 90 行 Node.js 精简到 31 行 bash + python3
- `iaura.ts` Pi 扩展改为走 `iaura speak --source pi`，不再直连 socket
- Claude Code / Codex / Pi 三个工具统一走 `iaura speak --source`

### 参数链路
- `SpeakCommand`: `--voice` 参数之前被声明但未使用，修复后拼入 `{source:xxx,voice:yyy}` payload
- `ConnectionHandler.extractVoicePrefix`: 键值对解析，优先级 显式 voice > sourceVoices > defaultVoice

### 音频引擎
- `AudioPlayer` 重写：串行队列解决 AVAudioEngine 多 actor SIGSEGV
- `drain()` 改用 `scheduleBuffer` 完成回调 + 轮询等待，替换估算 `Task.sleep`，消除播放切尾
- 初始化保护：`initError` 状态 + `isStarted` 检查

### 流式合成
- `TTSEngine.synthesizeStream()`: `AsyncThrowingStream<Data>` 替换批量返回
- `PlaybackQueue.processNext()`: `for try await pcm in stream` 边合成边写入
- 重试机制：TTS 合成失败自动重试 2 次，每次间隔 500ms

### 模型预热
- `TTSEngine.warmup()`: daemon 启动后用默认音色跑一次 TTS，预热 GPU pipeline
- `Daemon.run()`: `loadModel()` 后立即 `await engine.warmup(voiceID:)`

### 新命令
- `iaura status` — socket 连接检查
- `iaura version` — v1.0.0
- `iaura restart` — launchd kickstart
- `iaura voice list` — 读 config 列出音色
- `iaura voice add` — 添加自定义音色（自动复制参考音频）
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

### 文档
- README 更新 CLI 表、开发命令、部署结构
- `docs/architecture.md` 数据流图、模块职责
- `docs/CHANGELOG.md` 开发日志
