"""Servidor COOP/COEP para a build de teste. Uso: python3 -I serve.py <dir> <porta>"""
import http.server
import sys
from functools import partial


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".pck": "application/octet-stream",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *a):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[2])), partial(Handler, directory=sys.argv[1]))
server.serve_forever()
