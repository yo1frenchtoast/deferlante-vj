extends Node

## Web control surface: a static page on one port, a WebSocket on the next.
##
## Two ports rather than one, deliberately. `WebSocketPeer.accept_stream()` performs
## the HTTP handshake itself, so it needs the stream untouched — which rules out
## reading the request first to decide whether it is an upgrade. Splitting the two
## costs one port and removes the guesswork.
##
## The page drives the very same `VJParam.set_value()` as the sliders and OSC, so
## nothing here knows anything about lasers or spheres. The REST API is the same
## story: this file only routes, the controller answers.

signal set_requested(slug: String, value: float)
signal action_requested(name: String)
## A start-up setting, which lands in the config rather than in the show. Untyped
## on purpose: these are choices, switches and ports, not the single float every
## live setting is.
signal launch_set_requested(key: String, value: Variant)
## A browser has just finished its handshake and is waiting to be told what exists.
signal client_connected

@export var enabled: bool = true
## 7331 rather than 8080: the latter is registered as webcache and is the first
## port every proxy, dev server and container grabs. The WebSocket takes 7332.
@export var http_port: int = 7331
## The WebSocket sits on http_port + 1.
@export var page: String = "res://web/index.html"
@export var docs_page: String = "res://web/docs.html"

## Set by the controller. Called as (method, path, body) and expected to return
## { "code": int, "body": Variant } — the body is serialised to JSON.
var api_handler: Callable

var _http := TCPServer.new()
var _ws := TCPServer.new()
var _clients: Array[WebSocketPeer] = []
var _greeted: Array[bool] = []
var _requests: Array = []
var _page_bytes := PackedByteArray()
var _docs_bytes := PackedByteArray()
var _listening := false
## The address handed to `listen()`, which is not always the one that was asked for.
var _bind := ""


func _ready():
	if not enabled:
		set_process(false)
		return

	# Chosen at the launcher, because a port has to be settled before anything can
	# listen on it. The exported value stays as the default the launcher opens on.
	http_port = Launch.web_port

	_page_bytes = _load_page(page)
	_docs_bytes = _load_page(docs_page)

	# Loopback unless the launcher was told otherwise. Nothing here asks for a
	# password, so a surface the whole venue can reach is a decision someone makes
	# about a room, not a default one inherits.
	_bind = Launch.bind_address(Launch.web_bind)
	if _bind != Launch.web_bind:
		push_warning("Web: %s is not on this machine any more, serving on %s only"
			% [Launch.web_bind, _bind])

	var err := _http.listen(http_port, _bind)
	var err_ws := _ws.listen(http_port + 1, _bind)
	if err != OK or err_ws != OK:
		push_warning("Web: cannot listen on ports %d/%d" % [http_port, http_port + 1])
		set_process(false)
		return

	_listening = true
	print("Web: control surface at %s" % address())


func is_listening() -> bool:
	return _listening


## The address to type into a phone, or empty if nothing is being served. It is the
## address actually bound rather than the prettiest one the machine holds: on
## loopback there is no phone in the story, and saying so is the point.
func address() -> String:
	if not _listening:
		return ""
	return "http://%s:%d" % [_bind, http_port]


