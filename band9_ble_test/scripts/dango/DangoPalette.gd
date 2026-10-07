@tool
## Recurso editable con las texturas del dango. Cámbialas en el Inspector
## (resources/dango_paleta.tres) y todos los dangos, pedidos y cuencos se actualizan.
class_name DangoPalette
extends Resource

@export var verde: Texture2D
@export var blanca: Texture2D
@export var rosa: Texture2D
@export var salsa: Texture2D

func texture_for(color_id: String) -> Texture2D:
	match color_id:
		"verde":
			return verde
		"blanca":
			return blanca
		"rosa":
			return rosa
		"salsa":
			return salsa
	return null
