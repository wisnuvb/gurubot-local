#!/usr/bin/env python3
"""
GuruBot Setup Agent — portal operator + API (hanya PC server).
Bind 127.0.0.1:2077 — terpisah dari https://gurubot.sekolah (aplikasi sekolah).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse

AGENT_VERSION = "1.0.0"
DEFAULT_PORT = 2077
HOST = "127.0.0.1"
STATIC_DIR = Path(__file__).resolve().parent / "static"
STATIC_FILES = {
    "/": ("index.html", "text/html; charset=utf-8"),
    "/index.html": ("index.html", "text/html; charset=utf-8"),
    "/app.css": ("app.css", "text/css; charset=utf-8"),
    "/app.js": ("app.js", "application/javascript; charset=utf-8"),
}


def bundle_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


def load_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def operator_pin() -> str:
    env = os.environ.get("OPERATOR_SETUP_PIN", "").strip()
    if env:
        return env
    return load_env_file(bundle_root() / ".env.docker").get("OPERATOR_SETUP_PIN", "").strip()


def agent_token() -> str:
    env = os.environ.get("OPERATOR_AGENT_TOKEN", "").strip()
    if env:
        return env
    dot = load_env_file(bundle_root() / ".env.docker")
    return dot.get("OPERATOR_AGENT_TOKEN", "").strip()


def env_docker_path() -> Path:
    return bundle_root() / ".env.docker"


def mask_database_url(url: str) -> str:
    return re.sub(r":([^:@/]+)@", ":****@", url or "")


def build_database_url(user: str, password: str, database: str, port: str = "3306") -> str:
    host = "host.docker.internal"
    u = quote(user, safe="")
    db = quote(database, safe="")
    if password:
        p = quote(password, safe="")
        return f"mysql://{u}:{p}@{host}:{port}/{db}"
    return f"mysql://{u}@{host}:{port}/{db}"


def set_env_docker_value(key: str, value: str) -> None:
    path = env_docker_path()
    if not path.is_file():
        raise FileNotFoundError(f".env.docker tidak ada: {path}")
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    pattern = re.compile(rf"^{re.escape(key)}=")
    found = False
    out: list[str] = []
    for line in lines:
        if pattern.match(line):
            out.append(f"{key}={value}")
            found = True
        else:
            out.append(line)
    if not found:
        out.append(f"{key}={value}")
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def run_ps1(script: Path, *args: str) -> tuple[int, str]:
    cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script),
        *args,
    ]
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=str(bundle_root()))
    out = (p.stdout or "") + (p.stderr or "")
    return p.returncode, out.strip()


def run_bat(bat: Path) -> tuple[int, str]:
    env = os.environ.copy()
    env["GURUBOT_NONINTERACTIVE"] = "1"
    p = subprocess.run(
        ["cmd", "/c", str(bat)],
        capture_output=True,
        text=True,
        cwd=str(bundle_root()),
        env=env,
    )
    out = (p.stdout or "") + (p.stderr or "")
    return p.returncode, out.strip()


def health_json() -> dict:
    script = bundle_root() / "scripts" / "lib" / "health-check.ps1"
    code, out = run_ps1(script)
    if code != 0 and not out.strip():
        return {"ok": False, "error": "health-check.ps1 failed", "detail": out}
    try:
        # Ambil hanya blok JSON (baris pertama { sampai akhir)
        text = out.strip()
        start = text.find("{")
        if start >= 0:
            text = text[start:]
        return json.loads(text)
    except json.JSONDecodeError:
        return {"ok": False, "error": "invalid health JSON", "detail": out[:2000]}


def ensure_root_ca() -> Path | None:
    mobile = bundle_root() / "certs" / "mobile" / "gurubot-mkcert-rootCA.pem"
    if mobile.is_file():
        return mobile
    bat = bundle_root() / "scripts" / "setup-ssl-mobile.bat"
    if bat.is_file():
        run_bat(bat)
    if mobile.is_file():
        return mobile
    return None


def latest_autostart_log() -> str:
    logs = bundle_root() / "logs"
    if not logs.is_dir():
        return ""
    files = sorted(logs.glob("autostart-*.log"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        return ""
    try:
        text = files[0].read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        return "\n".join(lines[-40:])
    except OSError:
        return ""


class Handler(BaseHTTPRequestHandler):
    server_version = f"GuruBotSetupAgent/{AGENT_VERSION}"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write(f"[setup-agent] {self.address_string()} - {fmt % args}\n")

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0:
            return b""
        return self.rfile.read(length)

    def _auth_ok(self) -> bool:
        token = agent_token()
        if not token:
            return False
        hdr = self.headers.get("Authorization", "")
        if hdr.startswith("Bearer ") and hdr[7:].strip() == token:
            return True
        qs = parse_qs(urlparse(self.path).query)
        if qs.get("token", [""])[0] == token:
            return True
        return False

    def _json(self, code: int, obj: dict) -> None:
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _unauthorized(self) -> None:
        self._json(401, {"ok": False, "error": "Unauthorized"})

    def _file(self, code: int, data: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path != "/" and path.endswith("/"):
            path = path.rstrip("/") or "/"

        if path in STATIC_FILES:
            name, ctype = STATIC_FILES[path]
            fp = STATIC_DIR / name
            if fp.is_file():
                self._file(200, fp.read_bytes(), ctype)
                return

        if path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return

        if path == "/health":
            self._json(200, {"ok": True, "agent": AGENT_VERSION})
            return

        if path in ("/bootstrap", "/api/operator/bootstrap"):
            pin = operator_pin()
            self._json(
                200,
                {
                    "ok": True,
                    "pinRequired": bool(pin),
                    "domain": "gurubot.sekolah",
                    "agentVersion": AGENT_VERSION,
                },
            )
            return

        if path in ("/status", "/api/operator/status"):
            if not self._auth_ok():
                self._unauthorized()
                return
            data = health_json()
            data["autostartLogTail"] = latest_autostart_log()
            data["agentVersion"] = AGENT_VERSION
            self._json(200, data)
            return

        if path in ("/certs/root-ca", "/api/operator/certs/root-ca"):
            if not self._auth_ok():
                self._unauthorized()
                return
            ca = ensure_root_ca()
            if not ca:
                self._json(404, {"ok": False, "error": "root CA not found; run setup-ssl.bat"})
                return
            data = ca.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/x-pem-file")
            self.send_header(
                "Content-Disposition",
                'attachment; filename="gurubot-mkcert-rootCA.pem"',
            )
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return

        self._json(404, {"ok": False, "error": "Not found"})

    def do_POST(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"

        if path in ("/auth/pin", "/api/operator/auth/pin"):
            try:
                body = json.loads(self._read_body().decode("utf-8") or "{}")
            except json.JSONDecodeError:
                self._json(400, {"ok": False, "error": "Invalid JSON"})
                return
            pin = str(body.get("pin", "")).strip()
            expected = operator_pin()
            token = agent_token()
            if not expected:
                if token:
                    self._json(200, {"ok": True, "token": token, "message": "PIN tidak dikonfigurasi"})
                else:
                    self._json(503, {"ok": False, "error": "OPERATOR_AGENT_TOKEN belum diset"})
                return
            if pin != expected:
                self._json(403, {"ok": False, "error": "PIN salah"})
                return
            if not token:
                self._json(503, {"ok": False, "error": "OPERATOR_AGENT_TOKEN belum diset"})
                return
            self._json(200, {"ok": True, "token": token})
            return

        if not self._auth_ok():
            self._unauthorized()
            return

        if path in ("/mysql/config", "/api/operator/mysql/config"):
            try:
                body = json.loads(self._read_body().decode("utf-8") or "{}")
            except json.JSONDecodeError:
                self._json(400, {"ok": False, "error": "Invalid JSON"})
                return
            user = str(body.get("user", "")).strip()
            database = str(body.get("database", "")).strip()
            password = str(body.get("password", ""))
            port = str(body.get("port", "3306")).strip() or "3306"
            restart = body.get("restartApp", True)
            if not user or not database:
                self._json(400, {"ok": False, "error": "user dan database wajib diisi"})
                return
            if not re.match(r"^[A-Za-z0-9_]+$", database):
                self._json(400, {"ok": False, "error": "Nama database tidak valid"})
                return
            try:
                url = build_database_url(user, password, database, port)
                set_env_docker_value("DATABASE_URL", url)
            except FileNotFoundError as e:
                self._json(404, {"ok": False, "error": str(e)})
                return
            except OSError as e:
                self._json(500, {"ok": False, "error": f"Gagal menulis .env.docker: {e}"})
                return
            restart_out = ""
            restart_ok = True
            if restart:
                code, restart_out = run_bat(bundle_root() / "scripts" / "operator-restart-app.bat")
                restart_ok = code == 0
            self._json(
                200,
                {
                    "ok": True,
                    "databaseUrlMasked": mask_database_url(url),
                    "restartOk": restart_ok,
                    "output": restart_out[-4000:] if restart_out else "",
                },
            )
            return

        root = bundle_root()
        scripts = root / "scripts"

        action = path
        m = re.match(r"^/api/operator/actions/([^/]+)$", path)
        if m:
            action = m.group(1)

        if action in ("/actions/setup-dns", "setup-dns"):
            code, out = run_bat(scripts / "setup-dns.bat")
            self._json(200 if code == 0 else 500, {"ok": code == 0, "exitCode": code, "output": out[-8000:]})
            return

        if action in ("/actions/firewall", "firewall"):
            code, out = run_bat(scripts / "setup-lan-firewall.bat")
            self._json(200 if code == 0 else 500, {"ok": code == 0, "exitCode": code, "output": out[-8000:]})
            return

        if action in ("/actions/docker-up", "docker-up"):
            code, out = run_bat(scripts / "docker-up.bat")
            self._json(200 if code == 0 else 500, {"ok": code == 0, "exitCode": code, "output": out[-8000:]})
            return

        if action in ("/actions/test-db", "test-db"):
            code, out = run_bat(scripts / "operator-test-db.bat")
            self._json(200 if code == 0 else 500, {"ok": code == 0, "exitCode": code, "output": out[-8000:]})
            return

        if action in ("/actions/mysql-create-db", "mysql-create-db"):
            code, out = run_bat(scripts / "operator-mysql-create-db.bat")
            self._json(200 if code == 0 else 500, {"ok": code == 0, "exitCode": code, "output": out[-8000:]})
            return

        if action in ("/actions/prisma-generate", "prisma-generate"):
            code, out = run_bat(scripts / "prisma-generate.bat")
            self._json(200 if code == 0 else 500, {"ok": code == 0, "exitCode": code, "output": out[-8000:]})
            return

        if action in ("/actions/open-env-docker", "open-env-docker"):
            env_path = env_docker_path()
            if not env_path.is_file():
                self._json(404, {"ok": False, "error": ".env.docker tidak ditemukan"})
                return
            subprocess.Popen(
                ["notepad.exe", str(env_path)],
                cwd=str(bundle_root()),
                close_fds=True,
            )
            self._json(200, {"ok": True, "output": f"Membuka {env_path} di Notepad"})
            return

        if action in ("/actions/stop-host-nginx", "stop-host-nginx"):
            code, out = run_bat(scripts / "operator-stop-host-nginx.bat")
            self._json(200 if code == 0 else 500, {"ok": code == 0, "exitCode": code, "output": out[-4000:]})
            return

        self._json(404, {"ok": False, "error": "Unknown action"})


def main() -> None:
    port = int(os.environ.get("GURUBOT_SETUP_AGENT_PORT", DEFAULT_PORT))
    httpd = ThreadingHTTPServer((HOST, port), Handler)
    sys.stderr.write(f"[setup-agent] Listening on http://{HOST}:{port}\n")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
