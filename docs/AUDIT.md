# Audit — sever2021Full.tgz (JX2 / Võ Lâm 2 "Shiina 2021" server package)

Audit date: 2026-11-01. Source archive: `~/Downloads/sever2021Full.tgz` (531 MB, 94,777 members).
Extracted to: `Learn/JX/server2021/` (GBK filenames converted to UTF-8 via `tools/extract_gbk.py`).
Companion repo: `github.com/Vuthi1111/jx2` — **empty**, nothing pushed yet.

## 1. Provenance

- Package was tar'd from a **live production server** at `/home/server/` (root-owned, sticky bits, `.pid` files, `BishopLiveTime.tm` dated Jun 2026, login logs 2024–2025).
- Operators identifiable from leftovers: **EoPi / LoLi Team ("Thuong")** — paysys user `ThuongEopi`, `remember_token='Thuong123'`, account `tinykidpro` (gmail, VN IP 125.235.233.160, DOB, phone); a second MySQL password (`Phong…[redacted]`) suggests the package passed through ≥2 operators.
- `script/cambodia/` + `abluemoon_*` configs indicate a market-specific commercial build (KH/VN scene, cf. "SabayKH" JX2 English).
- This matches the LoLi Team "Server JX2 2021 (Shiina)" release, packaged as **native Linux files** (not the Ubuntu VM image) — designed to live at `/home/server`.

## 2. Architecture map

| Component | Path | Binary | Type | Listen |
|---|---|---|---|---|
| Login/role server | `gw/Goddess/KG_GoddessD` | ELF64 x86-64 (2005-era C++, stripped) | native Linux | 5001 (bishop↔goddess), 6001 (role stats) |
| Gateway | `gw/Bishop/KG_BishopD` | ELF64 x86-64 | native Linux | 5632 (relay), 5633 (gameservers), **55795 (players/client)**, 5009 (appserver, disabled) |
| Cross-server relay | `gw/Relay/SO2RelayD` | ELF64 x86-64 | native Linux | internal, Bishop 5632 link |
| Game servers ×7 | `gs1..gs7/SO2GameSvrD{1..7}` | **Go 1.14 binary (~311 MB), embedded Lua VM** | native Linux | GS port 8886 (gs1), connects Bishop 5633, internal Transfer 5003 / Chat 5004 / Tong 5005 |
| Billing | `paysysvip/GamePaysys.exe` | **PE32 Windows** (msvcr80 era) | **needs Wine** | 8000 |
| MySQL | — | dumps in `databasesql/` | schema-only | 3306 local |

- gs2–gs7 are clones of gs1 (`ServerIndex=2..7`, `ServerType=1`; `settings/data/maps/script` symlinked to gs1 on the original box — symlinks preserved in tar).
- The gameserver is a **modern Go rewrite** with server logic in Lua: `gs1/script/**.lua` (NPCs, missions, events), `gs1/settings/**` (ini/txt data tables). This is the feature-development surface.
- Extra ops tooling: `gw/Goddess/KG_StatGameDataD` (rank server), `KGD_MySQLBackupD` (DB backup), `RoleImportToolD`, `kg_RoleAdminD`; `gw/Bishop/KG_BishopD send-msg-to-gs` CLI for broadcasts/maintenance (see `start/offline` script); `start/1,2,3,s1..s7` = boot order scripts.

## 3. Databases

- `databasesql/jx2ib_database.sql` — game DB, **clean schema, 0 rows**: role, tong (guild), fightteam, mailset, masterandprentice, playerrelation, player_treasure, sharedatabase, exceptionrole, invite_code_1816.
- `databasesql/jx2ib_database_log.sql` — common_log, clean.
- `databasesql/paysys.sql` — billing/admin backend (766 lines): account, admin, admin_panel, agency, card_log, charge_log, deposits, gift_code(s), packages, login_log. **Has 3 leftover INSERTs** (real account `tinykidpro` with PII; admins `admin`/`dyadmin` with MD5 hashes; coin packages).
- Goddess DB creds in `KG_Goddess.ini`: `root / sCOE…[32 chars, redacted]` (plaintext). Paysys DB creds in `paysys.ini`: `root / Phong…[redacted]`.

## 4. Configuration state

- All listen IPs are `127.0.0.1`/`0.0.0.0` (offline posture) **except** `gs1..7/servercfg.ini: ExternalIP=38.54.93.188` — previous operator's public VPS. `servercfg_goc.ini` (backup copies) reference old LAN `192.168.1.150`.
- `bishop.ini` [Paysys] contains operator account `ThuongEopi / ****`.
- Server requires locale **`LANG=zh_CN.gbk`** (set in start scripts) — GBK data/script filenames.
- Ports differ from the CSDN one-click tutorial (5622/6660/8080): this build's client-facing port is **55795** (bishop.ini [Player]); no 8080 registration web is included in the tarball.
- `MaxPlayers=50` in bishop.ini [Player] (raise for launch), gs servercfg `MaxPlayer=1500`.

## 5. Risks & blockers (ordered)

