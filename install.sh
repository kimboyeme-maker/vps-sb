#!/usr/bin/env bash
set -euo pipefail
SB_ROOT="${SB_ROOT:-/opt/sb-deploy}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SB_ROOT/bin" "$SB_ROOT/env" "$SB_ROOT/backups"
install -m 755 "$SRC_DIR/bin/sb-profile" "$SB_ROOT/bin/sb-profile"
install -m 755 "$SRC_DIR/bin/sb-dns" "$SB_ROOT/bin/sb-dns"
install -m 755 "$SRC_DIR/bin/sb-doctor" "$SB_ROOT/bin/sb-doctor"
install -m 755 "$SRC_DIR/bin/sb-backup" "$SB_ROOT/bin/sb-backup"
install -m 755 "$SRC_DIR/bin/sb-route" "$SB_ROOT/bin/sb-route"
install -m 755 "$SRC_DIR/bin/sb-tune" "$SB_ROOT/bin/sb-tune"

# Optional PATH symlinks.
if [[ -d /usr/local/bin && -w /usr/local/bin ]]; then
  for x in sb-profile sb-dns sb-doctor sb-backup sb-route sb-tune; do
    ln -sf "$SB_ROOT/bin/$x" "/usr/local/bin/$x"
  done
fi

APPLY="$SB_ROOT/bin/sb-apply"
if [[ -f "$APPLY" ]]; then
  python3 - "$APPLY" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
# Keep nftables local-port redirect semantics.
s = s.replace('dnat to ":${HY2_RANGE_PORT}"', 'redirect to ":${HY2_RANGE_PORT}"')
s = s.replace('HY2 range nftables dnat 对账', 'HY2 range nftables redirect 对账')
s = s.replace('nftables HY2 range dnat 已应用', 'nftables HY2 range redirect 已应用')
# Compile hooks before sing-box check.
marker = 'dbg "语法校验（过了才落盘）"'
hook = '''# sb-extension compile hook: dns/route\nif [[ -x "$SB_ROOT/bin/sb-dns" ]]; then\n  "$SB_ROOT/bin/sb-dns" compile "$TMP2"\nfi\nif [[ -x "$SB_ROOT/bin/sb-route" ]]; then\n  "$SB_ROOT/bin/sb-route" compile "$TMP2"\nfi\n\n'''
if 'sb-extension compile hook: dns/route' not in s:
    if marker not in s:
        raise SystemExit('FAIL: cannot find sing-box check marker in sb-apply')
    s = s.replace(marker, hook + marker)
# Backup hook before temp cleanup, reached only on successful path.
cleanup = 'rm -f "$TMP" "$TMP2" /tmp/sb-check.log'
bhook = '''# sb-extension backup hook: apply-success only\nif [[ -x "$SB_ROOT/bin/sb-backup" ]]; then\n  "$SB_ROOT/bin/sb-backup" auto-apply-success >/dev/null || log "WARN: 自动备份失败"\nfi\n\n'''
if 'sb-extension backup hook: apply-success only' not in s:
    if cleanup not in s:
        raise SystemExit('FAIL: cannot find cleanup marker in sb-apply')
    s = s.replace(cleanup, bhook + cleanup)
p.write_text(s)
PY
  chmod +x "$APPLY"
  bash -n "$APPLY"
  echo "OK: patched $APPLY"
else
  echo "WARN: $APPLY not found; installed commands only. Re-run install after sb-apply exists."
fi

for x in sb-profile sb-dns sb-doctor sb-backup sb-route sb-tune; do
  bash -n "$SB_ROOT/bin/$x"
done

echo "OK: installed sb extension commands into $SB_ROOT/bin"
