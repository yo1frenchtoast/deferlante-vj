extends Node

## The REST API and its OpenAPI description.
##
## Kept out of the controller because none of it is about running a show: it is a
## translation layer, turning HTTP verbs into the same `VJParam.set_value()` every
## other surface goes through. The controller had grown to 866 lines with this and
## the auto-pilot inside it, and neither could be read without wading past the
## other.
##
## Everything it needs is injected, so it knows nothing about lasers or spheres.

## Injected by the controller.
var find_param: Callable
var all_params: Callable
var describe: Callable
var presets: Node
## Fires an action by name, answering false when the show has no such action. The
## one door: this used to match on its own list beside the spec, and the two came
## apart the moment an action was added.
var fire: Callable
## The one-shot actions this API advertises, named by the controller so the spec
## cannot claim one the show does not have.
var actions: Array = []
var settings_count: int = 0


func handle(method: String, path: String, body: String) -> Dictionary:
	if path == "/openapi.json":
		return {"code": 200, "body": _openapi()}

	if path == "/api/params":
		var listed: Array = []
		for p in all_params.call():
			listed.append(describe.call(p))
		return {"code": 200, "body": {"params": listed}}

	if path.begins_with("/api/params/"):
		var slug := path.substr("/api/params/".length())
		var p: VJParam = find_param.call(slug)
		if p == null:
			return {"code": 404, "body": {"error": "unknown setting", "setting": slug}}
		if method == "GET":
			return {"code": 200, "body": describe.call(p)}
		if method == "PUT" or method == "POST":
			var payload = JSON.parse_string(body)
			if typeof(payload) != TYPE_DICTIONARY or not payload.has("value"):
				return {"code": 400, "body": {"error": "expected {\"value\": number}"}}
			p.set_value(float(payload["value"]))
			return {"code": 200, "body": describe.call(p)}
		return {"code": 405, "body": {"error": "use GET or PUT"}}

	if path == "/api/presets":
		return {"code": 200, "body": {"slots": presets.used_slots(), "count": presets.SLOTS}}

	if path.begins_with("/api/presets/"):
		var rest := path.substr("/api/presets/".length()).split("/")
		var slot: int = int(rest[0])
		var verb: String = rest[1] if rest.size() > 1 else ""
		if method != "POST":
			return {"code": 405, "body": {"error": "use POST"}}
		match verb:
			"recall":
				if not presets.recall(slot):
					return {"code": 404, "body": {"error": "empty slot", "slot": slot}}
				return {"code": 200, "body": {"recalled": slot}}
			"save", "":
				if not presets.save_slot(slot):
					return {"code": 400, "body": {"error": "slot out of range", "slot": slot}}
				return {"code": 200, "body": {"saved": slot}}
			_:
				return {"code": 404, "body": {"error": "use /save or /recall"}}

	if path.begins_with("/api/actions/"):
		if method != "POST":
			return {"code": 405, "body": {"error": "use POST"}}
		var action := path.substr("/api/actions/".length())
		if not fire.call(action):
			return {"code": 404, "body": {"error": "unknown action", "action": action}}
		return {"code": 200, "body": {"triggered": action}}

	return {"code": 404, "body": {"error": "no such endpoint", "path": path}}



## The spec is generated from the settings rather than written alongside them, for
## the same reason the Chataigne module is: a hand-kept copy drifts silently.
func _openapi() -> Dictionary:
	var slugs: Array = []
	for p in all_params.call():
		slugs.append(p.slug)

	var setting_param := {
		"name": "setting",
		"in": "path",
		"required": true,
		"description": "Section and name, e.g. spot/hold",
		"schema": {"type": "string", "enum": slugs},
	}

	return {
		"openapi": "3.0.3",
		"info": {
			"title": "Deferlante",
			"version": "1.0.0",
			"description": "VJ visuals control. Every setting here is the same object the "
				+ "on-screen sliders and OSC drive, so changes made through this API show "
				+ "up everywhere at once.",
		},
		"servers": [{"url": "/"}],
		"paths": {
			"/api/params": {"get": {
				"summary": "List every setting",
				"tags": ["Settings"],
				"responses": {"200": {"description": "All settings with their bounds and current values"}},
			}},
			"/api/params/{setting}": {
				"get": {
					"summary": "Read one setting",
					"tags": ["Settings"],
					"parameters": [setting_param],
					"responses": {"200": {"description": "The setting"}, "404": {"description": "No such setting"}},
				},
				"put": {
					"summary": "Set one setting",
					"description": "The value is clamped to the setting's bounds and snapped to its step.",
					"tags": ["Settings"],
					"parameters": [setting_param],
					"requestBody": {"required": true, "content": {"application/json": {
						"schema": {"type": "object", "required": ["value"],
							"properties": {"value": {"type": "number"}}},
					}}},
					"responses": {"200": {"description": "The setting, after clamping"},
						"400": {"description": "Body was not {\"value\": number}"},
						"404": {"description": "No such setting"}},
				},
			},
			"/api/actions/{action}": {"post": {
				"summary": "Fire a one-shot action",
				"description": "Also accepts shuffle:<section> — shuffle:lasers, "
					+ "shuffle:spot — to re-roll one section instead of the show.",
				"tags": ["Actions"],
				"parameters": [{
					"name": "action", "in": "path", "required": true,
					"schema": {"type": "string", "enum": actions},
				}],
				"responses": {"200": {"description": "Fired"}, "404": {"description": "No such action"}},
			}},
		},
	}


