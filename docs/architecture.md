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
│                  PlaybackQueue (actor)                      │
│                    ┌─────┴─────┐                            │
│                    │ MediaController│  ← CGEvent 媒体键      │
│                    │  pause/resume │    暂停/恢复音乐       │
│                    └─────┬─────┘                            │
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
| `EntryPoint` | `Sources/iAura/EntryPoint.swift` | CLI 入口，注册 9 个子命令 |
| `Commands/` | `Sources/iAura/Commands/` | speak / serve / stop / restart / status / version / voice / model / setup |
| `Daemon/` | `Sources/iAura/Daemon/Daemon.swift` | 守护进程：加载模型 → 预热 → 监听 Socket |
| `Network/` | `Sources/iAura/Network/` | Unix Socket 服务器 + ConnectionHandler |
| `Audio/` | `Sources/iAura/Audio/` | AudioPlayer + PlaybackQueue + MediaController |
| `TTS/` | `Sources/iAura/TTS/TTSEngine.swift` | MLX TTS 流式推理，AsyncThrowingStream<Data>，内置重试 |
| `Hooks/` | `Sources/iAura/Hooks/HookInstaller.swift` | 安装 Claude / Codex / Pi Hook + trusted_hash |
| `Utilities/` | `Sources/iAura/Utilities/Logger.swift` | OSLog + 文件日志，5MB 自动轮转 |
| `iAuraKit/` | `Sources/iAuraKit/` | 共享库：Config、TextCleaner、AudioPipeline |

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
   - MediaController.pause() — CGEvent 模拟系统媒体键暂停音乐
5. TTSEngine.synthesizeStream() → AsyncThrowingStream<Data>
   - MLX GPU 推理，每 80ms 一个 float32 chunk
   - audioToPCM: 24k→48k 上采样 + float32→int16 转换
   - 失败自动重试 2 次
6. AudioPlayer.write(pcm) → serialQueue.sync { scheduleBuffer }
   - AVAudioPlayerNode.scheduleBuffer 流式播放
7. player.drain() — 轮询等待所有 buffer 播完
8. MediaController.resume() — 恢复音乐
9. processNext() 尾递归 — 处理期间新入队任务不丢失
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

## 媒体控制

```
PlaybackQueue.processNext()
  → MediaController.pause()  → CGEvent(NX_KEYTYPE_PLAY) 暂停音乐
  → TTS 合成 + 播放 ...
  → MediaController.resume() → CGEvent(NX_KEYTYPE_PLAY) 恢复音乐
```

通过 `CGEvent.post(tap: .cghidEventTap)` 注入系统媒体键，等效于键盘播放/暂停键。
需要 **辅助功能权限**，使用 Apple Development 证书签名后权限持久绑定。

## 日志

`~/.config/iaura/daemon.log`，超过 5MB 自动归档为 `.old`。

## 部署

所有运行时文件在 `~` 下：

```
~/.local/bin/iaura                          # CLI 入口
~/.local/share/iaura/runtime/iAura          # 二进制（签名）
~/.local/share/iaura/runtime/default.metallib # MLX Metal 库
~/.config/iaura/config.json                 # 配置
~/.config/iaura/voices/*.wav                # 参考音色
~/.config/iaura/hook-speak.sh               # Hook 脚本
~/.config/iaura/iaura.ts                    # Pi 扩展
~/Library/LaunchAgents/com.user.iaura.plist  # launchd 守护
```
