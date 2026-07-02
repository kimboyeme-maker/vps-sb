# sb-deploy

Self-hosted sing-box VPS proxy toolchain: small, **self-locating** `sb-*` scripts driven by a single compiler (`sb-apply`) and one unified entry (`pi`).

## Tools

Core (13, symlinked to PATH by the installer):

| script                  | role                                                                                                                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `sb-genenv`             | one-time init: `node.env` + `users.json` + Hy2 cert (idempotent)                                                                                                                           |
| `sb-user`               | user management (add/del/list/set-egress); per-user uuid+password                                                                                                                          |
| `sb-outbound`           | landing outbound (socks/http/ss) + upstream toggle                                                                                                                                         |
| `sb-inbound`            | inbound CRUD (writes `env/inbounds.json`) + HY2 port hopping                                                                                                                               |
| `sb-dns`                | _(optional)_ server-side egress DNS policy (`env/dns.json`; default off, **no built-in DoH**)                                                                                              |
| `sb-route`              | _(optional)_ custom routing rules (`env/routes.json`; default off)                                                                                                                         |
| `sb-apply`              | **the only compiler**: envsubst → jq (users/inbounds/outbounds/dns/route/upstream) → `sing-box check` → restart → ufw reconcile. `sb-apply snapshot` also snapshots and keeps the last 10. |
| `sb-show` / `sb-export` | print share links / export subscriptions (base64 `.sub` + Clash `.yaml`)                                                                                                                   |
| `sb-backup`             | snapshot / rollback the whole deploy                                                                                                                                                       |
| `sb-doctor`             | read-only diagnostics                                                                                                                                                                      |
| `sb-clear`              | wipe `env/`+`certs/`+`out/` (debug)                                                                                                                                                        |
| `pi`                    | unified entry: `pi <sub> …` → `sb-<sub> …`                                                                                                                                                 |

Optional add-on: **`sb-tune`** — sysctl/journald/XanMod tuning (writes `/etc/sysctl.d/99-sb-tune.conf`; WARNs on keys that override your hand-tuned sysctl).

> `sb-profile` is intentionally **not** included — deferred until it can be a real multi-module strategy source (profile.json + dns.json + node.env + doctor/export policy), not a metadata label.

## Install

Scripts self-locate their root (via `readlink -f` on their own path), so you can install to any directory:

```bash
# default /opt/sb-deploy
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s --

# custom path
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s -- /srv/sb

```

The installer installs **only the toolchain**. Install system deps first: `sing-box`, `jq`, `gettext-base` (envsubst), `ufw`, `openssl`. Re-running the installer updates the scripts (idempotent; never touches `env/`).

## Usage

Core flow is always: **`install → genenv → configure → apply → export`**. Paths, aliases, and upstreams below are examples — adapt to your topology.

### For Japan VPS (transit / fast entry)

```bash
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s --

pi genenv
pi inbound set vless-in  listen_port <port>
pi inbound set hy2-in    listen_port <port>
pi inbound set socks5-in listen_port <port>

pi user add direct daily          # exits from JP local IP
pi user add direct stream

# optional: chain some users through the target landing node
pi outbound add <TARGET_TAG> socks <TARGET_IP> <port> <username> <password>
pi outbound inbound set vless-in,hy2-in
pi outbound enable <TARGET_TAG>
pi user set-egress stream upstream

pi apply snapshot
pi export
pi show txt
```

### For US VPS (landing / native US IP)

```bash
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s -- /srv/sb --with-tune

pi genenv
pi inbound set vless-in  listen_port <port>
pi inbound set hy2-in    listen_port <port>
pi inbound set socks5-in listen_port <port>

pi user add direct netflix        # native US IP (US streaming)
# residential landing instead:
#   pi outbound add res socks <RES_IP> <port> <u> <p>; pi outbound enable res; pi user set-egress netflix upstream

# optional HY2 UDP port hopping (China ISP QoS mitigation)
pi inbound hy2 range 1000         # 40500 ± 500 -> [40000,41000]
#   ★ also open 40000-41000/udp in your cloud security group

# optional per-user domain override: user defaults upstream, force openai direct
pi route enable
pi route add domain-suffix openai.com    direct --user netflix
pi route add domain-suffix anthropic.com direct --user netflix

# optional tuning (preview first; WARNs if it overrides your ch.4 sysctl)
sb-tune plan tiny && sb-tune apply tiny

pi apply snapshot
pi export
pi doctor quick
```

Subscriptions land in `<ROOT>/out/sub/`: `<alias>_<proto>.sub` (base64 subscription, for Karing/Shadowrocket) and `<alias>_<proto>.yaml` (for Clash Verge). HY2 port hopping only appears in the `.yaml`.

## Design notes

- **`sb-apply` is the single compiler.** Editors (`sb-inbound`/`sb-outbound`/`sb-dns`/`sb-route`) only write intent files under `env/`. No compile hooks, no patching of `sb-apply`.
- **Route order:** `sniff → ip_is_private reject → sb-route (hard override) → auth_user upstream → final direct`. So `sb-route` overrides a user's default egress; `--user`/`--inbound` scope rules, global rules WARN on creation. `geosite`/`geoip` are rejected (need rule_set; deferred to a future `sb-ruleset`).
- **DNS:** default has no DNS block. `sb-dns` is opt-in, no built-in DoH, uses sing-box 1.12+ typed servers (`server`+`path`, `domain_resolver` required for domain servers).
- **HY2 port hopping** uses nftables **`dnat`** (not `redirect`) — correct for `::`-bound inbounds on Debian 13 (see apernet/hysteria#1590).
- **Backups are opt-in:** `pi apply snapshot` (or `sb-backup create`), never on a failed apply.
