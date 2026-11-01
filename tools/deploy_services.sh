#!/bin/bash
# Create systemd units for the JX2 stack and start them in dependency order.
set -uo pipefail

mk_unit() { # name, description, workdir, exec, after
  cat > "/etc/systemd/system/$1.service" <<EOF
[Unit]
Description=$2
After=$5 mariadb.service
Wants=mariadb.service

[Service]
Type=simple
WorkingDirectory=$3
Environment=LANG=zh_CN.gbk
ExecStart=$4
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
LimitCORE=unlimited

[Install]
WantedBy=multi-user.target
EOF
}

mk_unit jx2-goddess "JX2 Goddess (login/role server)" /home/server/gw/Goddess "/home/server/gw/Goddess/KG_GoddessD" ""
mk_unit jx2-bishop  "JX2 Bishop (gateway)"           /home/server/gw/Bishop  "/home/server/gw/Bishop/KG_BishopD"  "jx2-goddess.service"
mk_unit jx2-relay   "JX2 Relay"                      /home/server/gw/Relay   "/home/server/gw/Relay/SO2RelayD"    "jx2-goddess.service"
mk_unit jx2-gs1     "JX2 GameServer 1"               /home/server/gs1        "/home/server/gs1/SO2GameSvrD1"      "jx2-bishop.service"
mk_unit jx2-paysys-stub "Paysys stub (billing replaced)" /root "/usr/bin/python3 /root/paysys_stub.py" ""

systemctl daemon-reload
echo "--- units created ---"

mkdir -p /root/paysys_stub.log.d
rm -f /home/server/gw/Goddess/KG_GoddessD.pid /home/server/gw/Bishop/KG_BishopD.pid /home/server/gw/Relay/SO2RelayD.pid

systemctl start jx2-goddess;  sleep 4; echo "goddess: $(systemctl is-active jx2-goddess)"
systemctl start jx2-paysys-stub; sleep 2; echo "stub:    $(systemctl is-active jx2-paysys-stub)"
systemctl start jx2-bishop;   sleep 4; echo "bishop:  $(systemctl is-active jx2-bishop)"
systemctl start jx2-relay;    sleep 3; echo "relay:   $(systemctl is-active jx2-relay)"

echo "=== ports ==="
ss -tlnp | grep -E ":8000|:5001|:5632|:5633|:55795" || echo none