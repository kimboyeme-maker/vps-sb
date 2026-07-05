# VPS Proxy Toolkit

A self-hosted sing-box VPS proxy toolkit for VLESS Reality, Hysteria2, SOCKS5, optional upstream landing nodes, DNS policy, custom routes, subscriptions, backups, and diagnostics.

It is built around one rule: edit intent files through `pi ...`, then run `pi apply`. The generated `out/config.json` is compiled output and should not be hand-edited.

Key points:

- `pi` is the single user-facing entry. It forwards to the underlying `sb-*` scripts.
- `pi apply` is the only compiler: env/template + JSON intents -> checked sing-box config -> restart/firewall reconcile.
- Inbound tags live in `env/inbounds.json`; editors do not use the template or stale `out/config.json` as tag source.
- `.sub` exports are standard whole-file base64 subscriptions; `.yaml` exports are Clash/Mihomo compatible.
- `pi tune` is included as the required interactive new-machine prep/tuning tool.

## Install

Scripts self-locate their root (via `readlink -f` on their own path), so you can install to any directory:

```bash
# default

curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s --

# custom path
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s -- /srv/sb

```

The installer installs **only the toolchain**. Install system deps first: `sing-box`, `jq`, `gettext-base` (envsubst), `ufw`, `openssl`. Re-running the installer updates the scripts (idempotent; never touches `env/`).

## Command Map

Core flow is always: **install -> `pi tune bootstrap` -> `pi genenv` -> configure -> `pi apply` -> `pi export`**.

### `pi`

Unified entry point. `pi <subcommand> ...` forwards arguments to the matching `sb-*` tool.

| Command | Description | Affects |
| --- | --- | --- |
| `pi list` | List available subcommands. | Read-only |
| `pi help` | Show top-level help. | Read-only |
| `pi update` | Update toolkit scripts, template, and installer from the GitHub repo; leaves runtime state untouched. | `bin/`, `templates/`, `install.sh`, `/usr/local/bin` symlinks |

### `pi tune`

Required interactive VPS preparation and tuning: dependencies, certbot/certificates, sing-box, swap, sysctl/journald, XanMod/BBRv3.

| Command | Description | Affects |
| --- | --- | --- |
| `pi tune bootstrap` | Guided first-run setup; asks whether to install certbot and request a domain certificate. | System packages, certs, swap, sing-box, sysctl, journald, optional kernel |
| `pi tune check` | Read-only overall check. | Read-only |
| `pi tune preflight` | Inspect CPU/RAM/disk/IP/kernel basics. | Read-only |
| `pi tune recommend` | Recommend tuning profile. | Read-only |
| `pi tune reboot-needed` | Check whether reboot is recommended. | Read-only |
| `pi tune deps check` | Check required packages. | Read-only |
| `pi tune deps install` | Install required base packages. | System packages |
| `pi tune deps upgrade` | Run package upgrade flow. | System packages |
| `pi tune cert` | Interactive certbot certificate wizard; links `certs/cert.pem` and `certs/key.pem`, then writes HY2 `tls.server_name` to the issued domain. | sing-box service, certbot, `/etc/letsencrypt`, certbot deploy hook, `env/cert.json`, `certs/`, `env/inbounds.json`, optional `pi apply` |
| `pi tune cert check` | Check certbot, renewal task, deploy hook, cert links, and configured TLS paths. | Read-only |
| `pi tune cert install` | Install certbot only. | System packages |
| `pi tune cert renew-test` | Manually run `certbot renew --dry-run`; this temporarily stops sing-box. | sing-box service, certbot staging |
| `pi tune swap check` | Check swap state. | Read-only |
| `pi tune swap create 1G` | Create swap file. | System swap |
| `pi tune swap off` | Disable managed swap. | System swap |
| `pi tune singbox check` | Check sing-box availability. | Read-only |
| `pi tune singbox install` | Install sing-box. | System service/package |
| `pi tune singbox version` | Print sing-box version. | Read-only |
| `pi tune plan tiny` | Show sysctl/journald changes for a profile. | Read-only |
| `pi tune apply tiny` | Apply sysctl and journald profile. | `/etc/sysctl.d`, journald |
| `pi tune sysctl balanced` | Apply only sysctl profile. | `/etc/sysctl.d` |
| `pi tune journald tiny` | Apply only journald limits. | journald config |
| `pi tune bbrv3 auto` | Install/configure XanMod BBRv3 path. | Kernel/boot config |
| `pi tune kernel check-abi` | Check CPU ABI for XanMod. | Read-only |

