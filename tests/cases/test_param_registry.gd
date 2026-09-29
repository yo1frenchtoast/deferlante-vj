extends TestCase

const NEEDS_SHOW := false


func _p(slug: String) -> VJParam:
	return VJParam.new(slug, 0, 1, 0.1, 0.0, func(_v): pass)


func test_finds_by_slug_and_keeps_the_order():
	var r := ParamRegistry.new()
	r.add(_p("a/one"))
	r.add(_p("b/two"))
	r.add(_p("a/three"))
	same(r.find("b/two").slug, "b/two", "found")
	check(r.find("zzz/none") == null, "a typo is null, not a crash")
	check(r.has("a/one") and not r.has("a/none"), "has")
	same(r.all().map(func(p): return p.slug), ["a/one", "b/two", "a/three"], "declaration order")
	same(r.size(), 3, "size")


func test_groups_are_the_first_segment_once_each():
	var r := ParamRegistry.new()
	for slug in ["a/one", "b/two", "a/three", "c/four"]:
		r.add(_p(slug))
	same(Array(r.groups()), ["a", "b", "c"], "in the order they first appear")
