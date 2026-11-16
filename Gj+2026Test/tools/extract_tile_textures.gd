@tool
extends SceneTree

func _init() -> void:
	print("--- Extractor de Tiles 16x16 sin bordes ---")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("res://assets/extracted_tiles"):
		dir.make_dir("res://assets/extracted_tiles")

	# Tiny Dungeon
	var dungeon_img := Image.load_from_file("res://assets/tilemap/tiny_dungeon/tilemap.png")
	if dungeon_img:
		print("Dungeon image cargada: ", dungeon_img.get_size())
		_extract_sub_rect(dungeon_img, Rect2i(0, 0, 16, 16), "res://assets/extracted_tiles/stone_cobble.png")
		_extract_sub_rect(dungeon_img, Rect2i(17, 0, 16, 16), "res://assets/extracted_tiles/stone_floor.png")
		_extract_sub_rect(dungeon_img, Rect2i(0, 17, 16, 16), "res://assets/extracted_tiles/stone_dark.png")
		_extract_sub_rect(dungeon_img, Rect2i(68, 68, 16, 16), "res://assets/extracted_tiles/stone_brick.png")

	# Roguelike Indoors
	var indoor_img := Image.load_from_file("res://assets/tilemap/roguelike_indoors/roguelikeIndoor_transparent.png")
	if indoor_img:
		print("Indoor image cargada: ", indoor_img.get_size())
		_extract_sub_rect(indoor_img, Rect2i(0, 0, 16, 16), "res://assets/extracted_tiles/wood_planks.png")
		_extract_sub_rect(indoor_img, Rect2i(17, 0, 16, 16), "res://assets/extracted_tiles/wood_floor_light.png")
		_extract_sub_rect(indoor_img, Rect2i(34, 0, 16, 16), "res://assets/extracted_tiles/wood_floor_dark.png")
		_extract_sub_rect(indoor_img, Rect2i(0, 34, 16, 16), "res://assets/extracted_tiles/checker_tile.png")

	print("Extracción completada con éxito.")
	quit(0)

func _extract_sub_rect(src: Image, rect: Rect2i, out_path: String) -> void:
	var sub := Image.create(rect.size.x, rect.size.y, false, src.get_format())
	sub.blit_rect(src, rect, Vector2i.ZERO)
	sub.save_png(out_path)
	print("Guardado: ", out_path)
