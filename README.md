# JX2 (Võ Lâm 2 / 剑侠情缘网络版II) private server — build notes

Working repository for our JX2 private server: **deployment automation, audit findings and change history**.
Game binaries, maps and other third-party assets are **deliberately not stored here** — only our own scripts,
documentation and configuration templates.

## Current status (2026-11-02)

**Stack is running end-to-end on a CentOS Stream 9 VPS.** All components boot, Bishop registers the
gameserver (`protocol version 80-->80`), and the client-facing port (55795) is reachable.

| Component | Port(s) | State |
|---|---|---|
| Goddess (login / role server) | 5001, 6001 | running |
| Bishop (gateway, player entry) | 5632, 5633, **55795** | running |
| Relay (cross-map / chat / guild) | 5003, 5004, 5005 | running |
| GameServer 1 (Go + Lua) | 8886 | running |
| Paysys simulator (Wine container) | 8000 | running |

Not yet done: client package wiring, registration web panel, credential hardening, mobile.

## What we learned the hard way

The full list of blockers and their fixes is in [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md), but the short version:

1. DB password must be **exactly 32 chars** in the accepted charset — otherwise `Password Length Error`.
2. The old MySQL client in the C++ binaries uses the **socket** `/tmp/mysql.sock`, not TCP.
3. `lower_case_table_names=1` and matching `character-set-server` are **mandatory**.
4. Bishop **cannot start without paysys** — there is no disable switch.
5. Paysys speaks first (security-key handshake), so a passive stub can't fake it.
   `GamePaysys.exe` is itself a simulator (built by the package author) and needs **32-bit Wine**.
6. The game server is a modern **Go 1.14 binary with embedded Lua** → content work happens in
   `gs1/script/**.lua` + `gs1/settings/**`, no binary patching required.
7. Account passwords are **unsalted MD5** (`paysys.account.password`), `rowpass` = plaintext.

Details, credits and caveats: [`docs/AUDIT.md`](docs/AUDIT.md).
Chronological work log: [`docs/CHANGELOG.md`](docs/CHANGELOG.md).

## Layout

```
docs/AUDIT.md        audit of the server package (architecture, risks, leftovers)
docs/DEPLOYMENT.md   step-by-step runbook: bare CentOS Stream 9 -> running stack
docs/CHANGELOG.md    what we changed, in order
tools/deploy_setup.sh       extract + MySQL init + config patching
tools/deploy_services.sh    systemd units for the whole stack
tools/extract_gbk.py        extract tar with GBK (Chinese) filenames on UTF-8 filesystems
tools/paysys_stub.py        protocol capture stub (paysys handshake research)
tools/remote.template       ssh/scp helpers driven by env vars
configs/                    sanitized reference configs
```

## Quick start (on the VPS, as root)

```bash
export JX_EXT_IP=<your public ip>
export JX_DB_PASSWORD=<exactly 32 chars, [A-Za-z0-9_]>
export JX_TGZ=/root/sever2021Full.tgz      # server package, not in this repo

bash tools/deploy_setup.sh      # extract to /home/server, MySQL init, patch configs
bash tools/deploy_services.sh   # create systemd units, start the stack
systemctl status jx2-goddess jx2-bishop jx2-relay jx2-gs1
```

Then run the paysys simulator in a 32-bit Wine container (see `docs/DEPLOYMENT.md` §7) before starting Bishop.

## Constraints we work within

- **Legal**: the server files are leaked commercial software. Private, non-commercial, learning use only.
- **Security**: never reuse real passwords; the account hash format is crackable by design; the paysys DB
  must stay local-only; the gameserver port (8886) must not be exposed publicly.
- **RAM**: 3.6 GB box runs 1 game server comfortably; each extra GS needs roughly 0.5–1 GB.

## Roadmap

- [ ] Client package + first login (account `test` / `test123` already created)
- [ ] Registration / GM web panel (MD5 hash format confirmed, schema audited)
- [ ] Credential hardening: remove `skip-grant-tables`, single agreed DB password
- [ ] Close port 8886 externally
- [ ] Custom features (skills, events, chat, themed content) via the Lua script tree
- [ ] Mobile client research (no public JX2-mobile server files exist — long-term RE work)