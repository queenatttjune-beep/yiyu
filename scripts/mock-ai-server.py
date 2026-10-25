#!/usr/bin/env python3
"""A stand-in for an OpenAI-compatible chat-completions service, for scripts/ui-tour.sh.

Replies "<style>风格：<diary text>" wrapped in a <think> block, so the tour can check that
the chosen style reached the request and that reasoning blocks are stripped. Prints
"PORT <n>" on its first line, then serves until killed.
"""
import json
import re
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length))
            system, user = body["messages"][0]["content"], body["messages"][1]["content"]
        except (ValueError, KeyError, IndexError) as error:
            self.send_error(400, f"bad request: {error}")
            return
        if not self.path.endswith("/chat/completions"):
            self.send_error(404, "not found")
            return
        user = re.sub(r"^<日记>\n|\n</日记>$", "", user)
        match = re.search(r"风格要求：(\S+?)：", system)
        style = match.group(1) if match else "未知"
        reply = {"choices": [{"message": {"role": "assistant",
                                          "content": f"<think>mock</think>{style}风格：{user}"}}]}
        payload = json.dumps(reply, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
print(f"PORT {server.server_port}", flush=True)
server.serve_forever()
