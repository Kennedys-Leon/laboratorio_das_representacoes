"""Small local HTTP fixture for verifying the Godot/API contract end to end."""

import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse

SOURCE = Path(__file__).resolve().parents[2] / "project-gauss-api/content/lesson-drafts/gauss-ef03ma09-partes-iguais.v1.json"
LESSON = json.loads(SOURCE.read_text(encoding="utf-8"))
BY_ID = {exercise["id"]: exercise for exercise in LESSON["exercises"]}
LOG = Path("/tmp/gauss-grade3-api-attempts.jsonl")
LOG.write_text("")


class Handler(BaseHTTPRequestHandler):
    def send_json(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authenticated(self):
        return self.headers.get("Authorization") == "Bearer grade3-test"

    def do_GET(self):
        if not self.authenticated():
            return self.send_json(401, {"message": "Sessão inválida."})
        path = urlparse(self.path).path
        if path == "/learning/lessons":
            lesson = {
                key: value for key, value in LESSON.items()
                if key not in ("exercises",)
            }
            lesson["exercises"] = [{
                key: value for key, value in exercise.items()
                if key not in ("correctChoice", "correctAnswer", "wrongChoiceFeedback")
            } for exercise in LESSON["exercises"]]
            return self.send_json(200, {"schoolYear": 3, "lessons": [lesson]})
        if path == "/accessibility/effective":
            return self.send_json(200, {"textScale": 1.25, "contrast": "standard", "reducedMotion": True, "focusMode": False, "soundEffects": "off"})
        self.send_json(404, {"message": "Rota desconhecida."})

    def do_POST(self):
        if not self.authenticated():
            return self.send_json(401, {"message": "Sessão inválida."})
        if urlparse(self.path).path != "/learning/attempts":
            return self.send_json(404, {"message": "Rota desconhecida."})
        data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        exercise = BY_ID[data["exerciseId"]]
        assert data["gameId"] == "laboratorio-das-representacoes"
        assert data["lessonId"] == LESSON["id"] and data["lessonVersion"] == LESSON["version"]
        assert data["phaseId"] == LESSON["phases"][0]["id"]
        assert data["practiceMode"] == "free_practice" and data["type"] == "attempt_submitted"
        assert len(data["eventId"]) == 36 and data["occurredAt"].endswith("Z")
        with LOG.open("a") as output:
            output.write(json.dumps(data, ensure_ascii=False) + "\n")
        correct = data["choice"] == exercise.get("correctChoice", exercise.get("correctAnswer"))
        feedback = None if correct else exercise["wrongChoiceFeedback"].get(str(data["choice"]), exercise["wrongChoiceFeedback"].get("*"))
        self.send_json(200, {"eventId": data["eventId"], "exerciseId": data["exerciseId"], "correct": correct, "feedback": feedback})


HTTPServer(("127.0.0.1", 38961), Handler).serve_forever()
