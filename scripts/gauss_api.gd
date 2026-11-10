extends Node
## Authenticated adapter for the published Gauss lesson and attempt contracts.

const GAME_ID := "laboratorio-das-representacoes"
const TOKEN_KEY := "gauss.student.session"

var base_url := ""
var token := ""


func _ready() -> void:
	# Lesson credentials belong to the site host; this branch never reads a token.
	if get_parent().get("lesson_mode") == true:
		return
	base_url = OS.get_environment("GAUSS_API_URL").strip_edges().trim_suffix("/")
	token = OS.get_environment("GAUSS_STUDENT_TOKEN").strip_edges()
	if OS.has_feature("web"):
		if base_url.is_empty():
			base_url = str(JavaScriptBridge.eval("window.__GAUSS_API_URL__ || '/api'", true)).trim_suffix("/")
		if token.is_empty():
			token = str(JavaScriptBridge.eval("window.localStorage.getItem('gauss.student.session') || ''", true))


func has_session() -> bool:
	return not base_url.is_empty() and not token.is_empty()


func get_student_profile() -> Dictionary:
	return await _request("/auth/me", HTTPClient.METHOD_GET)


func get_accessibility_profile() -> Dictionary:
	return await _request("/accessibility/effective", HTTPClient.METHOD_GET)


func get_grade_three_lessons() -> Dictionary:
	return await _request("/learning/lessons?gameId=" + GAME_ID, HTTPClient.METHOD_GET)


func submit_attempt(round_data: Dictionary, choice: Variant, event_id: String, occurred_at: String) -> Dictionary:
	var payload := {
		"eventId": event_id,
		"gameId": GAME_ID,
		"type": "attempt_submitted",
		"lessonId": round_data.lessonId,
		"lessonVersion": round_data.lessonVersion,
		"phaseId": round_data.phaseId,
		"exerciseId": round_data.exerciseId,
		"choice": choice,
		"practiceMode": round_data.practiceMode,
		"occurredAt": occurred_at,
	}
	return await _request("/learning/attempts", HTTPClient.METHOD_POST, JSON.stringify(payload))


func _request(path: String, method: HTTPClient.Method, body := "") -> Dictionary:
	if not has_session():
		return {"ok": false, "message": "Não há sessão da API configurada."}
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var headers := ["Authorization: Bearer " + token, "Accept: application/json"]
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
	var started := http.request(base_url + path, headers, method, body)
	if started != OK:
		http.queue_free()
		return {"ok": false, "message": "Não foi possível iniciar a conexão com a API."}
	var completed: Array = await http.request_completed
	http.queue_free()
	var response_code: int = completed[1]
	var response_text := (completed[3] as PackedByteArray).get_string_from_utf8()
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(response_text) == OK else null
	if completed[0] != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var message := "A API não respondeu. Confira a conexão e tente novamente."
		if parsed is Dictionary and parsed.has("message"):
			message = str(parsed.message)
		return {"ok": false, "message": message, "status": response_code}
	if not parsed is Dictionary:
		return {"ok": false, "message": "A API enviou uma resposta inválida."}
	return {"ok": true, "data": parsed}