func _load_page(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		# In an exported build this means *.html was not included in the export
		# filter. Better to say so in the browser than to serve nothing.
		push_warning("Web: %s not found (add *.html to the export filter)" % path)
		return ("<!doctype html><meta charset=utf-8><body style=\"background:#111;color:#eee;"
			+ "font-family:sans-serif;padding:2rem\"><h1>Page missing</h1><p>"
			+ path + " was not found. Add <code>*.html</code> to the export filter.</p>"
			).to_utf8_buffer()
	return FileAccess.get_file_as_bytes(path)


func _process(_delta: float):
	_poll_http()
	_poll_websocket()


# --------------------------------------------------------------------------
# Static page
# --------------------------------------------------------------------------

func _poll_http():
	while _http.is_connection_available():
		_requests.append({"peer": _http.take_connection(), "data": PackedByteArray()})

	for i in range(_requests.size() - 1, -1, -1):
		var request = _requests[i]
		var peer: StreamPeerTCP = request["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_requests.remove_at(i)
			continue

		var available := peer.get_available_bytes()
		if available > 0:
			request["data"].append_array(peer.get_data(available)[1])

		var text: String = request["data"].get_string_from_utf8()
		var head_end := text.find("\r\n\r\n")
		if head_end == -1:
			continue

		# A PUT carries a body, so the blank line is no longer the end of the story:
		# we wait for as many bytes as Content-Length announced.
		var head := text.substr(0, head_end)
		var wanted := _content_length(head)
		var body := text.substr(head_end + 4)
		if body.length() < wanted:
			continue

		_route(peer, head, body.substr(0, wanted))
		_requests.remove_at(i)


func _content_length(head: String) -> int:
	for line in head.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			return int(line.split(":")[1].strip_edges())
	return 0


func _route(peer: StreamPeerTCP, head: String, body: String):
	var parts := head.split("\r\n")[0].split(" ")
	var method := parts[0] if parts.size() > 0 else "GET"
	var path := parts[1] if parts.size() > 1 else "/"
	path = path.split("?")[0]

	if path.begins_with("/api/") or path == "/openapi.json":
		if api_handler.is_valid():
			var answer: Dictionary = api_handler.call(method, path, body)
			_send(peer, int(answer.get("code", 200)), "application/json",
				JSON.stringify(answer.get("body", {})).to_utf8_buffer())
		else:
			_send(peer, 503, "application/json",
				'{"error":"no handler"}'.to_utf8_buffer())
		return

	match path:
		"/docs", "/docs/":
			_send(peer, 200, "text/html; charset=utf-8", _docs_bytes)
		"/", "/index.html":
			_send(peer, 200, "text/html; charset=utf-8", _page_bytes)
		_:
			_send(peer, 404, "text/plain; charset=utf-8", "not found".to_utf8_buffer())


func _send(peer: StreamPeerTCP, code: int, content_type: String, payload: PackedByteArray):
	var reason: String = {200: "OK", 400: "Bad Request", 404: "Not Found",
		405: "Method Not Allowed", 503: "Service Unavailable"}.get(code, "OK")
	var header := (
		"HTTP/1.1 %d %s\r\n" % [code, reason]
		+ "Content-Type: %s\r\n" % content_type
		+ "Content-Length: %d\r\n" % payload.size()
		# Any tool pointed at the spec — Swagger UI on another host, Postman —
		# would otherwise be blocked by the browser before reaching us.
		+ "Access-Control-Allow-Origin: *\r\n"
		+ "Access-Control-Allow-Methods: GET, PUT, POST, OPTIONS\r\n"
		+ "Access-Control-Allow-Headers: Content-Type\r\n"
		+ "Cache-Control: no-store\r\n"
		+ "Connection: close\r\n\r\n"
	)
	peer.put_data(header.to_utf8_buffer())
	peer.put_data(payload)
	peer.disconnect_from_host()




# --------------------------------------------------------------------------
# WebSocket control channel
# --------------------------------------------------------------------------

func _poll_websocket():
	while _ws.is_connection_available():
		var peer := WebSocketPeer.new()
		peer.accept_stream(_ws.take_connection())
		_clients.append(peer)
		_greeted.append(false)

	for i in range(_clients.size() - 1, -1, -1):
		var client := _clients[i]
		client.poll()
		match client.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if not _greeted[i]:
					_greeted[i] = true
					client_connected.emit()
				while client.get_available_packet_count() > 0:
					_handle(client.get_packet().get_string_from_utf8())
			WebSocketPeer.STATE_CLOSED:
				_clients.remove_at(i)
				_greeted.remove_at(i)


func _handle(text: String):
	var message = JSON.parse_string(text)
	if typeof(message) != TYPE_DICTIONARY:
		return
	match message.get("type", ""):
		"set":
			set_requested.emit(str(message.get("slug", "")), float(message.get("value", 0.0)))
		"action":
			action_requested.emit(str(message.get("name", "")))
		"launch":
			launch_set_requested.emit(str(message.get("key", "")), message.get("value"))


func broadcast(payload: Dictionary):
	if _clients.is_empty():
		return
	var text := JSON.stringify(payload)
	for client in _clients:
		if client.get_ready_state() == WebSocketPeer.STATE_OPEN:
			client.send_text(text)


func has_clients() -> bool:
	return not _clients.is_empty()