### `pi genenv`

Initialize or upgrade local env files: `node.env`, `users.json`, `inbounds.json`, Hy2 certs, symlink, and `.gitignore`.

`genenv` also fills `NODE_COUNTRY` (used for subscription node naming) by
trying a chain of geoip lookups against the server's own egress IP; if all
sources fail it falls back to `unknown`. It never overwrites an existing
`NODE_COUNTRY` value — use `pi dns country <code>` to set or correct it
manually. `pi show`/`pi export` also retry the same geoip lookup on the fly
whenever `NODE_COUNTRY` is missing entirely (e.g. `env/node.env` predates
this feature); once genenv or `pi dns country` has written a value —
including `unknown` — it's trusted as-is and never re-queried.

| Command | Description | Affects |
| --- | --- | --- |
| `pi genenv` | Create missing env/cert files and defaults. | `env/`, `certs/`, symlink, `.gitignore` |
| `pi genenv upgrade` | Same idempotent upgrade path; fills new defaults without overwriting secrets. | `env/node.env`, `env/inbounds.json` |
| `pi genenv summary` | Show what genenv manages. | Read-only |

### `pi user`

Manage users and their egress mode. `direct` exits locally; `upstream` exits through enabled outbound.

| Command | Description | Affects |
| --- | --- | --- |
| `pi user list` | List accounts, egress, aliases, UUIDs. | Read-only |
| `pi user add direct netflix` | Add direct user with alias. | `env/users.json` |
| `pi user add upstream us-ai` | Add upstream user with alias. | `env/users.json` |
| `pi user del <account\|alias>` | Delete user by account or alias. | `env/users.json` |
| `pi user set-egress <account\|alias> direct` | Switch user to direct egress. | `env/users.json` |
| `pi user set-egress <account\|alias> upstream` | Switch user to upstream egress. | `env/users.json` |

### `pi inbound`

Manage inbound registry and overlays. Tag truth source is `env/inbounds.json`, not the template or compiled config.

| Command | Description | Affects |
| --- | --- | --- |
| `pi inbound list` | Show base tags, clones, patches, deleted tags, port policy, HY2 range. | Read-only, normalizes `env/inbounds.json` |
| `pi inbound show <tag>` | Show source/clone/patch/delete state for one inbound. | Read-only |
| `pi inbound set vless-in listen_port 40443` | Set inbound field by exact tag. | `env/inbounds.json` |
| `pi inbound set vless-in tag edge-vless` | Rename inbound tag and sync references. | `env/inbounds.json`, `env/node.env`, `env/routes.json` |
| `pi inbound set hy2-in up_mbps 80` | Set HY2 upstream bandwidth. | `env/inbounds.json` |
| `pi inbound set hy2-in obfs.password <pass>` | Patch nested inbound field. | `env/inbounds.json` |
| `pi inbound set hy2 obfs.type salamander` | Patch shared HY2 field by type selector. Type supports `vless`, `hy2`, `hysteria2`, `socks`, `socks5`; do not use multi-match type selectors for `listen_port`. | `env/inbounds.json` |
| `pi inbound set hy2 tls.certificate_path /srv/sb/certs/cert.pem` | Use the toolkit cert symlink for HY2 TLS. | `env/inbounds.json` |
| `pi inbound set hy2 tls.key_path /srv/sb/certs/key.pem` | Use the toolkit key symlink for HY2 TLS. | `env/inbounds.json` |
| `pi inbound rm hy2-in obfs` | Delete field in final config. | `env/inbounds.json` |
| `pi inbound reset hy2-in obfs` | Remove patch/delete intent for a field. | `env/inbounds.json` |
| `pi inbound clone hy2-in hy2-41500 41500` | Clone inbound with optional listen port. | `env/inbounds.json` |
| `pi inbound delete socks5-in` | Mark inbound deleted. | `env/inbounds.json` |
| `pi inbound restore socks5-in` | Restore deleted inbound. | `env/inbounds.json` |
| `pi inbound hy2 range 1000` | Enable HY2 UDP range around selected/default HY2 port. | `env/node.env` |
| `pi inbound hy2 range show` | Show HY2 range calculation. | Read-only |
| `pi inbound hy2 range off` | Disable HY2 range. | `env/node.env` |

