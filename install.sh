#!/usr/bin/env bash
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

section() { echo -e "\n${BOLD}${CYAN}▸${RESET} ${BOLD}$1${RESET}"; }
ok()      { echo -e "  ${GREEN}✓${RESET} $1"; }
info()    { echo -e "  ${YELLOW}ℹ${RESET} $1"; }

echo -e "${BOLD}iAura 安装程序${RESET}"

# --- 1. 检查环境 ---
section "检查环境"

command -v swift >/dev/null 2>&1 || { echo "请先安装 Xcode 或 Swift 工具链"; exit 1; }
ok "Swift $(swift --version | head -1)"

if ! pgrep -q Music 2>/dev/null && ! pgrep -q Spotify 2>/dev/null; then
  info "未检测到 Music / Spotify 运行，媒体控制将跳过未运行的应用"
fi

# --- 2. 编译 ---
section "编译 (release 模式，约 1-2 分钟)"

cd "$(dirname "$0")"
make build
ok "编译完成"

# --- 3. 签名 ---
section "代码签名"

CERT=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | awk -F'"' '{print $2}' | tr -d '\n')

if [[ -z "$CERT" ]]; then
  info "未找到 Apple Development 证书，跳过签名"
  info "如需辅助功能权限（媒体键控制），请在 Xcode 中添加开发者账号后重装"
else
  codesign --force --sign "$CERT" --entitlements entitlements.plist .build/release/iAura 2>/dev/null || true
  ok "已签名: $CERT"
fi

# --- 4. 部署 ---
section "部署文件"

RUNTIME="${HOME}/.local/share/iaura/runtime"
mkdir -p "$RUNTIME" "${HOME}/.local/bin"
cp .build/release/iAura "$RUNTIME/iAura"
cp .build/release/default.metallib "$RUNTIME/default.metallib"
chmod 755 "$RUNTIME/iAura"

cat > "${HOME}/.local/bin/iaura" << 'LAUNCHER'
#!/bin/bash
exec "${HOME}/.local/share/iaura/runtime/iAura" "$@"
LAUNCHER
chmod 755 "${HOME}/.local/bin/iaura"
ok "已部署到 ~/.local"

# --- 5. 初始化 ---
section "初始化配置与守护"

"${HOME}/.local/bin/iaura" setup
ok "配置、Hook、launchd 已初始化"

# --- 6. 模型 ---
section "模型"
MODEL_DIR="${HOME}/.config/iaura/models/Qwen3-TTS-12Hz-1.7B-Base-8bit"
if [[ -d "$MODEL_DIR" ]]; then
  ok "模型已存在: $MODEL_DIR"
else
  info "模型未下载，运行以下命令获取："
  echo -e "    ${BOLD}iaura model pull${RESET}"
fi

# --- 完成 ---
echo ""
echo -e "${GREEN}${BOLD}✓ iAura 安装完成！${RESET}"
echo ""
echo "  辅助功能权限: 系统设置 → 隐私与安全性 → 辅助功能 → 添加 iAura"
echo "  (可选，用于播报时自动暂停音乐)"
echo ""
