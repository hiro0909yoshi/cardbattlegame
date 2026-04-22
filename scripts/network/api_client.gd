extends Node

class_name ApiClient

signal registered(user_id: String, access_token: String, refresh_token: String)
signal login_success(access_token: String, refresh_token: String)
signal login_failed(error: String)
signal token_refreshed(access_token: String)
signal deck_saved(success: bool, error: String)

var _base_url: String = ""
var _http: HTTPRequest
var _current_request_type: String = ""
var _current_user_id: String = ""


func _ready() -> void:
	if _base_url == "":
		_base_url = NetConfig.get_api_url()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func set_base_url(url: String) -> void:
	_base_url = url


func guest_register(user_id: String, display_name: String) -> void:
	_current_request_type = "register"
	_current_user_id = user_id
	var body: String = JSON.stringify({"user_id": user_id, "display_name": display_name})
	_http.request(_base_url + "/api/auth/guest/register", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func guest_login(user_id: String) -> void:
	_current_request_type = "login"
	var body: String = JSON.stringify({"user_id": user_id})
	_http.request(_base_url + "/api/auth/guest/login", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func refresh_token(ref_token: String) -> void:
	_current_request_type = "refresh"
	var body: String = JSON.stringify({"refresh_token": ref_token})
	_http.request(_base_url + "/api/auth/refresh", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


## デッキをサーバーに保存（PUT /api/player/decks）
## cards: カードIDの配列（重複あり、例: [1,1,2,2,3,...]）
func save_deck(access_token: String, slot_index: int, deck_name: String, cards: Array) -> void:
	_current_request_type = "save_deck"
	var body: String = JSON.stringify({
		"slot_index": slot_index,
		"deck_name": deck_name,
		"cards": cards,
	})
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + access_token,
	]
	_http.request(_base_url + "/api/player/decks", headers, HTTPClient.METHOD_PUT, body)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var json: JSON = JSON.new()
	var data: Dictionary = {}
	if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary:
		data = json.data

	var req_type: String = _current_request_type
	_current_request_type = ""

	match req_type:
		"register":
			if response_code == 201:
				registered.emit(_current_user_id, data.get("access_token", ""), data.get("refresh_token", ""))
			else:
				login_failed.emit("Register failed: %d" % response_code)
		"login":
			if response_code == 200:
				login_success.emit(data.get("access_token", ""), data.get("refresh_token", ""))
			else:
				login_failed.emit("Login failed: %d" % response_code)
		"refresh":
			if response_code == 200:
				token_refreshed.emit(data.get("access_token", ""))
			else:
				login_failed.emit("Refresh failed: %d" % response_code)
		"save_deck":
			if response_code == 200 or response_code == 201 or response_code == 204:
				deck_saved.emit(true, "")
			else:
				deck_saved.emit(false, "SaveDeck failed: %d" % response_code)