### `pi outbound`

Manage landing outbounds, upstream settings, direct outbound patching, and upstream inbound scope.

Whenever the upstream host changes (`pi outbound upstream set host <HOST>` or
`pi outbound upstream set name <name>`), the upstream's own egress country is
auto-detected via geoip and cached as `UPSTREAM_REGION` in `env/node.env` —
this is separate from `NODE_COUNTRY` (the VPS's own country) and is used only
in subscription node naming (see `pi export`/`pi show` below).

| Command | Description | Affects |
| --- | --- | --- |
| `pi outbound list` | List custom outbounds; last column is each named outbound's `domain_strategy`. | Read-only, creates `out/outbounds.json` if missing |
| `pi outbound show <name>` | Show one outbound. | Read-only |
| `pi outbound add us socks <US_IP> 40080 <USER> <PASS>` | Add SOCKS5 outbound. | `out/outbounds.json` |
| `pi outbound add web http <HOST> <PORT> [USER] [PASS]` | Add HTTP outbound. | `out/outbounds.json` |
| `pi outbound add ss1 ss <HOST> <PORT> <METHOD> <PASSWORD>` | Add Shadowsocks outbound. | `out/outbounds.json` |
| `pi outbound set us domain_strategy ipv4_only` | Set a named outbound's domain strategy; visible in `pi outbound list`. | `out/outbounds.json` |
| `pi outbound reset us domain_strategy` | Clear a named outbound's domain strategy. | `out/outbounds.json` |
| `pi outbound del <name>` | Delete outbound. | `out/outbounds.json` |
| `pi outbound upstream show` | Show current upstream settings and available inbound tags. | Read-only |
| `pi outbound upstream set name us` | Enable configured outbound as upstream and copy host/port/auth into env. | `env/node.env` |
| `pi outbound upstream set enabled 0` | Disable upstream. | `env/node.env` |
| `pi outbound upstream set inbounds vless-in,hy2-in` | Replace upstream inbound scope. | `env/node.env` |
| `pi outbound upstream allow inbounds hy2-alt` | Append inbound to upstream scope. | `env/node.env` |
| `pi outbound upstream del-inbounds hy2-alt` | Remove inbound from upstream scope. | `env/node.env` |
| `pi outbound upstream clear inbounds` | Clear upstream inbound scope. | `env/node.env` |
| `pi outbound upstream set domain_strategy ipv4_only` | Set current upstream domain strategy; visible in `pi outbound upstream show`, not `pi outbound list`. | `env/node.env` |
| `pi outbound upstream set host <HOST>` | Configure temporary upstream host without named outbound. | `env/node.env` |
| `pi outbound upstream set port <PORT>` | Configure temporary upstream port without named outbound. | `env/node.env` |
| `pi outbound upstream set isp 0\|1` | Toggle the `-ISP` segment in upstream subscription node names (default `1`). Naming only, no `pi apply` needed. | `env/node.env` |
| `pi outbound direct show` | Show patch for built-in `direct` outbound. | Read-only |
| `pi outbound direct set resolver cloudflare prefer_ipv4` | Patch direct outbound `domain_resolver`. | `env/outbound-patch.json` |
| `pi outbound direct set domain_strategy ipv4_only` | Patch direct outbound domain strategy. | `env/outbound-patch.json` |
| `pi outbound direct rm resolver` | Remove direct outbound resolver patch. | `env/outbound-patch.json` |

### `pi dns`

Optional server-side egress DNS policy. Default is disabled and no built-in DoH is injected.

| Command | Description | Affects |
| --- | --- | --- |
| `pi dns status` | Show enabled/final/strategy summary. | Read-only, creates `env/dns.json` if missing |
| `pi dns show` | Print DNS intent JSON. | Read-only |
| `pi dns enable` | Enable DNS block compilation. | `env/dns.json` |
| `pi dns disable` | Disable DNS block compilation. | `env/dns.json` |
| `pi dns reset` | Reset DNS intent. | `env/dns.json` |
| `pi dns server list` | List DNS servers. | Read-only |
| `pi dns server add cloudflare https 1.1.1.1 443 /dns-query` | Add typed DNS server. | `env/dns.json` |
| `pi dns server add local local` | Add local resolver. | `env/dns.json` |
| `pi dns server show cloudflare` | Show DNS server. | Read-only |
| `pi dns server del cloudflare` | Delete DNS server. | `env/dns.json` |
| `pi dns domain list` | List managed domains stored in DNS overlay. | Read-only |
| `pi dns domain add example.com www.example.com` | Add managed domains for certificate/domain bookkeeping; no `pi apply` needed by itself. | `env/dns.json` |
| `pi dns domain show example.com` | Check whether a managed domain exists. | Read-only |
| `pi dns domain rm example.com www.example.com` | Remove one or more managed domains; no `pi apply` needed by itself. | `env/dns.json` |
| `pi dns domain del example.com www.example.com` | Alias of `pi dns domain rm`. | `env/dns.json` |
| `pi dns domain clear` | Clear managed domains. | `env/dns.json` |
| `pi dns final cloudflare` | Set DNS final server. | `env/dns.json` |
| `pi dns final off` | Clear DNS final. | `env/dns.json` |
| `pi dns strategy ipv4_only` | Set DNS strategy. | `env/dns.json` |
| `pi dns strategy off` | Clear DNS strategy. | `env/dns.json` |
| `pi dns route-default set server cloudflare` | Set `route.default_domain_resolver.server`. | `env/dns.json` |
| `pi dns route-default set strategy ipv4_only` | Set route default resolver strategy. | `env/dns.json` |
| `pi dns route-default rm server` | Remove route default server. | `env/dns.json` |
| `pi dns route-default off` | Clear route default resolver object. | `env/dns.json` |
| `pi dns country jp` | Set `NODE_COUNTRY` used for subscription node naming. | `env/node.env` |
| `pi dns country show` | Show current `NODE_COUNTRY`. | Read-only |
| `pi dns country off` | Reset `NODE_COUNTRY` to `unknown`. | `env/node.env` |

`pi dns country` writes `env/node.env` directly (not `env/dns.json`); no
`pi apply` needed, it only affects `pi show`/`pi export` node naming.

### `pi route`

Optional custom route rules. Use for scoped domain/IP overrides before or after upstream routing.
`--user` accepts the account from `pi user list` or its alias; it is resolved to the account name used by sing-box `auth_user`, not the UUID column.

| Command | Description | Affects |
| --- | --- | --- |
| `pi route enable` | Enable custom route compilation. | `env/routes.json` |
| `pi route disable` | Disable custom route compilation. | `env/routes.json` |
| `pi route position before-upstream` | Place outbound rules before auth_user upstream rules. | `env/routes.json` |
| `pi route position after-upstream` | Place outbound rules after auth_user upstream rules. | `env/routes.json` |
| `pi route add domain-suffix openai.com direct --user res-ai` | Add user-scoped outbound override. | `env/routes.json` |
| `pi route add domain-suffix netflix.com upstream --user hk` | Route scoped domain to upstream. | `env/routes.json` |
| `pi route add ip-cidr 1.1.1.0/24 direct` | Add IP CIDR route. | `env/routes.json` |
| `pi route add protocol dns action hijack-dns` | Add action rule. | `env/routes.json` |
| `pi route list` | List route rules. | Read-only |
| `pi route show` | Show route intent JSON. | Read-only |
| `pi route rm <index>` | Remove route by list index. | `env/routes.json` |
| `pi route reset` | Reset route intent. | `env/routes.json` |

### `pi apply`

The only compiler. It renders config, injects users/inbounds/outbounds/DNS/routes, runs `sing-box check`, restarts service, reconciles firewall and HY2 range.

| Command | Description | Affects |
| --- | --- | --- |
| `pi apply` | Compile and apply current intent files. | `out/config.json`, sing-box service, UFW, nftables |
| `pi apply snapshot` | Apply and create a successful-apply backup snapshot. | `out/config.json`, sing-box service, backups |

If `env/cert.json` exists or `env/dns.json.domains` is non-empty, `pi apply` keeps `80/tcp` in UFW so certbot HTTP renewal is not reclaimed by firewall cleanup.

### `pi export`

Export subscriptions from compiled `out/config.json`. Run `pi apply` first.

When `env/cert.json` or `env/dns.json.domains` records a managed domain,
`pi export` writes it to YAML `x-meta.domain`; `pi export node ...` delegates
to `pi show node ...` and includes the same `domain` field.

Every node is also emitted with a `domain`-addressed variant alongside the
`v4`/`v6` IP variants, so subscriptions carry `server: <domain>` entries in
addition to the IP ones. With no managed domain present, only the IP variants
are produced. Hysteria2 domain nodes use the real issued certificate, so they
get strict TLS verification (`insecure=0` / `skip-cert-verify: false`); the
IP nodes keep `insecure=1` since certificate SANs don't cover raw IPs.

Node names follow `<NODE_COUNTRY>-<proto-or-tag>[-v4|-v6]`, e.g. `jp-vless`,
`jp-vless-v4`/`jp-vless-v6`/`jp-vless` (bare = domain) when a domain exists.
If a protocol has more than one inbound (e.g. `hy2-in` and `hy2-alt`), the
inbound tag replaces the protocol name to disambiguate: `jp-hy2-in`,
`jp-hy2-alt`.

When a user's egress is `upstream` (see `pi user`/`pi outbound upstream`),
the name becomes `<NODE_COUNTRY>-<UPSTREAM_REGION>[-ISP]-<proto-or-tag>`,
e.g. `jp-us-ISP-vless` — `UPSTREAM_REGION` is the upstream proxy host's own
geoip'd country (not the VPS's), auto-detected and cached whenever
`sb-outbound upstream set host`/`name` changes it. The `-ISP` segment is
controlled by `pi outbound upstream set isp 0|1` (default `1`) and omitted
entirely when set to `0`.

