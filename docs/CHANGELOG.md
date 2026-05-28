# iAura 开发日志

## 2026-05-29

### 配置
- 修复 `setup` 时 `JSONSerialization` 写入 `\/` 的问题，`rewriteModelPath` 加 `replacingOccurrences` 清洗
- 模板 `config.example.json` 与运行配置对齐

### Hook 脚本
- `hook-speak.sh` 从 90 行 Node.js 精简到 31 行 bash + python3，去掉日志和 Node 依赖
- `iaura.ts` Pi 扩展改为走 `iaura speak --source pi`，不再直连 socket
- Claude Code / Codex / Pi 三个工具统一走 `iaura speak --source`

### 参数链路
- `SpeakCommand`: `--voice` 参数之前被声明但未使用，修复后拼入 `{source:xxx,voice:yyy}` payload
- `ConnectionHandler.extractVoicePrefix`: 改为键值对解析，优先级 显式 voice > sourceVoices > defaultVoice

### 音频
- `AudioPlayer` 重写：串行队列 `serialQueue.sync { scheduleBuffer }` 解决 AVAudioEngine 多 actor SIGSEGV
- `drain()` 改为 `async`，按帧数估算播放时长 + `Task.sleep`

### 流式合成
- `TTSEngine.synthesizeStream()`: `AsyncThrowingStream<Data>` 替换原来的 `[Data]` 批量返回
- `PlaybackQueue.processNext()`: `for try await pcm in stream` 边合成边写入

### 模型预热
- `TTSEngine.warmup()`: daemon 启动后用默认音色跑一次 TTS，预热 GPU pipeline
- `Daemon.run()`: `loadModel()` 后立即 `await engine.warmup(voiceID:)`

### CLI
- 新增 `status` 命令 —— 检查 socket 文件 + 连接测试
- 新增 `version` 命令 —— 版本号 1.0.0
- 新增 `restart` 命令 —— launchd kickstart
- `voice list` 补完实现，读 config 列出音色（标记默认）

### 工程
- Git 初始化（main 分支），添加 `.gitignore`，移除 `default.profraw`
- Makefile: `build` / `debug` / `install` / `restart` / `clean`
- launchd plist 模板补完 `StandardOutPath`、`StandardErrorPath`、`HOME`
- `installRuntimeArtifacts` 路径改为 `.build/release`（符号链接），不再硬编码 `arm64-apple-macosx`
- 部署结构全部在 `~` 下，删除项目目录无影响

### 文档
- README 更新 CLI 表、开发命令、部署结构
- docs/architecture.md 更新数据流图、模块职责、音色匹配优先级