1. **License blobs**: `gs1/license` + `gs1/licenese` (encrypted, 416 B) and `verify_up2date` binary in gw/gs dirs. The Go gameserver likely validates a license — possibly bound to the old IP/machine. **Unknown until first boot.** Fallback: ask LoLi/EoPi (they support business setups), or test whether `verify_up2date` enforcement is soft.
2. **Missing registration/GM web panel** (the `:8080` Laravel-style app from the CSDN flow — `packages`/`remember_token` tables confirm paysys DB backs a web app). Must be obtained from LoLi's package or the CN one-click ecosystem; alternatively build a minimal reg page against the `paysys.account` table.
3. **Paysys is Windows PE32** → Wine required on Linux (or stub it: bishop.ini [Paysys] has result flags that can be hardcoded; billing only matters for card/coin sales).
4. **Leftover operator data**: real user PII + admin hashes + old public IP + login logs. Purge before any public deploy (privacy + hygiene + your own security).
5. **Go 1.14-era binary, stripped**: no source. Feature work is Lua/config-level unless you RE the binary. Fine for content features; a hard ceiling for protocol-level changes (relevant to the mobile bridge later).
6. Old C++ gateways: expect CentOS-7-era glibc; runs on x86_64 Linux ≥2.6.18 ABI — fine on CentOS 7.9 / Rocky 8, verify on modern Ubuntu.
7. No malware indicators found in configs/scripts (external URL grep: only loopback + old LAN IPs), but binaries are stripped and unverified — treat as untrusted until booted in an isolated environment (VM first, not the shared VPS).

## 6. Deploy checklist (VPS, CentOS 7.9 x86_64, 4 GB+)

1. `rm` leftovers: `**/*.pid`, `BishopLiveTime.tm`, `gs*/dulieu/login_logs/*`, `gs*/logs/*`, `_GAMESVR_LOG_`, `startlog/`.
2. Purge paysys.sql INSERTs (keep schema; recreate your own admin with fresh hash via `GMPassGen.exe`).
3. Set new MySQL root password; update `KG_Goddess.ini`, `paysys.ini`; import `jx2ib_database*.sql` + `paysys.sql` with `log-bin-trust-function-creators=1`.
4. Extract tree to `/home/server` (path is hardcoded in start scripts + gs symlinks). Install `zh_CN.gbk` locale, `libaio`, 32-bit Wine for paysys (or disable paysys).
5. Replace `ExternalIP=38.54.93.188` with your VPS IP in all 7 `servercfg.ini`; set bishop.ini player-facing IPs; firewall: open **55795/tcp** (client), 8080 (reg web, once obtained); keep 3306/5001/5632/5633/8886/8000 internal.
6. Client: `settings/glsver_list` + `server_jxae` → `GameIPAddress=<your IP>` (client package not in this tarball — separate download).
7. Boot order: MySQL → Goddess → Bishop → Relay → paysys (optional) → gs1..7; verify with `netstat -tnlp`.

## 7. Feature-dev surface (for your custom content)

- **Lua**: `gs1/script/` — missions (`missions/wantedboss`), events (`biwudahui` = martial tourney, `caiji` = gathering), VIP feedback system (`settings/static_script/vip_feedback_system/vfs_main.lua`), tong/guild extensions (`script/isolate/functions/tong_extension/`), region dirs incl. `cambodia/`.
- **Data tables**: `gs1/settings/` — items/shops (`buysell.txt`), chat control (`chatctrl.ini`), anti-cheat (`antibot_config.ini`, `antiplugin_config.ini`, `anti_enthrallment.ini`, `abluemoon_anticheaf.txt`), boss settings (`settings/npc/boss_setting/*.ini`), battle maps (`settings/battles/maps/yanmenguan/`).
- **DB-backed**: guild war (`_TongCityWar`), rankings (`_PlayerBattleRank*`), shared KV (`sharedatabase` + Goddess `ShareDBConfig.txt`).
- Hot-reload: GS reads Lua at runtime (typical for this stack) — test per script.

## 8. Next actions

1. Obtain: client package matching this server + registration web panel (from LoLi Drive/EoPi contact or CN ecosystem).
2. Trial boot in a local x86 Linux VM (UTM/QEMU) — verifies the license question cheaply before touching the VPS.
3. Push your custom-feature work to `github.com/Vuthi1111/jx2` (currently empty) — keep scripts/configs under version control from day one; I can review diffs there.

## 9. CSDN one-click status (checked 2026-11-01)

- `kr.000028.xyz/jxinstall.sh` → **NXDOMAIN** (domain dead; parent + www too). No public mirror found.
- The CSDN route is unusable; the tgz (this package) is the base. Its unique missing piece — the :8080 registration/GM web panel — must come from EoPi/LoLi or be built in-house against the `paysys.account` schema (hash format to be reversed from `GMPassGen.exe`).
- Related CN builds (黑鹰/Black Eagle VM, ports 32489/6666, client `server_list.ini`) share the same lineage; this Go-GS build is the most modern variant.

