"""Copy the four EF03MA09 rounds assigned to Leon's game for local preview.

The API remains the source of truth in authenticated play. This file is a
reviewable demo snapshot for running the Godot project without a server.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "project-gauss-api/content/lesson-drafts/gauss-ef03ma09-partes-iguais.v1.json"
TARGET = ROOT / "content/grade3_fractions_preview.json"
GAME_ID = "laboratorio-das-representacoes"

lesson = json.loads(SOURCE.read_text(encoding="utf-8"))
assert lesson["schoolYears"] == [3] and GAME_ID in lesson["gameIds"]
phase = lesson["phases"][0]
rounds = []
allowed_ids = set(phase["exerciseIds"])
allowed_ids.update(step["checkExerciseId"] for step in phase["teachingSteps"] if step.get("checkExerciseId"))
for exercise in lesson["exercises"]:
    exercise_id = exercise["id"]
    assert exercise_id in allowed_ids
    kind = exercise["round"]["kind"]
    assert kind in ("fraction_parts", "fraction_collection")
    rounds.append({
        "contractVersion": 1,
        "gameId": GAME_ID,
        "lessonId": lesson["id"],
        "lessonVersion": lesson["version"],
        "phaseId": phase["id"],
        "exerciseId": exercise_id,
        "schoolYear": 3,
        "skillId": lesson["skillId"],
        "bnccCodes": lesson["bnccCodes"],
        "practiceMode": "free_practice",
        "prompt": exercise["prompt"],
        "accessibleDescription": exercise["accessibleDescription"],
        "response": {"kind": "choice", "choices": exercise["choices"]}
            if exercise["answerMode"] == "choice" else {"kind": "number"},
        "round": exercise["round"],
        "demoFeedback": exercise.get("wrongChoiceFeedback", {}),
    })

assert len(rounds) == 4 and {r["round"]["kind"] for r in rounds} == {"fraction_parts", "fraction_collection"}
TARGET.parent.mkdir(parents=True, exist_ok=True)
TARGET.write_text(json.dumps({"source": SOURCE.name, "rounds": rounds}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Synced {len(rounds)} third-year rounds to {TARGET}")