`NODE_COUNTRY` is set in `env/node.env`; see `pi genenv` and `pi dns country`
below.

| Command | Description | Affects |
| --- | --- | --- |
| `pi export` | Export all protocols for all users. | `out/sub/` |
| `pi export all` | Same as default all-protocol export. | `out/sub/` |
| `pi export vless` | Export only VLESS nodes. | `out/sub/` |
| `pi export hy2` | Export only Hysteria2 nodes. | `out/sub/` |
| `pi export socks5` | Export only SOCKS5 nodes. | `out/sub/` |
| `pi export all transit` | Export all protocols for one account/alias. | `out/sub/` |
| `pi export hy2-in transit` | Export one inbound tag for one account/alias. | `out/sub/` |
| `pi export node hy2-in transit` | Print JSON nodes through `pi show node`. | Read-only |
| `pi export txt hy2-in transit` | Print plain links through `pi show txt`. | Read-only |

### `pi show`

Print share links or JSON node objects from compiled config.

When a managed domain exists, `pi show node ...` includes `domain` on the user
object and each node. HY2 `sni` comes from the compiled inbound
`tls.server_name`, with the managed certificate domain filled by `pi apply`
when no explicit SNI is set.

`pi show txt` groups links under a `# ── <user> · <proto> · <tag> ──` section
header, and — when a managed domain exists — emits a third domain-addressed
link per inbound next to the `v4`/`v6` ones. Node naming follows the same
scheme described under `pi export` above, including the
`<NODE_COUNTRY>-<UPSTREAM_REGION>[-ISP]-<proto-or-tag>` form for users whose
egress is `upstream`.

