extends Node

@export var url: String = "https://against-them-server.onrender.com/"
var http_request: HTTPRequest

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	var err = http_request.request(url)
	if err != OK:
		push_error("HTTP request failed to start: %s" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != OK or response_code != 200:
		push_warning("HTTP request failed: result=%s response_code=%s" % [result, response_code])
		return

	var latest_system_version: String = body.get_string_from_utf8()
	var verdict: Dictionary = _check_versions_and_verdict(latest_system_version, global.GAME_VERSION)
	
	if verdict.update_available:
		var update_notification: Control = preload("res://Scenes/HUD/new_game_version_available_notification.tscn").instantiate()
		update_notification.setAsMustUpdate = verdict.must_be_updated
		$"../UI".add_child.call_deferred(update_notification)

func _check_versions_and_verdict(latest_system_version: String, current_system_version: String) -> Dictionary:
	var lsv: Array[int]
	for part in latest_system_version.split("."):
		lsv.append(int(part))
	
	var csv: Array[int]
	for part in current_system_version.split("."):
		csv.append(int(part))
	
	var verdict: Dictionary = {
		update_available = false,
		must_be_updated = false
	}
	
	for i in range(3):
		if lsv[i] != csv[i]:
			verdict.update_available = true
	
	if lsv[0] != csv[0] or lsv[1] != csv[1]:
		verdict.must_be_updated = true
	
	return verdict
