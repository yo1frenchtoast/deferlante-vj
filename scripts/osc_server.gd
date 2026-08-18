extends Node

## Minimal OSC receiver (OSC 1.0 over UDP).
##
## Godot has no built-in OSC, but the format is simple: an address, a type tag
## string, then the arguments, all padded to 4 bytes. We handle plain messages and
## bundles (Chataigne sends those when several values leave in the same frame).

signal message_received(address: String, args: Array)

@export var enabled: bool = true
@export var port: int = 9000

var _udp := PacketPeerUDP.new()
var _listening: bool = false
## The address handed to `bind()`, which is not always the one that was asked for.
var _bind := ""


func _ready():
	if not enabled:
		set_process(false)
		return

	# Chosen at the launcher, because a port has to be settled before anything can
	# bind it. The exported value stays as the default the launcher opens on.
	port = Launch.osc_port

	# Loopback unless the launcher was told otherwise. OSC carries no credentials of
	# any kind — a message that reaches the port is obeyed — so the console is let in
	# on purpose rather than by default.
	_bind = Launch.bind_address(Launch.osc_bind)
	if _bind != Launch.osc_bind:
		push_warning("OSC: %s is not on this machine any more, listening on %s only"
			% [Launch.osc_bind, _bind])

	var err := _udp.bind(port, _bind)
	if err != OK:
		push_warning("OSC: cannot listen on port %d (error %d)" % [port, err])
		set_process(false)
		return

	_listening = true
	print("OSC: listening on %s:%d" % [_bind, port])


func is_listening() -> bool:
	return _listening


## Where a console has to aim, or empty if nothing is listening. The address is worth
## saying now that it is a choice: "port 9000" no longer tells anyone whether the desk
## across the room will be heard.
func address() -> String:
	if not _listening:
		return ""
	return "%s:%d" % [_bind, port]


func _process(_delta: float):
	while _udp.get_available_packet_count() > 0:
		_read_packet(_udp.get_packet())


func _read_packet(data: PackedByteArray):
	if data.size() < 4:
		return

	# A bundle: "#bundle\0", an 8-byte timetag, then size-prefixed elements. We
	# handle them flat and ignore the timetag: when VJing you want the value now,
	# not at a scheduled time.
	if data.size() >= 16 and data.slice(0, 7).get_string_from_ascii() == "#bundle":
		var pos := 16
		while pos + 4 <= data.size():
			var size := _read_int(data, pos)
			pos += 4
			if size <= 0 or pos + size > data.size():
				return
			_read_packet(data.slice(pos, pos + size))
			pos += size
		return

	var address_end := _string_end(data, 0)
	if address_end < 0:
		return
	var address := data.slice(0, _null_at(data, 0)).get_string_from_utf8()

	var args: Array = []
	if address_end < data.size():
		args = _read_args(data, address_end)

	message_received.emit(address, args)


func _read_args(data: PackedByteArray, pos: int) -> Array:
	var tags_null := _null_at(data, pos)
	if tags_null < 0:
		return []
	var tags := data.slice(pos, tags_null).get_string_from_ascii()
	if not tags.begins_with(","):
		return []

	var cursor := _string_end(data, pos)
	var args: Array = []

	for i in range(1, tags.length()):
		match tags[i]:
			"f":
				if cursor + 4 > data.size():
					return args
				args.append(_read_float(data, cursor))
				cursor += 4
			"i":
				if cursor + 4 > data.size():
					return args
				args.append(_read_int(data, cursor))
				cursor += 4
			"s":
				var end := _null_at(data, cursor)
				if end < 0:
					return args
				args.append(data.slice(cursor, end).get_string_from_utf8())
				cursor = _string_end(data, cursor)
			"T":
				args.append(true)
			"F":
				args.append(false)
			"N":
				args.append(null)
			"I":
				# Impulse: carries no data, it is simply a trigger.
				args.append(true)
			_:
				# Unknown type: we cannot tell how far to advance, so we stop here
				# rather than return values shifted out of place.
				return args

	return args


func _null_at(data: PackedByteArray, from: int) -> int:
	var i := from
	while i < data.size():
		if data[i] == 0:
			return i
		i += 1
	return -1


## Position just past an OSC string, aligned to the next multiple of 4.
func _string_end(data: PackedByteArray, from: int) -> int:
	var end := _null_at(data, from)
	if end < 0:
		return -1
	var length := end - from + 1
	return from + length + ((4 - (length % 4)) % 4)


func _read_int(data: PackedByteArray, pos: int) -> int:
	var value := (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3]
	# Back to a signed 32-bit value.
	return value - 0x100000000 if value >= 0x80000000 else value


func _read_float(data: PackedByteArray, pos: int) -> float:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = true
	buffer.data_array = data.slice(pos, pos + 4)
	return buffer.get_float()