---

# Part 2 — Live deployment log (VPS 130.94.6.220, 2026-11-01)

Host: CentOS Stream 9, 2 vCPU, 3.6 GB RAM, 50 GB, x86_64. Stack: **RUNNING**.

## Final service map (systemd units)

| Unit | Binary | Ports | Notes |
|---|---|---|---|
| `jx2-goddess` | gw/Goddess/KG_GoddessD | 5001, 6001 | MySQL client (embedded 5.5.50) |
| `jx2-bishop` | gw/Bishop/KG_BishopD | 5632, 5633, **55795 (public)** | requires paysys at login |
| `jx2-relay` | gw/Relay/SO2RelayD | 5003, 5004, 5005 (+63562 dyn) | |
| `jx2-gs1` | gs1/SO2GameSvrD1 | **8886** (0.0.0.0 — expose only internally) | Go 1.14 + Lua |
| `jx2-paysys` (podman) | paysysvip/GamePaysys.exe via Wine | 8000 | see below |

Boot order achieved: MariaDB → Goddess → paysys → Bishop → Relay → GS. Bishop log confirms:
`[GameServer 0] Connected ... internet address = 130.94.6.220, open port = 8886, protocol version (80-->80)` → `=== Start ===`.

## Gotchas solved (in order encountered)

1. **DB password length = 32 chars exactly.** `KG_Goddess:393 LoadConfig` → `PG_RESULTLENSTD "Password Length Error"` for a 20-char password.
2. **DB password content is validated**, not just length (`:395 "Password Error"`). Working value: keep the original 32-char token style `[A-Za-z0-9_]` (the shipped tokens work verbatim).
3. **Old client library connects via socket `/tmp/mysql.sock`**, not TCP → `ln -sf /var/lib/mysql/mysql.sock /tmp/mysql.sock`.
4. **`lower_case_table_names=1` required** — Goddess aborts with an explicit message otherwise.
5. **`character-set-server` must equal the DB charset** → set `utf8mb4` + `utf8mb4_unicode_ci` (dumps are utf8/utf8mb4; server default was latin1).
6. **Bishop refuses to start without paysys** (`KG_BishopPaySys.cpp:74 Init`). No disable switch exists.
7. **Paysys protocol is server-speaks-first** (security-key handshake) — a passive stub gets zero bytes. Must run the real component.
8. **`GamePaysys.exe` is itself a simulator** ("Copyright 2024 Thuong Wine Version 9.0.0.0", handlers `KG_SimulatePaysys::b2p_*`) — EoPi's own billing replacement. Intended to run under Wine.
9. **Wine 8.0 from EPEL is x86_64-only** and cannot run the 32-bit PE (`syswow64\rundll32.exe` missing). Solution: `podman run --network host -w /paysys -v /home/server/paysysvip:/paysys docker.io/scottyhardy/docker-wine wine GamePaysys.exe` (3.6 GB image, has wine32+wine64).
10. **`startgs`/`nstart`/`bstart` scripts are broken for this layout** (they derive the binary name from `/home/so2game/server<N>`); launch the binaries directly.
11. **Daemon mode processes hold the SSH channel open** → run under systemd (`Type=simple`) instead of `start --daemon`.
12. **License blobs did NOT block startup.** `main.loadLicense`/`CheckExpiredCycle` exist in the Go GS but the bundled 416-byte licenses were accepted on this IP/host. Risk downgraded, not eliminated (unknown expiry behaviour).

## Account creation — format cracked

`paysys.account.password` = **unsalted MD5(password)**, `rowpass` = plaintext.
Verified: `MD5("Thuong123") = aead1222d31203158a44f5bbbc374ae7` (the leftover operator row).
No need to reverse `GMPassGen.exe` for server-side work — insert rows directly:
`password=MD5(pw)`, `rowpass=pw`, `active=1`.
Security note: this is trivially crackable — never reuse a real password, and keep the paysys DB local-only.

## Open items / hardening TODO

- [ ] **Revert `skip-grant-tables`** (currently in `/etc/my.cnf.d/zz-skip-grants.cnf`) — temporarily enabled to bypass the DB-password derivation. Then set a single agreed DB password that satisfies rule #1/#2 and update all configs + MariaDB user.
- [ ] **Do not expose 8886** (GS) publicly — restrict to localhost/private and keep only 55795 open for players.
- [ ] Registration web panel (still absent) — build against `paysys.account` using MD5 format.
- [ ] Client package still needed (not in the tarball): set `GameIPAddress=130.94.6.220` in `settings/glsver_list` + `server_jae`.
- [ ] 7 `_LoadTable() KGD_ERROR_NOT_SUPPORT` warnings in Goddess → identify which tables the build ignores (likely extra/newer tables in the dump).
- [ ] RAM headroom: 1.3 GB used with 1 GS; each extra GS needs ~0.5–1 GB. Do not start all 7 on this box.
- [ ] Local repo `github.com/Vuthi1111/jx2` is still empty — push scripts/configs for review.