| Command | Description | Affects |
| --- | --- | --- |
| `pi show txt` | Print text share links. | Read-only |
| `pi show txt all transit` | Print all protocol links for one user. | Read-only |
| `pi show txt vless netflix` | Print VLESS links for one user. | Read-only |
| `pi show txt hy2-in netflix` | Print links for one inbound tag and one user. | Read-only |
| `pi show node all transit` | Print JSON node objects for one user. | Read-only |

### `pi doctor`

Read-only diagnostics for service, ports, firewall, certificates, nftables, DNS, network, upstream, and exports. `pi detect ...` is an alias of `pi doctor ...`.

| Command | Description | Affects |
| --- | --- | --- |
| `pi doctor quick` | Check service, ports, firewall, and certificates. | Read-only |
| `pi doctor all` | Run all diagnostic sections. | Read-only |
| `pi detect quick` | Alias of `pi doctor quick`. | Read-only |
| `pi doctor service` | Check sing-box service/config. | Read-only |
| `pi doctor ports` | Check inbounds and listening ports. | Read-only |
| `pi doctor firewall` | Show UFW state. | Read-only |
| `pi doctor cert` | Check certbot, renewal timer/cron, deploy hook, UFW 80/tcp, cert expiry/fingerprint, TLS paths, and client update advice. | Read-only |
| `pi doctor nft` | Show HY2 range nft table. | Read-only |
| `pi doctor dns` | Show DNS state. | Read-only |
| `pi doctor network` | Show network/public IP basics. | Read-only |
| `pi doctor upstream` | Check upstream env/reachability. | Read-only |
| `pi doctor export` | List subscription outputs. | Read-only |

