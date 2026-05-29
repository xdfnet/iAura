.PHONY: all build deploy init model launchd uninstall sign run clean

RUNTIME    := $(HOME)/.local/share/iaura/runtime
BIN        := $(RUNTIME)/iAura
METALLIB   := $(RUNTIME)/default.metallib
LAUNCHER   := $(HOME)/.local/bin/iaura
LABEL      := com.user.iaura
PLIST      := $(HOME)/Library/LaunchAgents/com.user.iaura.plist
CONFIG     := $(HOME)/.config/iaura/config.json
VOICES_DIR := $(HOME)/.config/iaura/voices
MODEL_DIR  := $(HOME)/.config/iaura/models
HOOK_SH    := $(HOME)/.config/iaura/hook-speak.sh
IAURA_TS   := $(HOME)/.config/iaura/iaura.ts
LOG        := $(HOME)/.config/iaura/daemon.log
ENTITLEMENTS := entitlements.plist

# ─── 全流程 ──────────────────────────────────────────
all: init deploy model launchd
	@echo "✓  iAura 已就绪"

# ─── 第 1 层：无依赖，可并行 ────────────────────────
init:
	@mkdir -p $(HOME)/.config/iaura $(VOICES_DIR) $(MODEL_DIR)
	# config.json
	@if [ ! -f $(CONFIG) ]; then \
		cp Sources/iAura/Resources/config.example.json $(CONFIG); \
		sed -i '' 's|"~|"$(HOME)|g' $(CONFIG); \
		echo "✓  已生成配置: $(CONFIG)"; \
	else \
		echo "[i] 配置已存在: $(CONFIG)"; \
	fi
	# 音色
	@for f in ref_mizai.wav ref_taozi.wav ref_dayi.wav ref_wanwan.wav; do \
		if [ ! -f $(VOICES_DIR)/$$f ]; then \
			cp Sources/iAura/Resources/voices/$$f $(VOICES_DIR)/$$f; \
		fi; \
	done
	@echo "✓  音色文件: $(VOICES_DIR)"
	# hook 脚本
	@cp -n Sources/iAura/Resources/hook-speak.sh $(HOOK_SH) 2>/dev/null; [ -f $(HOOK_SH) ] || cp Sources/iAura/Resources/hook-speak.sh $(HOOK_SH)
	@chmod 755 $(HOOK_SH)
	@echo "✓  hook: $(HOOK_SH)"
	# Pi extension
	@cp -n Sources/iAura/Resources/iaura.ts $(IAURA_TS) 2>/dev/null; [ -f $(IAURA_TS) ] || cp Sources/iAura/Resources/iaura.ts $(IAURA_TS)
	@echo "✓  Pi extension: $(IAURA_TS)"
	# ── Hook 安装（已存在则跳过）──
	@python3 scripts/install-hooks.py "$(HOOK_SH)" "$(IAURA_TS)" 

# ─── 第 2 层：依赖 build ──────────────────────────
build:
	swift build -c release

deploy: build
	@mkdir -p $(RUNTIME) $(HOME)/.local/bin
	cp .build/release/iAura $(BIN)
	cp .build/release/default.metallib $(METALLIB)
	chmod 755 $(BIN)
	@printf '#!/bin/bash\nexec "%s" "$$@"\n' "$(BIN)" > $(LAUNCHER)
	chmod 755 $(LAUNCHER)

# ─── 第 3 层：下载模型 ─────────────────────────────
model:
	@if [ -d $(MODEL_DIR)/Qwen3-TTS-12Hz-1.7B-Base-8bit ]; then \
		echo "[i] 模型已存在"; \
	else \
		echo "[i] 下载模型..."; \
		git clone --depth 1 \
			https://www.modelscope.cn/models/mlx-community/Qwen3-TTS-12Hz-1.7B-Base-8bit.git \
			$(MODEL_DIR)/Qwen3-TTS-12Hz-1.7B-Base-8bit; \
	fi

# ─── 第 4 层：注册 + 启动 daemon ──────────────────
launchd:
	@{ echo '<?xml version="1.0" encoding="UTF-8"?>'; \
	   echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'; \
	   echo '<plist version="1.0"><dict>'; \
	   echo '  <key>Label</key><string>$(LABEL)</string>'; \
	   echo '  <key>ProgramArguments</key><array>'; \
	   echo '    <string>$(LAUNCHER)</string>'; \
	   echo '    <string>serve</string>'; \
	   echo '  </array>'; \
	   echo '  <key>WorkingDirectory</key><string>$(RUNTIME)</string>'; \
	   echo '  <key>RunAtLoad</key><true/>'; \
	   echo '  <key>KeepAlive</key><true/>'; \
	   echo '  <key>StandardOutPath</key><string>$(LOG)</string>'; \
	   echo '  <key>StandardErrorPath</key><string>$(LOG)</string>'; \
	   echo '  <key>EnvironmentVariables</key><dict>'; \
	   echo '    <key>HOME</key><string>$(HOME)</string>'; \
	   echo '  </dict>'; \
	   echo '</dict></plist>'; } > $(PLIST)
	-launchctl bootout gui/$(shell id -u)/$(LABEL) 2>/dev/null
	launchctl bootstrap gui/$(shell id -u) $(PLIST)
	@sleep 1
	launchctl kickstart -k gui/$(shell id -u)/$(LABEL)
	@echo "✓  守护进程已启动"

# ─── 辅助命令 ──────────────────────────────────────
install: all

uninstall:
	-launchctl bootout gui/$(shell id -u)/$(LABEL) 2>/dev/null
	@rm -f $(PLIST)
	@rm -rf $(RUNTIME)
	@rm -f $(LAUNCHER)
	@echo "✓  已卸载（保留 ~/.config/iaura/）"

run: deploy
	@echo "●  前台启动（Ctrl-C 停止）"
	.build/release/iAura serve

sign:
	@id="$(SIGN_ID)"; \
	if [ -z "$$id" ]; then \
		id=$$(security find-identity -v -p basic 2>/dev/null | grep -v REVOKED | grep -m1 '^ *[0-9]*)' | sed -E 's/^ *[0-9]+\) "(.+)".*/\1/'); \
	fi; \
	if [ -n "$$id" ]; then \
		codesign --force --sign "$$id" --entitlements $(ENTITLEMENTS) .build/release/iAura; \
		echo "✓  签名完成"; \
	else \
		echo "⚠️  未找到有效的签名身份"; \
	fi

clean:
	rm -rf .build

help:
	@echo "iAura 构建系统"
	@echo ""
	@echo "  make            = 全流程（init → build → deploy → model → launchd）"
	@echo "  make init       = 配置、音色、hook（第 1 层）"
	@echo "  make build      = 编译（第 2 层）"
	@echo "  make deploy     = 编译 + 部署文件（第 2 层）"
	@echo "  make model      = 下载模型（第 3 层）"
	@echo "  make launchd    = 注册自启 + 启动 daemon（第 4 层）"
	@echo "  make uninstall  = 停服务 + 删文件"
	@echo "  make run        = 前台调试"
	@echo "  make sign       = 签名"
	@echo "  make clean      = 删除 .build"
