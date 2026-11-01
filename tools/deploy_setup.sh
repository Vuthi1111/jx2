#!/bin/bash
# JX2 server deploy — step 1: extract, DB, config patch
# Runs on the VPS as root. Idempotent-ish; re-runnable.
set -uo pipefail

TGZ=${JX_TGZ:-/root/sever2021Full.tgz}
NEWPW="${JX_DB_PASSWORD:?set JX_DB_PASSWORD (exactly 32 chars)}"
EXTIP="${JX_EXT_IP:?set JX_EXT_IP}"

echo "=== 1. extract to /home ==="
mkdir -p /home
if [ ! -d /home/server/gw ]; then
  tar -xzf "$TGZ" -C /home && echo "extracted"
else
  echo "already extracted"
fi
chmod -R 755 /home/server 2>/dev/null
echo "files: $(find /home/server -type f | wc -l)  size: $(du -sh /home/server | cut -f1)"

echo "=== 2. mysql: root password + native auth + TCP user ==="
mysql -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${NEWPW}');
FLUSH PRIVILEGES;
SQL
mysql -uroot -p"${NEWPW}" <<SQL
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '${NEWPW}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS jx2ib_database DEFAULT CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS jx2ib_database_log DEFAULT CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS paysys DEFAULT CHARACTER SET utf8mb4;
FLUSH PRIVILEGES;
SQL

echo "=== 3. import schema ==="
grep -q jx2ib_database /etc/my.cnf.d/*.cnf 2>/dev/null
mysql -uroot -p"${NEWPW}" jx2ib_database < /home/server/databasesql/jx2ib_database.sql && echo "jx2ib ok"
mysql -uroot -p"${NEWPW}" jx2ib_database_log < /home/server/databasesql/jx2ib_database_log.sql && echo "jx2ib_log ok"
mysql -uroot -p"${NEWPW}" paysys < /home/server/databasesql/paysys.sql && echo "paysys ok"

echo "=== 4. purge leftover operator data ==="
mysql -uroot -p"${NEWPW}" paysys -e "DELETE FROM account; DELETE FROM admin; DELETE FROM login_log; DELETE FROM charge_log; DELETE FROM history_log; DELETE FROM card_log; DELETE FROM deposits;" 2>/dev/null && echo "paysys purged"
rm -f /home/server/gs*/*.pid /home/server/gw/*/*.pid /home/server/gw/*/BishopLiveTime.tm 2>/dev/null
rm -rf /home/server/gs*/dulieu/login_logs/* /home/server/gs*/logs/* /home/server/gs*/startlog/* 2>/dev/null
: > /home/server/gs*/gs.log 2>/dev/null
echo "logs/pid cleaned"

echo "=== 5. patch configs: password + external IP ==="
cd /home/server
# passwords (each tool had its own leaked one -> one strong value)
sed -i "s/^Password=.*/Password=${NEWPW}/; s/^password=.*/password=${NEWPW}/; s/^ModifyPassword=.*/ModifyPassword=${NEWPW}/" \
  gw/Goddess/KG_Goddess.ini gw/Goddess/KG_RoleAdmin.ini gw/Goddess/KG_StatGameData.ini \
  gw/Goddess/KGD_MySQLBackup.ini gw/Relay/RelaySetting/Database.ini paysysvip/paysys.ini 2>/dev/null
# plaintext mode everywhere (the stored ones were inconsistent/encrypted)
sed -i "s/EnableEncrypt=1/EnableEncrypt=0/" gw/Goddess/KG_StatGameData.ini gw/Goddess/KGD_MySQLBackup.ini gw/Relay/RelaySetting/Database.ini 2>/dev/null
# external IP
sed -i "s/^ExternalIP=.*/ExternalIP=${EXTIP}/" gs*/servercfg.ini
# bishop: bind player port to all interfaces
sed -i "/^\[Player\]/,/^\[/ s/^LocalIPAddress=.*/LocalIPAddress=0.0.0.0/" gw/Bishop/bishop.ini

echo "=== 6. verify patch ==="
grep -H "^Password=\|^password=\|^ExternalIP=\|EnableEncrypt=" gw/Goddess/KG_Goddess.ini gw/Goddess/KG_RoleAdmin.ini gs1/servercfg.ini paysysvip/paysys.ini | head -10
grep -A2 "^\[Player\]" gw/Bishop/bishop.ini | head -3
echo "=== DONE step1 ==="