### `pi backup`

Snapshot, inspect, diff, restore, and prune deploy state. Restore creates a pre-restore snapshot first.

| Command | Description | Affects |
| --- | --- | --- |
| `pi backup create` | Create manual backup. | `backups/` |
| `pi backup list` | List backups. | Read-only |
| `pi backup show <id>` | Show backup manifest and files. | Read-only |
| `pi backup diff <id>` | Diff backup against current root. | Read-only |
| `pi backup restore <id>` | Restore backup after taking pre-restore backup. | `env/`, `certs/`, `templates/`, `bin/`, `out/` |
| `pi backup prune 20` | Keep newest 20 backups. | `backups/` |

### `pi clear`

Reset generated runtime state and managed sing-box config, useful when abandoning or rebuilding a VPS. It keeps the toolchain itself, so `pi update` and `pi genenv` remain available.

| Command | Description | Affects |
| --- | --- | --- |
| `pi clear` | Ask for confirmation, stop sing-box if running, clear runtime state, remove managed sing-box config symlink, and delete HY2 range nft table. | `env/`, `certs/`, `out/`, `backups/`, managed `/etc/sing-box/config.json`, `inet sb_hy2_range` |
| `pi clear --yes` | Same cleanup without interactive confirmation. | Same as above |

### `pi update`

Update installed toolkit code without touching node state.

| Command | Description | Affects |
| --- | --- | --- |
| `pi update` | Download latest scripts/template/installer from `kimboyeme-maker/vps_proxy` `main`, syntax-check scripts, then install. | `bin/`, `templates/`, `install.sh`, `/usr/local/bin` symlinks |
| `pi update --dry-run` | Download and syntax-check only. | Read-only except temp files |
| `pi update --ref <branch-or-tag>` | Update from a specific branch/tag. | `bin/`, `templates/`, `/usr/local/bin` symlinks |

## Deployment Examples

`pi inbound` and `pi outbound upstream set inbounds ...` validate inbound tags from `env/inbounds.json`, not from the template or stale compiled config. After `pi genenv`, you can safely edit inbound tags/ports before the first `pi apply`.

