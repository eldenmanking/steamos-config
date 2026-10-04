#!/usr/bin/env python3
"""Smoke test for the ttyd + systemd-socket-proxyd chain, without systemd.

systemd-socket-activate plays webterm.socket: it listens on a TCP port and
starts systemd-socket-proxyd on the first connection, exactly like the unit.
Checks: secret path, origin check, shell round-trip, and idle exit.
"""
import base64
import os
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = 3999
TOKEN = "smoketoken"
IDLE = "4s"


def fail(msg):
    print("FAIL:", msg)
    cleanup()
    sys.exit(1)


procs = []


def cleanup():
    for p in procs:
        if p.poll() is None:
            p.kill()


def find_proxyd():
    for p in ("/usr/lib/systemd/systemd-socket-proxyd", "/lib/systemd/systemd-socket-proxyd"):
        if os.access(p, os.X_OK):
            return p
    fail("systemd-socket-proxyd not found")


def http_get(path):
    with socket.create_connection(("127.0.0.1", PORT), timeout=5) as s:
        s.sendall(f"GET {path} HTTP/1.1\r\nHost: localhost:{PORT}\r\nConnection: close\r\n\r\n".encode())
        data = b""
        while chunk := s.recv(65536):
            data += chunk
    return int(data.split(b" ", 2)[1])


class WS:
    """Just enough of a WebSocket client to speak ttyd's protocol."""

    def __init__(self, path, host, origin):
        self.s = socket.create_connection(("127.0.0.1", PORT), timeout=5)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall(
            (
                f"GET {path} HTTP/1.1\r\nHost: {host}\r\nOrigin: {origin}\r\n"
                "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n"
                "Sec-WebSocket-Protocol: tty\r\n\r\n"
            ).encode()
        )
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = self.s.recv(4096)
            if not chunk:
                break
            resp += chunk
        self.ok = resp.startswith(b"HTTP/1.1 101")
        self.buf = resp.split(b"\r\n\r\n", 1)[1] if self.ok else b""

    def send(self, data):
        payload = data.encode() if isinstance(data, str) else data
        mask = os.urandom(4)
        n = len(payload)
        head = bytes([0x82])
        head += bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + struct.pack(">H", n)
        self.s.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.s.recv(65536)
            if not chunk:
                raise EOFError
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def recv(self):
        b0, b1 = self._read(2)
        n = b1 & 0x7F
        if n == 126:
            n = struct.unpack(">H", self._read(2))[0]
        elif n == 127:
            n = struct.unpack(">Q", self._read(8))[0]
        return b0 & 0x0F, self._read(n)

    def close(self):
        self.s.close()


def main():
    ttyd = os.path.join(REPO, "bin", "ttyd")
    if not os.access(ttyd, os.X_OK):
        subprocess.run(["bash", os.path.join(REPO, "scripts", "fetch-ttyd.sh")], check=True)
    if not shutil.which("systemd-socket-activate"):
        fail("systemd-socket-activate not found")

    rundir = tempfile.mkdtemp()
    sock = os.path.join(rundir, "webterm.sock")
    env = {**os.environ, "SHELL": "/bin/bash", "WEBTERM_TMUX": "0"}
    procs.append(subprocess.Popen(
        [ttyd, "-i", sock, "-b", f"/{TOKEN}", "-W", "-O", "-P", "10",
         os.path.join(REPO, "bin", "webterm-shell")],
        env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    for _ in range(50):
        if os.path.exists(sock):
            break
        time.sleep(0.1)
    else:
        fail("ttyd did not create its socket")

    activator = subprocess.Popen(
        ["systemd-socket-activate", "-l", f"127.0.0.1:{PORT}",
         find_proxyd(), f"--exit-idle-time={IDLE}", sock],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    procs.append(activator)
    time.sleep(0.5)

    if http_get("/") != 404:
        fail("page served without the secret path")
    if http_get(f"/{TOKEN}/") != 200:
        fail("page not served under the secret path")
    print("ok: page only served under the secret path")

    host = f"localhost:{PORT}"
    bad = WS(f"/{TOKEN}/ws", host, "http://evil.example")
    if bad.ok:
        fail("cross-origin websocket was accepted")
    bad.close()
    print("ok: cross-origin websocket rejected")

    ws = WS(f"/{TOKEN}/ws", host, f"http://{host}")
    if not ws.ok:
        fail("same-origin websocket was rejected")
    ws.send('{"AuthToken":"","columns":80,"rows":24}')
    # arithmetic so the typed echo differs from the command's real output
    ws.send("0echo web$((40+2))term; exit\n")
    out = b""
    deadline = time.time() + 5
    while b"web42term" not in out and time.time() < deadline:
        try:
            op, data = ws.recv()
        except (EOFError, socket.timeout):
            break
        if op == 0x2 and data[:1] == b"0":
            out += data[1:]
    ws.close()
    if b"web42term" not in out:
        fail("no shell output")
    print("ok: shell round-trip")

    try:
        code = activator.wait(timeout=10)
    except subprocess.TimeoutExpired:
        fail("proxy did not exit after idle")
    print("ok: proxy exited when idle, code", code)
    cleanup()
    shutil.rmtree(rundir, ignore_errors=True)
    sys.exit(0 if code == 0 else 1)


if __name__ == "__main__":
    main()
