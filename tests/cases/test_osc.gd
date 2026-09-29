extends TestCase

const NEEDS_SHOW := false


static func _padded(text: String) -> PackedByteArray:
	var bytes := text.to_utf8_buffer()
	bytes.append(0)
	while bytes.size() % 4 != 0:
		bytes.append(0)
	return bytes


static func message(address: String, tags: String, payload: PackedByteArray) -> PackedByteArray:
	var out := _padded(address)
	out.append_array(_padded(tags))
	out.append_array(payload)
	return out


static func be_float(value: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, value)
	b.reverse()
	return b


static func be_int(value: int) -> PackedByteArray:
	var b := be_float(0.0)
	b.encode_s32(0, value)
	b.reverse()
	return b


func _collect(packet: PackedByteArray) -> Array:
	var server: Node = load("res://scripts/osc_server.gd").new()
	var got := []
	server.message_received.connect(func(a, args): got.append([a, args]))
	server._read_packet(packet)
	server.free()
	return got


func test_float_message():
	var got := _collect(message("/deferlante/global/speed", ",f", be_float(1.5)))
	same(got, [["/deferlante/global/speed", [1.5]]], "one float")


func test_mixed_arguments():
	var payload := be_int(7)
	payload.append_array(be_float(0.25))
	payload.append_array(_padded("hi"))
	var got := _collect(message("/a", ",ifs", payload))
	same(got, [["/a", [7, 0.25, "hi"]]], "int, float, string")


func test_flags_and_no_arguments():
	same(_collect(message("/a", ",T", PackedByteArray())), [["/a", [true]]], "true")
	same(_collect(message("/a", ",", PackedByteArray())), [["/a", []]], "empty tag string")


func test_bundle_is_flattened():
	var one := message("/one", ",f", be_float(1.0))
	var two := message("/two", ",f", be_float(2.0))
	var bundle := _padded("#bundle")
	bundle.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 1]))
	for m in [one, two]:
		bundle.append_array(be_int(m.size()))
		bundle.append_array(m)
	var got := _collect(bundle)
	same(got, [["/one", [1.0]], ["/two", [2.0]]], "both elements, in order")


func test_garbage_is_ignored():
	same(_collect(PackedByteArray([1, 2])), [], "too short")
	var truncated := message("/a", ",f", PackedByteArray([0, 0]))
	same(_collect(truncated), [["/a", []]], "a float cut short yields no value")
