#!/usr/bin/env python3
"""Paysys stub — capture/emulate the Bishop<->Paysys protocol.
Phase 1: log every byte Bishop sends so we can reverse the framing.
"""
import socket
import sys
import time
import binascii

HOST, PORT = "127.0.0.1", 8000
LOG = "/root/paysys_stub.log"


def log(msg):
    line = f"{time.strftime('%H:%M:%S')} {msg}"
    print(line, flush=True)
    with open(LOG, "a") as f:
        f.write(line + "\n")


def hexdump(data: bytes) -> str:
    return binascii.hexlify(data).decode()


srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind((HOST, PORT))
srv.listen(5)
log(f"listening {HOST}:{PORT}")

while True:
    conn, addr = srv.accept()
    log(f"CONNECT from {addr}")
    conn.settimeout(20)
    buf = b""
    try:
        while True:
            chunk = conn.recv(65536)
            if not chunk:
                log("peer closed")
                break
            buf += chunk
            log(f"RECV {len(chunk)}B: {hexdump(chunk)}")
    except socket.timeout:
        log("recv timeout")
    except Exception as e:
        log(f"error: {e}")
    finally:
        conn.close()