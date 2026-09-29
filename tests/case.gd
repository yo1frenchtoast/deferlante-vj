class_name TestCase
extends RefCounted

## Base of every file in `tests/cases/`. A method whose name starts with `test_` is
## run; `check()` and `same()` record a failure and carry on, so that one broken
## assertion does not hide the others.

## The show, instanced from `scenes/main.tscn`. Null in a case that declares
## `const NEEDS_SHOW := false`, so it does not depend on one by accident.
var show: Node
var failures: Array[String] = []
var checks: int = 0


func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)


func same(got, expected, message: String):
	checks += 1
	if typeof(got) != typeof(expected) or got != expected:
		failures.append("%s — expected %s, got %s" % [message, var_to_str(expected), var_to_str(got)])


# The show's doors, named once here so that a case reads as behaviour and the
# lines that reach into the show's internals are these and no others.

func params() -> Array:
	return show.registry.all()


func param(slug: String) -> VJParam:
	return show.registry.find(slug)


func osc(address: String, args: Array):
	show._on_osc_message(address, args)


func fire(name: String) -> bool:
	return show.fire_action(name)


func rest(method: String, path: String, body: String = "") -> Dictionary:
	return show.api.handle(method, path, body)
