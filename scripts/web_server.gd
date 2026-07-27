extends Node

## Web control surface: a static page on one port, a WebSocket on the next.
##
## Two ports rather than one, deliberately. `WebSocketPeer.accept_stream()` performs
## the HTTP handshake itself, so it needs the stream untouched — which rules out
## reading the request first to decide whether it is an upgrade. Splitting the two
## costs one port and removes the guesswork.
##
## The page drives the very same `VJParam.set_value()` as the sliders and OSC, so
## nothing here knows anything about lasers or spheres.

signal set_requested(slug: String, value: float)
signal action_requested(name: String)
## A browser has just finished its handshake and is waiting to be told what exists.
signal client_connected

@export var enabled: bool = true
@export var http_port: int = 8080
## The WebSocket sits on http_port + 1.
@export var page: String = "res://web/index.html"

var _http := TCPServer.new()
var _ws := TCPServer.new()
var _clients: Array[WebSocketPeer] = []
var _greeted: Array[bool] = []
var _requests: Array = []
var _page_bytes := PackedByteArray()
var _listening := false


func _ready():
	if not enabled:
		set_process(false)
		return

	_page_bytes = _load_page()

	var err := _http.listen(http_port)
	var err_ws := _ws.listen(http_port + 1)
	if err != OK or err_ws != OK:
		push_warning("Web: cannot listen on ports %d/%d" % [http_port, http_port + 1])
		set_process(false)
		return

	_listening = true
	for address in IP.get_local_addresses():
		if address.begins_with("192.") or address.begins_with("10.") or address.begins_with("172."):
			print("Web: control surface at http://%s:%d" % [address, http_port])


func is_listening() -> bool:
	return _listening


func _load_page() -> PackedByteArray:
	if not FileAccess.file_exists(page):
		# In an exported build this means *.html was not included in the export
		# filter. Better to say so in the browser than to serve nothing.
		push_warning("Web: %s not found (add *.html to the export filter)" % page)
		return ("<!doctype html><meta charset=utf-8><body style=\"background:#111;color:#eee;"
			+ "font-family:sans-serif;padding:2rem\"><h1>Page missing</h1><p>"
			+ page + " was not found. Add <code>*.html</code> to the export filter.</p>"
			).to_utf8_buffer()
	return FileAccess.get_file_as_bytes(page)


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

		# We do not parse the request at all: there is exactly one page to serve.
		# Waiting for the blank line only tells us the browser has finished asking.
		if request["data"].get_string_from_utf8().find("\r\n\r\n") != -1:
			_serve_page(peer)
			_requests.remove_at(i)


func _serve_page(peer: StreamPeerTCP):
	var header := (
		"HTTP/1.1 200 OK\r\n"
		+ "Content-Type: text/html; charset=utf-8\r\n"
		+ "Content-Length: %d\r\n" % _page_bytes.size()
		+ "Cache-Control: no-store\r\n"
		+ "Connection: close\r\n\r\n"
	)
	peer.put_data(header.to_utf8_buffer())
	peer.put_data(_page_bytes)
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


func broadcast(payload: Dictionary):
	if _clients.is_empty():
		return
	var text := JSON.stringify(payload)
	for client in _clients:
		if client.get_ready_state() == WebSocketPeer.STATE_OPEN:
			client.send_text(text)


func has_clients() -> bool:
	return not _clients.is_empty()
