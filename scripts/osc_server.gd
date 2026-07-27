extends Node

## Récepteur OSC minimal (OSC 1.0 sur UDP).
##
## Godot n'a pas d'OSC intégré, mais le format est simple : une adresse, une
## chaîne de types, puis les arguments, le tout aligné sur 4 octets. On gère les
## messages seuls et les bundles (Chataigne en envoie quand plusieurs valeurs
## partent dans la même image).

signal message_received(address: String, args: Array)

@export var enabled: bool = true
@export var port: int = 9000

var _udp := PacketPeerUDP.new()
var _listening: bool = false


func _ready():
	if not enabled:
		set_process(false)
		return

	var err := _udp.bind(port)
	if err != OK:
		push_warning("OSC : impossible d'écouter sur le port %d (erreur %d)" % [port, err])
		set_process(false)
		return

	_listening = true
	print("OSC : à l'écoute sur le port %d" % port)


func is_listening() -> bool:
	return _listening


func _process(_delta: float):
	while _udp.get_available_packet_count() > 0:
		_read_packet(_udp.get_packet())


func _read_packet(data: PackedByteArray):
	if data.size() < 4:
		return

	# Un bundle : "#bundle\0", un timetag de 8 octets, puis une suite de blocs
	# préfixés par leur taille. On les traite à plat, sans gérer le timetag :
	# en VJ on veut la valeur tout de suite, pas à une date programmée.
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
				# Impulsion : pas de donnée, c'est un simple déclencheur.
				args.append(true)
			_:
				# Type inconnu : on ne sait pas de combien avancer, on s'arrête là
				# plutôt que de renvoyer des valeurs décalées.
				return args

	return args


func _null_at(data: PackedByteArray, from: int) -> int:
	var i := from
	while i < data.size():
		if data[i] == 0:
			return i
		i += 1
	return -1


## Position juste après une chaîne OSC, alignée sur le prochain multiple de 4.
func _string_end(data: PackedByteArray, from: int) -> int:
	var end := _null_at(data, from)
	if end < 0:
		return -1
	var length := end - from + 1
	return from + length + ((4 - (length % 4)) % 4)


func _read_int(data: PackedByteArray, pos: int) -> int:
	var value := (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3]
	# Repasser en signé sur 32 bits.
	return value - 0x100000000 if value >= 0x80000000 else value


func _read_float(data: PackedByteArray, pos: int) -> float:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = true
	buffer.data_array = data.slice(pos, pos + 4)
	return buffer.get_float()
