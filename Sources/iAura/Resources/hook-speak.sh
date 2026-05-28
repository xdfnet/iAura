#!/bin/bash
# iAura Hook — Claude Code / Codex Stop Hook
# 协议：stdout 必须保持干净；exit 0 = 继续，非 0 = 停止
[[ "${IAURA_SKIP:-}" == "1" ]] && exit 0
exec 1>/dev/null

SOURCE="${1:-claude}"
payload="$(cat)"

text=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
text = ''
for k in ['last_assistant_message', 'output_text', 'assistant_message']:
    v = d.get(k)
    if isinstance(v, str) and v.strip():
        text = v; break

if not text:
    msgs = d.get('messages', []) + d.get('conversation', [])
    for m in reversed(msgs):
        if not isinstance(m, dict) or m.get('role') != 'assistant':
            continue
        c = m.get('content', '')
        if isinstance(c, str):
            text = c
        elif isinstance(c, list):
            text = '\n'.join(
                b.get('text', '') for b in c
                if isinstance(b, dict) and b.get('type') == 'text'
            )
        if text.strip():
            break

print(text[:5000])
" "$payload" 2>/dev/null)

[[ -z "${text// }" ]] && exit 0
iaura speak --source "$SOURCE" "$text" 2>/dev/null &
exit 0
