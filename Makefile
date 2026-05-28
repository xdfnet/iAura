VERSION  := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")
COMMIT   := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

RUNTIME   := $(HOME)/.local/share/iaura/runtime
BIN       := $(RUNTIME)/iAura
METALLIB  := $(RUNTIME)/default.metallib
LAUNCHER  := $(HOME)/.local/bin/iaura
LABEL     := com.user.iaura

.PHONY: build debug install deploy restart clean

build:
	@echo 'enum BuildInfo {' > Sources/iAura/Commands/BuildInfo.swift
	@echo '    static let version = "$(VERSION)"' >> Sources/iAura/Commands/BuildInfo.swift
	@echo '    static let commit = "$(COMMIT)"' >> Sources/iAura/Commands/BuildInfo.swift
	@echo '}' >> Sources/iAura/Commands/BuildInfo.swift
	swift build -c release

debug: build
	@echo "● 前台启动 daemon（Ctrl-C 停止）"
	swift run -c release iaura serve

install: build
	@mkdir -p $(RUNTIME) $(HOME)/.local/bin
	cp .build/release/iAura $(BIN)
	cp .build/release/default.metallib $(METALLIB)
	chmod 755 $(BIN)
	@echo '#!/bin/bash'  > $(LAUNCHER)
	@echo 'exec "$(BIN)" "$$@"' >> $(LAUNCHER)
	chmod 755 $(LAUNCHER)
	@echo "✓ 已安装: $(BIN)"
	@echo "✓ launcher: $(LAUNCHER)"

restart:
	@launchctl kickstart -k gui/$$(id -u)/$(LABEL) 2>/dev/null && echo "✓ 已重启" || echo "✗ 未运行，请先 setup"

clean:
	@rm -rf .build
