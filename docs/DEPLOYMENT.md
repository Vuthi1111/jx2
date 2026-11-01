# Deployment runbook — JX2 server package on CentOS Stream 9

Verified on: CentOS Stream 9, x86_64, 2 vCPU, 3.6 GB RAM, 50 GB disk.
Target path is **`/home/server`** — hardcoded in the start scripts and in the `gs*/settings|data|maps|script`
symlinks. Do not relocate.

Package layout (from `sever2021Full.tgz`):

```
server/gw/Goddess   login + role database        (KG_GoddessD, KG_StatGameDataD, KG_RoleAdminD)
server/gw/Bishop    gateway: relay/gs/player     (KG_BishopD)
server/gw/Relay     cross-server, chat, guild    (SO2RelayD)
server/gs1..gs7     game servers                 (SO2GameSvrD1..7 — Go 1.14 + Lua)
server/paysysvip    billing (Windows PE32)       (GamePaysys.exe + paysys.ini)
server/databasesql  MySQL dumps (schema only)
server/start        convenience scripts (broken for this layout — see §8)
```

## 1. Base OS

```bash
dnf install -y mariadb-server glibc-langpack-zh libaio tar
systemctl enable --now mariadb
```

## 2. Supported locale

The server and its data files use GBK paths; scripts export `LANG=zh_CN.gbk`.
Installing `glibc-langpack-zh` is enough. Extracting the tarball on Linux needs no special handling
(on macOS use `tools/extract_gbk.py`).

## 3. MySQL configuration (all four are mandatory)

`/etc/my.cnf.d/jx2.cnf`:

```ini
[mysqld]
lower_case_table_names=1
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
```

Then the socket the old client library expects:

```bash
ln -sf /var/lib/mysql/mysql.sock /tmp/mysql.sock
```

*Why*: the embedded MySQL 5.5 client connects through the socket when host is local, and Goddess refuses
to run against a case-sensitive or charset-mismatched server.

## 4. Databases

```bash
mysql -uroot <<'SQL'
CREATE DATABASE IF NOT EXISTS jx2ib_database     DEFAULT CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS jx2ib_database_log DEFAULT CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS paysys             DEFAULT CHARACTER SET utf8mb4;
SQL
mysql -uroot jx2ib_database     < /home/server/databasesql/jx2ib_database.sql
mysql -uroot jx2ib_database_log < /home/server/databasesql/jx2ib_database_log.sql
mysql -uroot paysys             < /home/server/databasesql/paysys.sql
```

The dumps are schema-only (no player data) apart from 3 rows in `paysys` — delete them before going live
(see `tools/deploy_setup.sh` §4).

## 5. Credentials

The DB password in every config must be **exactly 32 characters** from `[A-Za-z0-9_]`.
Both a 20-char value and a 32-char lowercase-hex value were rejected by `KG_Goddess`'s config validator
(`Password Length Error` / `Password Error`). Use the same 32-char value in MariaDB and in:

- `gw/Goddess/KG_Goddess.ini` — `[DatabaseServer] Password`
- `gw/Goddess/KG_RoleAdmin.ini` — `password`
- `gw/Goddess/KG_StatGameData.ini` — `Password`
- `gw/Goddess/KGD_MySQLBackup.ini` — `Password`
- `gw/Relay/RelaySetting/Database.ini` — `Password`
- `paysysvip/paysys.ini` — `[Mysql] Password`

Set `EnableEncrypt=0` in the files that ship with `1` for consistency (the flag did not change behaviour in testing).

## 6. Public IP

`gs*/servercfg.ini` → `[Net] ExternalIP=<public ip>` (ships with the previous operator's IP).
`gw/Bishop/bishop.ini` → `[Player] LocalIPAddress=0.0.0.0` (client entry point) and `OpenPort=55795`.

Firewall: expose **55795** only. 5001/5632/5633/8000/8886 must stay internal — 8886 is the game server and
bypasses gateway auth if reachable.

## 7. Paysys (required by Bishop)

Bishop aborts with `KG_BishopPaySys.cpp:74 Init` if paysys is unreachable — there is no disable switch.
`GamePaysys.exe` is a PE32 **simulator** (the package author's own billing replacement), so it must run under
32-bit Wine. EPEL's `wine-8.0` on el9 is 64-bit only (`syswow64\rundll32.exe` missing) — use a container:

```bash
dnf install -y podman
podman pull docker.io/scottyhardy/docker-wine:latest
podman run -d --name jx2-paysys --network host -w /paysys \
  -e WINEDEBUG=-all -v /home/server/paysysvip:/paysys \
  docker.io/scottyhardy/docker-wine wine GamePaysys.exe
```

It listens on `127.0.0.1:8000` and reads `paysys.ini` (MySQL `paysys` DB) from its working directory.

## 8. Start order

`tools/deploy_services.sh` creates systemd units (recommended — daemon mode of these binaries holds the
SSH session open, so don't use `start --daemon` over ssh):

```
MariaDB -> jx2-goddess -> paysys container -> jx2-bishop -> jx2-relay -> jx2-gs1
```

The shipped `startgs` / `nstart` / `bstart` scripts are broken for this layout: they derive the binary name
from a `/home/so2game/server<N>` path. Launch `/home/server/gsN/SO2GameSvrDN` directly.
`gdb.txt` in each gs dir documents the port argument (`r 6660`), while `servercfg.ini` ships `[GameServer] Port=8886`.

Successful boot signature in the Bishop log:

```
[net] Connect [127.0.0.1:8000] ok            <- paysys
[Goddess] Connect to (127.0.0.1: 5001) ok
[Relay] ThreadFunction() RelayConnectedInit nRetCode = 1
[GameServer 0] Connected from 127.0.0.1 ... open port = 8886, protocol version (80-->80)
[GameServer 0] === Start ===
```

## 9. Accounts

`paysys.account.password` = **unsalted MD5** of the password; `rowpass` = plaintext; `active=1`.

```sql
INSERT INTO account (id, username, password, rowpass, active, email, testcoin, createtime)
VALUES (20001,'test',MD5_via_shell,'test123',1,'test@localhost.local',9999999,NOW());
```

(compute `MD5(password)` with `printf '%s' "$PW" | md5sum`)

## 10. Client

Set `GameIPAddress=<public ip>` in the client's `settings/glsver_list` and `server_jae`, and the realm name
to whatever you like. The client package is separate from the server package.

## 11. Known warnings

- 7× `KGD_ERROR_NOT_SUPPORT ... _LoadTable()` in the Goddess log — tables present in the dump that this
  build does not model. Non-fatal; investigate only if a feature misbehaves.
- `[verify_up2date] ok` lines are normal.
- License blobs (`gs*/license`, `gs*/licenese`, `verify_up2date`) did **not** block startup on a fresh host.