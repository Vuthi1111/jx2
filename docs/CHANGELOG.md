# Changelog — from the beginning

## Phase 0 — direction

- Background: we already run a **JX1 mobile** private-server track.
- Decision: chase the **JX2 (PC + mobile)** trend instead — new private servers and official mobile ports
  (GOSU "JX2 Immortal", ADNX "JX2 Origin") are reviving the game. Long-term maintenance is not a priority.
- Key research finding: **no public JX2-mobile server files exist**. All JX2 mobile products are closed clients.
  The mobile JX2 share releases floating around RaGEZONE are JX1-mobile builds (21 sects) or incomplete
  (missing game DB). Conclusion: launch PC first, treat mobile as our own future client work.

## Phase 1 — acquiring a base package

Evaluated, in order:

| Candidate | Verdict |
|---|---|
| RaGEZONE one-click (2020, VMware/CentOS) | Wine-based quirks, dead links, Vietnamese client |
| CSDN one-click (`jxinstall.sh` from `kr.000028.xyz`) | **domain dead** (NXDOMAIN) — unusable, retroactively validates not using it |
| CN 2021-era one-clicks (7chaowan/rexuexia/0du.net) | alive but older generation, 5622/6660/8080 port family |
| **LoLi Team / EoPi "Server JX2 2021 Shiina"** | newest content generation (final official-era), native Linux, Go game server, **chosen** |

Package obtained: `sever2021Full.tgz` (531 MB, 94,777 files), tar'd from a live production server
(`per-file mtimes up to 2026-06`), path layout `/home/server`.

## Phase 2 — extraction + audit

- macOS APFS rejects the GBK-encoded Chinese filenames in the archive → wrote `tools/extract_gbk.py`
  (recovers raw bytes via surrogateescape, converts to UTF-8).
- Full audit (`docs/AUDIT.md` Part 1): component map, ports, 5 different plaintext credentials,
  leftover player PII, previous operator's public IP in `gs*/servercfg.ini`, encrypted license blobs
  (`main.loadLicense`/`MAC`-related symbols — flagged as the #1 risk).
- Architecture insight: the gameserver is a **Go 1.14 rewrite with embedded Lua** (Kingsoft internal
  modules `code.kingsoft.com/{crypto,guid,serialize}`), while Goddess/Bishop/Relay are 2005-era C++.
- Companion repo `Vuthi1111/jx2` created (empty until this commit).

## Phase 3 — VPS deployment (CentOS Stream 9)

Extract + import went clean. Then the fix chain, in order encountered:

1. `Password Length Error` — DB password must be **32 chars** exactly.
2. `Password Error` — the value must satisfy the config validator's charset; use `[A-Za-z0-9_]`.
3. Socket connection to `/tmp/mysql.sock` — symlinked to MariaDB's real socket.
4. `lower_case_table_names=1` required.
5. `character-set-server=utf8mb4` must match the DB charset.
6. **Bishop refuses to start without paysys** (no disable switch anywhere in the binary).
7. Protocol research: paysys **speaks first** (security-key handshake) — a passive stub captures nothing.
8. `GamePaysys.exe` turned out to be the package author's own **simulator** ("Copyright 2024 Thuong Wine
   Version 9.0.0.0") → intended to run under Wine all along.
9. EPEL `wine-8.0` is x86_64-only and cannot run the PE32 → **podman + 32-bit Wine image** runs it.
10. Daemon mode holds the SSH session → moved everything to **systemd units** (`tools/deploy_services.sh`).
11. Shipped start scripts (`startgs`/`nstart`/`bstart`) assume a different path layout — launched directly.

**Result: the full stack came up.** Bishop registered the gameserver:
`[GameServer 0] Connected ... open port = 8886, protocol version (80-->80) → === Start ===`.
Client port 55795 reachable externally. **License blobs did not block startup.**

## Phase 4 — accounts

- Cracked the credential format by matching the leftover operator row:
  `MD5("Thuong123") == aead1222…` → **`password` = unsalted MD5**, `rowpass` = plaintext.
- No need to reverse `GMPassGen.exe` for account creation; inserted a test account (`test` / `test123`).
- Consequence for the future registration panel: it writes MD5 rows into `paysys.account` — trivial.

## Open items

- [ ] Client package wiring + first real login
- [ ] Registration / GM web panel (build in-house; the CSDN installer that shipped one is dead)
- [ ] Credential hardening: remove `skip-grant-tables` (temporary workaround still active on the VPS)
- [ ] Close port 8886 to the internet
- [ ] Identify the 7 `_LoadTable NOT_SUPPORT` tables in Goddess
- [ ] Custom features via the Lua tree; mobile client research (long-term)