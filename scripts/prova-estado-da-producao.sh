#!/usr/bin/env bash
# Run the real diagnostic and curl against a loopback HTTP server, never a GPU.
set -euo pipefail
command -v python3 >/dev/null || { echo 'prova-estado: python3 is required.' >&2; exit 2; }
command -v curl >/dev/null || { echo 'prova-estado: curl is required.' >&2; exit 2; }
command -v jq >/dev/null || { echo 'prova-estado: jq is required.' >&2; exit 2; }

python3 - "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/estado-da-producao.sh" "$BASH" <<'PY'
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

script, bash = sys.argv[1:]
response = {}
requests = []


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        requests.append((self.path, self.rfile.read(int(self.headers['Content-Length']))))
        if response['status'] is None:
            self.connection.shutdown(socket.SHUT_RDWR)
            self.connection.close()
            return
        self.send_response(response['status'])
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(response['body'].encode())

    def log_message(self, *args):
        pass


server = HTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
env = dict(os.environ, OLLAMA_HOST=f'http://127.0.0.1:{server.server_port}',
           MODELO='diagnostic-test:latest', NO_PROXY='127.0.0.1', no_proxy='127.0.0.1')
env.pop('SHVIA_WEB_ENV', None)
valid = {'parameters': 'temperature 1\nnum_ctx 32768\n', 'system': '',
         'details': {'parent_model': 'base:latest'}}
cases = [
    ('configured capacity', 200, valid, 0),
    ('optional metadata omitted', 200, {'parameters': 'num_ctx 32768\n'}, 0),
    ('nonempty system', 200, dict(valid, system='Fallback persona'), 0),
    ('smaller configured capacity', 200, dict(valid, parameters='num_ctx 4096\n'), 0),
    ('model missing', 404, {'error': 'model not found: num_ctx 32768'}, 2),
    ('HTTP server error with valid-looking fields', 500, valid, 2),
    ('redirect', 302, valid, 2),
    ('empty response', 204, '', 2),
    ('non-JSON containing a context', 200, 'not json: num_ctx 32768', 2),
    ('API error with valid-looking fields', 200, dict(valid, error='unavailable'), 2),
    ('array instead of object', 200, [valid], 2),
    ('null instead of object', 200, None, 2),
    ('multiple JSON responses', 200, json.dumps(valid) + '\n' + json.dumps(valid), 2),
    ('context only in prompt/template text', 200,
     {'system': 'num_ctx 32768', 'template': 'num_ctx 32768', 'modelfile': 'PARAMETER num_ctx 32768'}, 2),
    ('context not configured', 200, dict(valid, parameters='temperature 1\n'), 2),
    ('parameters has wrong type', 200, dict(valid, parameters={'num_ctx': 32768}), 2),
    ('system has wrong type', 200, dict(valid, system=True), 2),
    ('details has wrong type', 200, dict(valid, details=[]), 2),
    ('parent model has wrong type', 200, dict(valid, details={'parent_model': 32768}), 2),
    ('disconnected response', None, '', 2),
]
for value in ('0', '-1', '32768junk', '32.768', '"32768"', '32768\nnum_ctx 4096'):
    cases.append(('invalid context ' + repr(value), 200, dict(valid, parameters='num_ctx ' + value), 2))

failures = []
try:
    for name, status, body, expected in cases:
        response.update(status=status, body=body if isinstance(body, str) else json.dumps(body))
        result = subprocess.run([bash, script], env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        if result.returncode != expected or (expected != 0 and '✅' in output):
            failures.append(f'{name}: expected exit {expected} without a false green; got {result.returncode}\n{output}')
        if name == 'configured capacity' and ('32768' not in output or 'base:latest' not in output or '✅' not in output):
            failures.append('configured capacity: valid model details were lost\n' + output)
        if name == 'configured capacity' and 'SYSTEM no Modelfile  não' not in output:
            failures.append('an empty SYSTEM was reported as present\n' + output)
        if name == 'nonempty system' and 'SYSTEM no Modelfile  sim' not in output:
            failures.append('the SYSTEM presence was lost\n' + output)
        if name == 'smaller configured capacity' and ('4096' not in output or '✅' in output):
            failures.append('smaller configured capacity: incorrect capacity verdict\n' + output)
    for path, body in requests:
        if path != '/api/show' or json.loads(body) != {'model': 'diagnostic-test:latest'}:
            failures.append('the diagnostic changed the requested endpoint or model')
    if len(requests) != len(cases):
        failures.append('not every case reached the real HTTP server')

    # This is the only application configuration read: a disposable one-line fixture.
    with tempfile.TemporaryDirectory(prefix='shvia-diagnostic-') as temporary:
        flag = Path(temporary) / 'app-config'
        flag.write_text('OLLAMA_PRESERVE_MODELFILE_SYSTEM=false\n')
        response.update(status=200, body=json.dumps(valid))
        result = subprocess.run([bash, script], env=dict(env, SHVIA_WEB_ENV=str(flag)),
                                capture_output=True, text=True, timeout=25)
        if result.returncode or 'Fase 1' not in result.stdout:
            failures.append('the optional application flag stopped working\n' + result.stdout + result.stderr)
        # A missing parser must refuse before making a request, never fall back to text matching.
        tools = Path(temporary) / 'bin'
        tools.mkdir()
        (tools / 'curl').symlink_to(shutil.which('curl'))
        request_count = len(requests)
        result = subprocess.run([bash, script], env=dict(env, PATH=str(tools)),
                                capture_output=True, text=True, timeout=25)
        if result.returncode != 2 or 'jq' not in result.stderr or len(requests) != request_count:
            failures.append('missing jq did not refuse before the request\n' + result.stdout + result.stderr)
    missing_host = dict(env)
    missing_host.pop('OLLAMA_HOST')
    result = subprocess.run([bash, script], env=missing_host, capture_output=True, text=True, timeout=25)
    if result.returncode != 1:
        failures.append('missing OLLAMA_HOST must retain exit 1')
finally:
    server.shutdown()
    server.server_close()
    thread.join()

if failures:
    print('\n'.join(failures), file=sys.stderr)
    raise SystemExit(1)
print(f'prova-estado: {len(cases) + 3} cases passed through the real diagnostic; loopback only.')
PY
