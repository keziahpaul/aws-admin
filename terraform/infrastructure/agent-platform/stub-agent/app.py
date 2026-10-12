"""Stub agent image.

Placeholder container used to seed empty ECR repositories so that
image-consuming infrastructure (ECS services, Bedrock AgentCore runtimes)
can be created before a real agent image exists. It implements the minimal
Bedrock AgentCore runtime contract:

  - GET  /ping          -> 200 (health probe)
  - POST /invocations   -> 200 (stub response)

It also simply stays running, which satisfies an ECS (Socket Mode) task
whose only requirement is that the container does not exit.

The real agent image (built by the agent's own app pipeline and pushed as
`:latest`) replaces this stub on the next deploy.
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8080


class Handler(BaseHTTPRequestHandler):
    def _respond(self, status: int, body: bytes = b"") -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 (http.server naming)
        if self.path == "/ping":
            self._respond(200, b'{"status":"healthy","stub":true}')
        else:
            self._respond(404, b'{"error":"not found"}')

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/invocations":
            # Drain the request body if present, then return a stub payload.
            length = int(self.headers.get("Content-Length", 0) or 0)
            if length:
                self.rfile.read(length)
            self._respond(
                200,
                b'{"stub":true,"message":"stub agent - replace with real image"}',
            )
        else:
            self._respond(404, b'{"error":"not found"}')

    def log_message(self, *_args) -> None:  # silence default request logging
        return


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"stub-agent listening on 0.0.0.0:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
