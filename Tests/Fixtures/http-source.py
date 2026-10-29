#!/usr/bin/python3
"""Synthetic loopback source for exercising the production URLSession transport."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import base64
import json
import sys
import time
from urllib.parse import urlparse, parse_qs

mode = sys.argv[1]

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        route = urlparse(self.path)
        if mode == 'redirect':
            self.send_response(302)
            self.send_header('Location', 'http://127.0.0.1:1/should-not-follow')
            self.end_headers()
            return
        if mode in ['401', '429']:
            self.send_response(int(mode))
            self.send_header('Retry-After', '600')
            self.end_headers()
            return
        if route.path == '/auth/connect/synthetic-code':
            assert self.headers['Accept'] == 'application/json'
            if mode == 'slowpair':
                time.sleep(0.5)
            body = {'token': 'synthetic-token'}
        else:
            expected_auth = 'Basic ' + base64.b64encode(b'opencode:synthetic-token').decode('ascii')
            assert self.headers['Authorization'] == expected_auth
            if route.path == '/api/event':
                self.send_response(200)
                self.send_header('Content-Type', 'text/event-stream')
                self.end_headers()
                self.wfile.write(b'data: {"prompt":"private-canary"}\n\n')
                return
            if route.path == '/api/info':
                body = {'version': '1.0.0' if mode == 'unsupported' else '2.0.0', 'pid': 42}
            elif route.path == '/api/session/active':
                body = {'data': {'ses-child': {'type': 'running'}}}
            elif route.path == '/api/session':
                second = 'cursor' in parse_qs(route.query)
                if mode == 'laterfail' and second:
                    self.send_response(503)
                    self.end_headers()
                    return
                if mode == 'slow':
                    time.sleep(1)
                body = {'data': [{'id': 'ses-parent' if second else 'ses-child', 'title': 'Synthetic parent' if second else 'Synthetic child', 'parentID': None if second else 'ses-parent', 'projectID': 'synthetic-project', 'prompt': 'private-canary'}], 'cursor': {'next': 'next' if not second or mode == 'loop' else None}}
            elif route.path.endswith('/permission') or route.path.endswith('/form'):
                body = {'data': []}
            else:
                self.send_response(403)
                self.end_headers()
                return
        raw = json.dumps(body).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        try:
            self.wfile.write(raw)
        except BrokenPipeError:
            pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
print(server.server_port, flush=True)
server.serve_forever()
