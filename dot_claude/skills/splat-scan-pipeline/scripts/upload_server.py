#!/usr/bin/env python3
"""Minimal upload receiver for phone-captured scans (SplatKing LiDAR exports, etc.).

Usage:
    python3 upload_server.py <incoming_dir> [port]

Accepts:
    POST /upload  multipart/form-data with a field named "file"
    POST /upload  raw body + header "X-Filename: <name>" (no multipart)

Run in the background so it doesn't block:
    setsid nohup python3 upload_server.py <incoming_dir> 8000 \
        < /dev/null > upload_server.log 2>&1 & disown

Then tell the user the machine's LAN IP and port, e.g. http://192.168.0.58:8000/upload,
and poll <incoming_dir> for the new file (watch for the size to stop changing before
treating the upload as complete — large captures can take a while over Wi-Fi).
"""
import cgi
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

INCOMING = sys.argv[1] if len(sys.argv) > 1 else "./incoming"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
os.makedirs(INCOMING, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path.rstrip("/") != "/upload":
            self.send_response(404)
            self.end_headers()
            return
        ctype = self.headers.get("Content-Type", "")
        if ctype.startswith("multipart/form-data"):
            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={"REQUEST_METHOD": "POST", "CONTENT_TYPE": ctype},
            )
            field = form["file"] if "file" in form else None
            if field is None or not field.filename:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"missing 'file' field\n")
                return
            filename = os.path.basename(field.filename)
            data = field.file.read()
        else:
            filename = self.headers.get("X-Filename") or f"upload_{int(time.time())}.bin"
            length = int(self.headers.get("Content-Length", 0))
            data = self.rfile.read(length)

        dest = os.path.join(INCOMING, filename)
        with open(dest, "wb") as f:
            f.write(data)
        print(f"[upload] saved {dest} ({len(data)} bytes)", flush=True)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(f"OK {filename} ({len(data)} bytes)\n".encode())

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"upload server alive. POST a file to /upload\n")

    def log_message(self, fmt, *args):
        pass  # keep stdout to just the [upload] lines above


if __name__ == "__main__":
    print(f"[upload] listening on 0.0.0.0:{PORT}, saving to {INCOMING}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
