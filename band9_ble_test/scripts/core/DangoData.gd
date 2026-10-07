## Datos de un dango. El PEDIDO del gato y el dango CONSTRUIDO usan exactamente
## la misma estructura, así se comparan directamente:
##   {"lower": "verde", "middle": "blanca", "upper": "rosa", "sauce": true}
## Un hueco vacío es "".
extends RefCounted

const COLORS := ["verde", "blanca", "rosa"]
const SLOTS := ["lower", "middle", "upper"]

static func make(lower: String = "", middle: String = "", upper: String = "", sauce: bool = false) -> Dictionary:
	return {"lower": lower, "middle": middle, "upper": upper, "sauce": sauce}

static func empty() -> Dictionary:
	return make()

static func traditional(sauce: bool = false) -> Dictionary:
	return make("verde", "blanca", "rosa", sauce)

static func ball_count(d: Dictionary) -> int:
	var n := 0
	for s in SLOTS:
		if d[s] != "":
			n += 1
	return n

static func is_complete(d: Dictionary) -> bool:
	return ball_count(d) == 3

static func equals(a: Dictionary, b: Dictionary) -> bool:
	for s in SLOTS:
		if a[s] != b[s]:
			return false
	return a["sauce"] == b["sauce"]

## Pedido según la complejidad del momento (se introduce poco a poco):
##   0 tradicional (con o sin salsa) · 1 permutaciones de los 3 colores · 2+ cualquiera de las 54.
static func random_order(complexity: int) -> Dictionary:
	var sauce := randf() < 0.5
	if complexity <= 0:
		return traditional(sauce)
	if complexity == 1:
		var c: Array = COLORS.duplicate()
		c.shuffle()
		return make(c[0], c[1], c[2], sauce)
	return make(COLORS.pick_random(), COLORS.pick_random(), COLORS.pick_random(), sauce)

static func describe(d: Dictionary) -> String:
	return "%s/%s/%s%s" % [d["lower"], d["middle"], d["upper"], " +salsa" if d["sauce"] else ""]
