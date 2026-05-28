# iAura 架构

## 整体

```
┌─ Claude Code ──┐    ┌─ Codex ────────┐    ┌─ Pi ──────────┐
│ hook-speak.sh   │    │ hook-speak.sh  │    │ iaura.ts       │
│ bash ... claude │    │ bash ... codex │    │ iaura speak    │
└────┬────────────┘    └────┬───────────┘    └────┬───────────┘
     │                      │                      │
     └──────────────────────┼──────────────────────┘
                            │ iaura speak --source <name> <text>
                            ▼
                   Unix Socket (~/.config/iaura/iaura.sock)
                            │
                            ▼
┌───────────────────────────────────────────────────────────┐
│                   iAura Daemon (launchd)                   │
│                                                            │
│  SocketServer → ConnectionHandler                          │
│      解析 {source:claude,voice:wanwan}                      │
│      + TextCleaner 清洗 Markdown                           │
│                         │                                  │
│                         ▼                                  │
│                  PlaybackQueue (串行队列)                    │
│                         │                                  │
│              ┌──────────┴──────────┐                       │
│              ▼                     ▼                       │
│        TTSEngine              AudioPlayer                  │
│     synthesizeStream()      scheduleBuffer()               │
│     流式生成 PCM              流式播放                       │
│     (MLX GPU)               (AVAudioEngine)                 │
└───────────────────────────────────────────────────────────┘
```

## 模块

| 模块 | 路径 | 职责 |
|------|------|------|
| `EntryPoint` | `Sources/iAura/EntryPoint.swift` | CLI 入口，注册 8 个子命令 |
| `Commands/` | `Sources/iAura/Commands/` | speak/serve/stop/restart/status/version/voice/setup |
| `Daemon/` | `Sources/iAura/Daemon/Daemon.swift` | 守护进程：加载模型 → 监听 Socket |
| `Network/` | `Sources/iAura/Network/` | Unix Socket 服务器 + 连接处理 |
| `Audio/` | `Sources/iAura/Audio/` | AudioPlayer(串行队列 scheduleBuffer) + PlaybackQueue |
| `TTS/` | `Sources/iAura/TTS/TTSEngine.swift` | MLX TTS 流式推理，AsyncThrowingStream<Data> |
| `Hooks/` | `Sources/iAura/Hooks/HookInstaller.swift` | 安装 Claude/Codex/Pi Hook |
| `iAuraKit/` | `Sources/iAuraKit/` | 共享库：Config 加载、TextCleaner、AudioPipeline |

## 数据流

```
1. CLI: iaura speak -s codex "你好"
2. SpeakCommand 拼 {source:codex}你好 → Unix Socket
3. ConnectionHandler.handle()
   - 解 {source:codex} → source="codex"
   - 查 config.sourceVoices["codex"] → voiceID="wanwan"
   - if 有 {voice:xxx} → 显式覆盖
   - cleanText() 清洗 Markdown
4. PlaybackQueue.enqueue(job)
5. TTSEngine.synthesizeStream() → AsyncThrowingStream<Data>
   - MLX GPU 推理，每 80ms 一个 float32 chunk
   - audioToPCM: 24k→48k 上采样 + float32→int16 转换
6. AudioPlayer.write(pcm) → serialQueue.sync { scheduleBuffer }
   - AVAudioPlayerNode.scheduleBuffer 流式播放
7. player.drain() → await Task.sleep(估算时长 + 0.5s)
```

## 音色匹配

优先级：`显式 voice > sourceVoices 映射 > defaultVoice`

```
config.json:
  defaultVoice: "mizai"
  sourceVoices: { claude: "taozi", codex: "wanwan", pi: "dayi" }
  voices: [{ id, refAudio, refText }, ...]

ConnectionHandler.extractVoicePrefix():
  if {voice:xxx} in payload  → 直接用 xxx
  else if {source:s}         → sourceVoices[s] ?? defaultVoice
  else                       → defaultVoice
```
