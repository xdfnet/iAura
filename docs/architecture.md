# iAura 架构

iAura 是 macOS 本地语音播报守护进程，纯 Swift 实现。通过 mlx-audio-swift 做 TTS 推理，AVAudioEngine 原生播放，Unix Socket 接收播报请求。

## 整体数据流

```
Claude / Codex / Pi 完成事件
        │
        ▼
   hook 脚本 ──→ nc -U ~/.config/iaura/iaura.sock
        │
        ▼
   iAura (Swift) ────────────────────────────────────┐
   ├ SocketServer   Unix Socket 监听                  │
   ├ TextCleaner    清洗 Markdown / 代码 / 路径        │
   ├ PlaybackQueue  actor 串行队列                     │
   │                                                  │
   ├ TTSEngine                                          │
   │   ├ mlx-audio-swift 模型加载                      │
   │   ├ generateStream()  流式推理 (AsyncStream)      │
   │   └ AudioPipeline    24k→48k 上采样 + PCM 转换    │
   │                                                  │
   └ AudioPlayer                                      │
       └ AVAudioEngine → scheduleBuffer → 🔊          │
```

## 代码结构

```
Sources/
├── iAura/                    # 可执行目标
│   ├── EntryPoint.swift      # @main + ArgumentParser
│   ├── Commands/
│   │   ├── ServeCommand.swift    # 守护进程
│   │   ├── SpeakCommand.swift    # 一次性播报
│   │   ├── SetupCommand.swift    # 初始化
│   │   ├── VoiceCommand.swift    # 音色管理
│   │   └── StopCommand.swift     # 停止
│   ├── Daemon/
│   │   ├── Daemon.swift          # 生命周期/信号
│   │   └── LaunchAgent.swift     # plist 管理
│   ├── Config/
│   │   ├── Config.swift          # 加载/校验
│   │   └── ConfigModels.swift    # Codable 模型
│   ├── Network/
│   │   ├── SocketServer.swift    # Unix Socket + DispatchSource
│   │   └── ConnectionHandler.swift
│   ├── Audio/
│   │   ├── AudioPlayer.swift     # AVAudioEngine
│   │   └── PlaybackQueue.swift   # actor 队列
│   ├── TTS/
│   │   ├── TTSEngine.swift       # mlx-audio-swift 封装
│   │   └── ModelManager.swift    # 模型管理
│   ├── Text/
│   │   └── TextCleaner.swift     # 文本清洗
│   ├── Hooks/
│   │   └── HookInstaller.swift   # AI 工具集成
│   └── Resources/
│       ├── hook-speak.sh         # Hook 脚本
│       ├── hook-speak.js         # 文本提取
│       ├── com.user.iaura.plist  # LaunchAgent
│       └── config.example.json   # 示例配置
│
└── iAuraKit/                # 库目标（可测试）
    ├── Config.swift             # 配置模型
    ├── TextCleaner.swift        # 文本清洗
    └── AudioPipeline.swift      # 音频转换
```

## 并发模型

```
SocketServer (actor, DispatchSource)
    │  非阻塞 accept()
    ▼
ConnectionHandler (每个连接一个 Task)
    │  读取文本 → 解析 {source:...} → 入队
    ▼
PlaybackQueue (actor, 串行)
    │  AsyncStream 驱动，一次处理一个播报
    ▼
TTSEngine.generateStream()
    │  AsyncThrowingStream<[Float]>，流式产出音频
    ▼
AudioPlayer.write()
    │  scheduleBuffer 异步投喂，FIFO 排队播放
    ▼
AudioPlayer.drain()
    │  等所有 buffer 播完
```

**关键保证**：
- `PlaybackQueue` actor 确保一次只有一个播报在处理
- `AudioPlayer` 使用 `AVAudioPlayerNode.scheduleBuffer` 的 FIFO 特性保证顺序
- `SocketServer` actor 确保 socket 状态安全

## 播放端

AVAudioEngine 原生访问（无需 CGo）：

```swift
let engine = AVAudioEngine()
let node = AVAudioPlayerNode()
engine.attach(node)
engine.connect(node, to: engine.mainMixerNode, format: format)
engine.start()
node.play()

// 流式写入
node.scheduleBuffer(pcmBuffer)
```

## Hook 机制

iAura 通过 bash hook 脚本提取 `last_assistant_message`，再调用 `iaura speak` 发送给本地服务：

```
Claude Stop Hook → bash hook-speak.sh claude < payload.json
                 → 内联 Node 解析 JSON
                 → iaura speak --source claude "<text>"
                 → ~/.config/iaura/iaura.sock
```

## 配置

iAura 读取 `~/.config/iaura/config.json`。模型、音色、来源到音色的映射都从这个文件加载。

## 与 iVox 对比

| 维度 | iVox | iAura |
|------|------|-------|
| 语言 | Go + Python + C | Swift |
| 进程 | 2 (Go + Python) | 1 |
| TTS 推理 | Go→pipe→Python→MLX | Swift→mlx-audio-swift→MLX |
| 音频播放 | CGo→AVAudioEngine | AVAudioEngine 原生 |
| 并发 | goroutine + chan | actor + AsyncStream |
| 二进制 | Go ~10MB + venv | Swift ~3MB |
| 内存 | ~3.4GB | ~2.8GB |
| 依赖 | Go, Python, npm | Swift 6 + SPM |
| 分发 | npm | Homebrew / 直接下载 |

## 关键性能

| 指标 | 数值 |
|------|------|
| 启动（含模型预热） | ~2s |
| 首帧延迟 | ~300ms |
| 合成速度 | ~76ms/字 (模型限制) |
| 模型 | 8bit 量化，约 2.9GB |
| 常驻内存 | ~2.8GB |
