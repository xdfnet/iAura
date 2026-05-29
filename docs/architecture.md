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

## 命令体系

两个入口，职责分离。

### `make` — 构建 + 部署

```
make            = 全流程（日常用这条）
make init       = 配置 + 音色 + hook（第 1 层，幂等）
make build      = 编译（第 2 层）
make deploy     = 编译 + 部署 runtime 文件（第 2 层）
make model      = 下载 TTS 模型（第 3 层）
make launchd    = 注册自启 + 启动 daemon（第 4 层）
make uninstall  = 停服务 + 删文件
make run        = 前台调试
make sign       = 签名
make clean      = 删除 .build
```

全流程编排依赖关系：

```
init  ──→  deploy  ──→  model  ──→  launchd
(无依赖)  (依赖 build)  (依赖 config)  (依赖全部就绪)
```

### `iaura` — 运行时操作

```
iaura serve   = 启动 daemon（默认命令）
iaura speak   = 发送播报
iaura voice   = 音色管理
iaura stop    = 停止 daemon
iaura status  = 查看状态
iaura version = 版本信息
iaura restart = 重启 daemon
```

`iaura setup`、`iaura model` 已移除，由 `make` 替代。

### 日常使用

```bash
# 首次安装
git clone ... && cd iAura
make

# 改完代码后更新
make

# 卸载重装
make uninstall
make

# 运行时操作
iaura status
iaura speak "你好"
iaura voice list
```

## 模块

| 模块 | 路径 | 职责 |
|------|------|------|
| `EntryPoint` | `Sources/iAura/EntryPoint.swift` | CLI 入口，7 个子命令 |
| `Commands/` | `Sources/iAura/Commands/` | serve / speak / voice / stop / status / version / restart |
| `Daemon/` | `Sources/iAura/Daemon/Daemon.swift` | 守护进程：加载模型 → 预热 → 监听 Socket |
| `Network/` | `Sources/iAura/Network/` | Unix Socket 服务器 + ConnectionHandler |
| `Audio/` | `Sources/iAura/Audio/` | AudioPlayer + PlaybackQueue + MediaController |
| `TTS/` | `Sources/iAura/TTS/TTSEngine.swift` | MLX TTS 流式推理，内置重试 2 次 |
| `Utilities/` | `Sources/iAura/Utilities/Logger.swift` | OSLog + 文件日志，5MB 轮转 |
| `iAuraKit/` | `Sources/iAuraKit/` | 共享库：Config、TextCleaner、AudioPipeline |
| `scripts/` | `scripts/install-hooks.py` | 安装 hook 到 Claude / Codex / Pi |

`SetupCommand`、`ModelCommand`、`HookInstaller` 已移除，逻辑迁入 Makefile + `scripts/`。

## 数据流

```
1. CLI: iaura speak -s codex "你好"
2. SpeakCommand 拼 {source:codex}你好 → Unix Socket
3. ConnectionHandler.handle()
   - 解 {source:codex} → source="codex"
   - 查 config.sourceVoices["codex"] → voiceID="wanwan"
   - 显式 {voice:xxx} 可覆盖
   - cleanText() 清洗 Markdown
4. PlaybackQueue.enqueue(job)
   - MediaController.pause() — 暂停音乐
5. TTSEngine.synthesizeStream() → AsyncThrowingStream<Data>
   - MLX GPU 推理，每 80ms float32 chunk
   - audioToPCM: 24k→48k 上采样 + float32→int16
   - 失败自动重试 2 次，间隔 500ms
6. AudioPlayer.write(pcm) → scheduleBuffer 流式播放
7. player.drain() — 轮询等待 buffer 播完
8. MediaController.resume() — 恢复音乐
```

## 音色匹配

优先级：`显式 voice > sourceVoices 映射 > defaultVoice`

```
ConnectionHandler.extractVoicePrefix():
  if {voice:xxx} in payload  → 直接用 xxx
  else if {source:s}         → sourceVoices[s] ?? defaultVoice
  else                       → defaultVoice
```

## 媒体控制

`CGEvent.post(tap: .cghidEventTap)` 注入系统媒体键，等效键盘播放/暂停。
需要 **辅助功能权限**，Apple Development 证书签名后权限持久绑定。

## 日志

`~/.config/iaura/daemon.log`，超过 5MB 自动归档为 `.old`。

## 部署结构

所有运行时文件在 `~` 下，删除项目目录不影响运行：

```
~/.local/bin/iaura                          # CLI 入口
~/.local/share/iaura/runtime/iAura          # 二进制
~/.local/share/iaura/runtime/default.metallib # MLX Metal 库
~/.config/iaura/config.json                 # 配置
~/.config/iaura/voices/*.wav                # 参考音色
~/.config/iaura/hook-speak.sh               # Hook 脚本
~/.config/iaura/iaura.ts                    # Pi 扩展
~/.config/iaura/models/                     # TTS 模型
~/Library/LaunchAgents/com.user.iaura.plist  # launchd 守护
```

## Hook 集成

| 工具 | 配置文件 | 方式 |
|------|----------|------|
| Claude Code | `~/.claude/settings.json` | Stop → hook-speak.sh claude |
| Codex | `~/.codex/hooks.json` | Stop → hook-speak.sh codex（首次触发时授权即可） |
| Pi | `~/.pi/agent/settings.json` | Extension → iaura.ts → iaura speak --source pi |

由 `scripts/install-hooks.py` 统一安装，已存在则跳过。`make init` 幂等调用。
