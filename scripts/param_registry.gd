class_name ParamRegistry
extends RefCounted

## Every setting the show has, in the order it declared them, and the one way to
## find one by its slug.
##
## The controller declares into it and hands the same object to whoever needs the
## list: the panel, the REST API, the presets, the auto-pilot, the MIDI surface and
## the pad. It used to hand each of them a pair of callables, `find_param` and
## `all_params`, assigned one by one — and a collaborator that was forgotten simply
## held a null and failed on the night. An object that is passed at construction
## cannot be forgotten in that way, and cannot disagree with another about which
## settings exist.

var _params: Array[VJParam] = []
var _by_slug := {}


## Declaration order is what the panel and every schema show, so it is kept.
func add(p: VJParam):
	assert(not _by_slug.has(p.slug), "%s is declared twice" % p.slug)
	_params.append(p)
	_by_slug[p.slug] = p


## Null when there is no such setting, so callers can tell a typo from a value.
func find(slug: String) -> VJParam:
	return _by_slug.get(slug)


func has(slug: String) -> bool:
	return _by_slug.has(slug)


func all() -> Array[VJParam]:
	return _params


func size() -> int:
	return _params.size()


## The first path segment of every slug, once each, in declaration order: the
## sections of the show as the addresses name them.
func groups() -> PackedStringArray:
	var out := PackedStringArray()
	for p in _params:
		var group := p.slug.get_slice("/", 0)
		if not out.has(group):
			out.append(group)
	return out
