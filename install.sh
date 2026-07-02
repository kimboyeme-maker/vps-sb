#!/usr/bin/env bash
set -euo pipefail

# sb-deploy 一键安装 / 更新（从 GitHub 拉取脚本）
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_sb/main/install.sh | bash -s -- [ROOT] [--with-tune] [--ref BRANCH]
# 例:
#   ... | bash -s --                      # 装到默认 /opt/sb-deploy
#   ... | bash -s -- /srv/sb              # 装到 /srv/sb

REPO="kimboyeme-maker/vps_proxy"
REF="main"
ROOT="/opt/sb-deploy"
CORE=(
  pi
  sb-apply
  sb-backup
  sb-clear
  sb-dns
  sb-doctor
  sb-export
  sb-genenv
  sb-user
  sb-inbound
  sb-outbound
  # sb-profile
  sb-route
  sb-show
  sb-tune
  sb-user
)

log(){ printf '[install] %s\n' "$*" >&2; }
die(){ printf '[install] FAIL: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) shift; REF="${1:-main}" ;;
    -*) die "未知参数 $1" ;;
    *) ROOT="$1" ;;
  esac
  shift
done

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "需要 root（要写 $ROOT 和 /usr/local/bin）"
command -v curl >/dev/null || die "缺 curl"

RAW="https://raw.githubusercontent.com/$REPO/$REF"
log "安装到 $ROOT (repo=$REPO ref=$REF)"

mkdir -p "$ROOT"/{bin,templates,env,certs,out}
mkdir -p /etc/sing-box
ln -sf "$ROOT/out/config.json" /etc/sing-box/config.json

fetch(){ curl -fsSL --retry 3 "$RAW/$1" -o "$2" || die "下载失败: $1"; }

for s in "${CORE[@]}"; do
  fetch "bin/$s" "$ROOT/bin/$s"; chmod +x "$ROOT/bin/$s"
  ln -sf "$ROOT/bin/$s" "/usr/local/bin/$s"
done

fetch "templates/config.json.tpl" "$ROOT/templates/config.json.tpl"
printf 'env/\ncerts/\nout/\nbackups/\n' > "$ROOT/.gitignore"

miss=""
for d in jq envsubst openssl sing-box ufw; do command -v "$d" >/dev/null || miss="$miss $d"; done
[[ -n "$miss" ]] && log "WARN: 缺依赖:$miss（sb-genenv/sb-apply 需要，请先按文档第 1、5 章装好）"

log "OK: 已装 ${#CORE[@]} , 核心脚本软链到 /usr/local/bin"
log "脚本自定位根目录（$ROOT），零 env 即用。下一步: pi genenv → pi user add ... → pi apply → pi export"