If JP/HK should relay to a US landing node, deploy the US node first, export the `transit` user's SOCKS5 parameters, then fill `<US_IP>`, `<US_TRANSIT_ACCOUNT>`, and `<US_TRANSIT_PASSWORD>` on the JP/HK node.

### Japan Direct

```bash
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s --

pi tune bootstrap
pi genenv
pi inbound set vless-in  listen_port 40443
pi inbound set hy2-in    listen_port 40500
pi inbound set socks5-in listen_port 40080
# Optional: pi inbound hy2 range <number> enables HY2 port hopping.

pi user add direct daily
pi user add direct jp-video

pi apply snapshot
pi doctor quick
pi export
pi show txt
```

### Hong Kong Direct

HK direct is for HK IP / Asia entry. Keep server-side DNS off by default unless you explicitly need it.

```bash
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s --

pi tune bootstrap
pi genenv
pi inbound set vless-in  listen_port 40443
pi inbound set hy2-in    listen_port 40500
pi inbound set socks5-in listen_port 40080
# Optional: pi inbound hy2 range <number> enables HY2 port hopping.
pi user add direct hk

# pi dns enable
# pi dns server add cloudflare https 1.1.1.1 443 /dns-query
# pi dns final cloudflare
# pi dns strategy ipv4_only
# pi dns route-default set server cloudflare

pi apply snapshot
pi doctor quick
pi export
```

### US West Direct

```bash
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s -- /srv/sb

pi tune bootstrap
pi genenv
pi inbound set vless-in  listen_port 40443
pi inbound set hy2-in    listen_port 40500
pi inbound set socks5-in listen_port 40080
# Optional: pi inbound hy2 range <number> enables HY2 port hopping.

pi user add direct netflix
pi user add direct openai
pi user add direct transit      # optional: for JP/HK relay back to this US node

pi apply snapshot
pi doctor quick
pi export
pi show txt transit
```

### Japan Relay, US Landing

```bash
# First deploy a US landing node and get the transit SOCKS5 account.
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s --

pi tune bootstrap
pi genenv
pi inbound set vless-in  listen_port 40443
pi inbound set hy2-in    listen_port 40500
pi inbound set socks5-in listen_port 40080
# Optional: pi inbound hy2 range <number> enables HY2 port hopping.

pi user add direct jp
pi user add upstream us-ai
pi outbound add us socks <US_IP> 40080 <US_TRANSIT_ACCOUNT> <US_TRANSIT_PASSWORD>
pi outbound upstream set inbounds vless-in,hy2-in
pi outbound upstream set name us

# Server-side DNS is recommended on JP/HK relay nodes.
pi dns enable
pi dns server add cloudflare https 1.1.1.1 443 /dns-query
pi dns final cloudflare
pi dns strategy prefer_ipv4
pi dns route-default set server cloudflare
pi dns route-default set strategy prefer_ipv4

# Scoped route policy for the US-landing user.
pi route enable
pi route add protocol dns action hijack-dns --user us-ai
pi route add network udp action hijack-dns port 53 --user us-ai
pi route add domain-suffix openai.com    upstream --user us-ai
pi route add domain-suffix anthropic.com upstream --user us-ai
pi route add domain-suffix netflix.com   upstream --user us-ai

pi apply snapshot
pi doctor quick
pi export
pi show txt us-ai
```

### Hong Kong Relay, US Landing

```bash
# First deploy a US landing node and get the transit SOCKS5 account.
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s --

pi tune bootstrap
pi genenv
pi inbound set vless-in  listen_port 40443
pi inbound set hy2-in    listen_port 40500
pi inbound set socks5-in listen_port 40080
# Optional: pi inbound hy2 range <number> enables HY2 port hopping.

pi user add direct hk
pi user add upstream us-ai
pi outbound add us socks <US_IP> 40080 <US_TRANSIT_ACCOUNT> <US_TRANSIT_PASSWORD>
pi outbound upstream set inbounds vless-in,hy2-in
pi outbound upstream set name us

# Server-side DNS is recommended on JP/HK relay nodes.
pi dns enable
pi dns server add cloudflare https 1.1.1.1 443 /dns-query
pi dns final cloudflare
pi dns strategy prefer_ipv4
pi dns route-default set server cloudflare
pi dns route-default set strategy prefer_ipv4

# Scoped route policy for the US-landing user.
pi route enable
pi route add protocol dns action hijack-dns --user us-ai
pi route add network udp action hijack-dns port 53 --user us-ai
pi route add domain-suffix openai.com    upstream --user us-ai
pi route add domain-suffix anthropic.com upstream --user us-ai
pi route add domain-suffix netflix.com   upstream --user us-ai

pi apply snapshot
pi doctor quick
pi export
pi show txt us-ai
```

