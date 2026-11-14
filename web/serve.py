#!/usr/bin/env python3
"""Servidor local para testar o export web (web/dist/) antes de publicar.

Envia os mesmos cabeçalhos COOP/COEP que o vercel.json configura na Vercel
(sem eles a versão com threads não carrega) e desliga o cache, para cada novo
export aparecer ao recarregar a página.

Uso:  python3 web/serve.py [porta]     (padrão: 8060)
"""
import http.server
import sys
from functools import partial
from pathlib import Path

DIST = Path(__file__).resolve().parent / "dist"


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


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
    if not (DIST / "index.html").exists():
        sys.exit("web/dist/index.html não existe. Rode web/export.sh primeiro.")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=str(DIST)))
    print(f"Servindo {DIST} em http://localhost:{port}  (Ctrl+C para parar)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
