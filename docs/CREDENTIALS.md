# Database credentials — the full story

This is the most confusing part of the whole stack, so it gets its own document.
Everything below was established empirically on a live deployment.

## Who connects to MySQL, and how

| Component | Connection | Account it uses | Status |
|---|---|---|---|
| Goddess (login/role) | UNIX socket `/tmp/mysql.sock` | `root`/`localhost` | works |
| Relay | socket + two more (relay.ini `[DataBase]`, `[GlobalDatabase]`, `[MyGlbDB]`, `RelaySetting/Database.ini`) | `root`/`localhost` | works after pointing every host at `localhost` |
| GameServer (Go) | **TCP 127.0.0.1:3306** for its log DB | `root`, password baked into the binary | works only with auth bypass |
| Paysys simulator (Wine) | **TCP 127.0.0.1:3306** | anything we configure | works with a native-password user |

## Hard constraints discovered

1. **`KG_Goddess` config validator** rejects some passwords outright:
   - wrong length → `Password Length Error` (`KG_Goddess.cpp:393`)
   - rejected content → `Password Error` (`KG_Goddess.cpp:395`)
   32 characters from `[A-Za-z0-9_]` was the only shape that passed validation.
2. **Relay reads FOUR separate DB configs.** Fixing one is not enough — `relay.ini` has
   `[DataBase]` (with `DBHost=`), `[GlobalDatabase]` and `[MyGlbDB]`, plus
   `RelaySetting/Database.ini`. Any one still pointing at `127.0.0.1` over TCP produces
   `Access denied` and the relay dies with `Start failed` (it does *not* say why at INFO level;
   `strace` shows the MySQL error packet `28000`).
3. **The gameserver's log-DB password cannot be found in any config file.** It is compiled into
   the Go binary. It is not empty and not any of `1234`, `123456`, `12345678`, `root`, `jx2`.
   The address is TCP `127.0.0.1:3306` and the account is `root`.
4. **The old MySQL 5.0/5.5 clients cannot do plugin-based auth** (`pam`, `unix_socket` over TCP).
   MariaDB's PAM auth worked fine from the CLI but the gameserver still failed.
5. **Paysys's ini password is limited to 16 characters.** A 32-character password made it fail
   with `Cannot Connect to Mysql Server`; 16 characters worked.
6. **MariaDB needs `lower_case_table_names=1`** and a server charset that matches the databases
   (`utf8mb4`), otherwise Goddess refuses to start with explicit messages.
7. **`jx2ib_database_log.common_log` must not be `latin1`.** With `latin1` the gameserver's
   `CreateLogDB` fails; convert the table to `utf8mb4`.

## What we ended up with

`/etc/my.cnf.d/jx2.cnf`:

```ini
[mysqld]
lower_case_table_names=1
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
bind-address=127.0.0.1
skip-grant-tables
```

**Why `skip-grant-tables`**: the gameserver's compiled-in log-DB password is unknown and cannot be
changed without patching the binary. Constraints 3, 4 and 5 together leave no way to satisfy all
four components with real grants on this build.

**What makes it acceptable (barely)**:

- MariaDB listens on `127.0.0.1` only (`bind-address`), verified with `ss -tln`.
- firewalld's public zone allows only SSH and `55795/tcp`; everything else falls through to
  `reject`, so 3306 is not reachable from the internet even before the bind-address.
- the host is single-tenant and every game process already runs as root.

**This is the one known security debt.** If it matters later, the options are:
patch the Go binary's log-DB credential handling (reverse `CreateLogDB`), or run a second MySQL
instance for the gameserver with the real `jx2ib_database` proxied, or accept it behind the
loopback+firewall boundary as we do now.

## Accounts present after cleanup

| User | Host | Plugin | Purpose |
|---|---|---|---|
| `root` | localhost | `mysql_native_password` (grants bypassed) | everything |
| `jx2t` | 127.0.0.1 | `mysql_native_password`, 16-char secret | paysys simulator |

Temporary accounts created during debugging (`paysys` via PAM, `wineuser` via unix_socket,
`root@127.0.0.1`) were dropped, and `/etc/pam.d/mysql` removed.

## Never do this again

- Don't rotate the DB password without testing **all four** Relay config sections.
- Don't set a paysys password longer than 16 characters.
- Don't leave `jx2ib_database_log` with `latin1` tables.
- `mysql -h127.0.0.1` from the shell as root only works because grants are bypassed; if grants are
  ever re-enabled, `root@localhost` uses `mysql_native_password` and the CLI needs the password.