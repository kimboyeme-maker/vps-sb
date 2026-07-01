# sb-deploy extension v1

Adds:

- `sb-profile`: region/use-case profile manager
- `sb-dns`: DNS policy manager, compiled by `sb-apply`
- `sb-doctor`: service/ports/firewall/nft/dns/network/upstream/export diagnostics
- `sb-backup`: snapshot/restore; `sb-apply` successful path auto-backups
- `sb-route`: custom route rule manager, compiled by `sb-apply`
- `sb-tune`: sysctl/journald/BBR/XanMod tuning planner and applier

Install:

```bash
tar -xzf sb-deploy-extension-v1.tar.gz
cd sb_ext
SB_ROOT=/opt/sb-deploy ./install.sh
```

After install:

```bash
sb-profile apply jp
sb-dns status
sb-route list
sb-doctor quick
sb-backup list
sb-tune check
sb-apply
```

Notes:

- `sb-dns` and `sb-route` only write intent files under `env/`; `sb-apply` compiles them before `sing-box check`.
- `sb-backup auto-apply-success` is patched into the successful end of `sb-apply`, so failed apply runs do not backup.
- `sb-tune bbrv3` / `sb-tune kernel xanmod` modify the system and may require reboot.
