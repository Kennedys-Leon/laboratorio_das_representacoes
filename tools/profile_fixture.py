from http.server import BaseHTTPRequestHandler, HTTPServer
import json
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get('Authorization') != 'Bearer local-test':
            self.send_response(401); self.end_headers(); return
        profile=dict(version=1,textScale=2,contrast='high',reducedMotion=True,focusMode=True,pace='untimed',soundEffects='off',audioAssistance=False,captions=True,preferredInput='keyboard',accessibleActivity='game')
        data=profile if self.path=='/accessibility/effective' else dict(role='student',displayName='Teste')
        self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header("Content-Length", str(len(json.dumps(data).encode()))); self.end_headers(); self.wfile.write(json.dumps(data).encode())
    def log_message(self,*args): pass
HTTPServer(('127.0.0.1',18976),Handler).serve_forever()