### US West Direct, US Landing

This is the full US landing shape: direct US users, optional `transit` user for JP/HK relay, and optional residential SOCKS5 for selected users.

```bash
curl -fsSL https://raw.githubusercontent.com/kimboyeme-maker/vps_proxy/main/install.sh | bash -s -- /srv/sb

pi tune bootstrap
pi genenv
pi inbound set vless-in  listen_port 40443
pi inbound set hy2-in    listen_port 40500
pi inbound set socks5-in listen_port 40080
# Optional: pi inbound hy2 range <number> enables HY2 port hopping.

pi user add direct netflix
pi user add direct openai
pi user add direct transit

pi user add upstream res-ai
pi outbound add res socks <RES_IP> <RES_PORT> <RES_USER> <RES_PASS>
pi outbound upstream set inbounds vless-in,hy2-in
pi outbound upstream set name res

# Optional: enable server-side DNS only if the residential upstream workflow needs it.
# pi dns enable
# pi dns server add cloudflare https 1.1.1.1 443 /dns-query
# pi dns final cloudflare
# pi dns strategy ipv4_only
# pi dns route-default set server cloudflare
# pi dns route-default set strategy ipv4_only

pi route enable
pi route add domain-suffix openai.com    direct --user res-ai
pi route add domain-suffix anthropic.com direct --user res-ai

pi apply snapshot
pi doctor quick
pi export
pi show txt
pi show txt transit
```

Subscriptions land in `<ROOT>/out/sub/`:

- `<alias_or_account>_<proto>.sub`
  - standard base64 subscription
  - base64-encodes a newline-separated URI list
  - decoded lines start with `vless://`, `hysteria2://`, or `socks5://`

- `<alias_or_account>_<proto>.yaml`
  - Clash/Mihomo YAML
  - includes VLESS Reality options, HY2 obfs, and HY2 port hopping when enabled

Filename prefix priority:

1. `alias`
2. `name` / account
3. omitted prefix, resulting in `<proto>.sub` and `<proto>.yaml`

## Design notes

- **`sb-apply` is the single compiler.** Editors (`sb-inbound`/`sb-outbound`/`sb-dns`/`sb-route`) only write intent files under `env/`. No compile hooks, no patching of `sb-apply`.
- **Inbound tags live in `env/inbounds.json`.** `sb-inbound` validates tags only from this registry; it never uses the template as a source. `pi inbound set vless-in tag edge-vless` renames the registry and syncs references in `node.env` / `routes.json`; `sb-apply` renders the template with those tags.
- **Outbound upstream scope also uses the registry.** `pi outbound upstream set inbounds ...` validates against `env/inbounds.json`, not the template or a possibly stale compiled config.
- **Route order:** `sniff → ip_is_private reject → sb-route (hard override) → auth_user upstream → final direct`. So `sb-route` overrides a user's default egress; `--user`/`--inbound` scope rules, global rules WARN on creation. `geosite`/`geoip` are rejected (need rule_set; deferred to a future `sb-ruleset`).
- **DNS:** default has no DNS block. `sb-dns` is opt-in, no built-in DoH, uses sing-box 1.12+ typed servers (`server`+`path`, `domain_resolver` required for domain servers).
- **HY2 port hopping** uses nftables **`dnat`** (not `redirect`) — correct for `::`-bound inbounds on Debian 13
- **Backups are opt-in:** `pi apply snapshot` (or `pi backup create`), never on a failed apply.
