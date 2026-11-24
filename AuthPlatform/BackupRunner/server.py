#!/usr/bin/env python3
"""Authenticated, single-execution HTTP trigger for the backup container."""
import hmac
import json
import os
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = os.environ.get("BACKUP_TRIGGER_TOKEN", "")
state = {"status": "idle", "result": None}
lock = threading.Lock()

def run_backup():
    try:
        completed = subprocess.run(
            ["python3", "/backup/backup_once.py"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=int(os.environ.get("BACKUP_TIMEOUT_SECONDS", "3600")),
            check=False,
        )
        if completed.returncode == 0:
            try:
                result = json.loads(completed.stdout.strip().splitlines()[-1])
            except Exception:
                result = {"status": "completed", "details": "Backup process exited successfully"}
            with lock:
                state["status"] = "succeeded"
                state["result"] = result
        else:
            with lock:
                state["status"] = "failed"
                state["result"] = {"error": "Backup process failed; sensitive output suppressed"}
    except Exception as exc:
        with lock:
            state["status"] = "failed"
            state["result"] = {"error": type(exc).__name__}

class Handler(BaseHTTPRequestHandler):
    def send_json(self, code, payload):
        body = json.dumps(payload, sort_keys=True).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"service": "authplatform-backup-runner", "status": "ready"})
        elif self.path == "/status":
            with lock:
                self.send_json(200, dict(state))
        else:
            self.send_json(404, {"error": "not_found"})

    def do_POST(self):
        if self.path != "/run":
            self.send_json(404, {"error": "not_found"})
            return
        if len(TOKEN) < 32:
            self.send_json(503, {"error": "backup_trigger_not_configured"})
            return
        supplied = self.headers.get("Authorization", "")
        expected = "Bearer " + TOKEN
        if not hmac.compare_digest(supplied.encode("utf-8"), expected.encode("utf-8")):
            self.send_json(401, {"error": "unauthorized"})
            return
        with lock:
            if state["status"] != "idle":
                self.send_json(409, {"error": "one_time_execution_already_started",
                                     "status": state["status"]})
                return
            state["status"] = "running"
            state["result"] = None
        threading.Thread(target=run_backup, daemon=True).start()
        self.send_json(202, {"status": "accepted", "message": "One-time backup started"})

    def log_message(self, fmt, *args):
        return

port = int(os.environ.get("PORT", "10000"))
ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
