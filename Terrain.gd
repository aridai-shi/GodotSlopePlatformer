extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	for child in get_children():
		if child is SS2D_Shape_Closed:
			var node:SS2D_Shape_Closed = child
			add_collision(node)
			
			
func add_collision(shape:SS2D_Shape_Closed):
	if not shape.get_parent() is StaticBody2D:
		var static_body: StaticBody2D = StaticBody2D.new()
		var t: Transform2D = shape.transform
		static_body.position = shape.position
		shape.position = Vector2.ZERO
		shape.get_parent().add_child(static_body)
		static_body.owner = get_tree().get_root()
		shape.get_parent().remove_child(shape)
		static_body.add_child(shape)
		shape.owner = get_tree().get_root()
		var poly: CollisionPolygon2D = CollisionPolygon2D.new()
		static_body.add_child(poly)
		poly.owner = get_tree().get_root()
		# TODO: Make this a option at some point
		poly.modulate.a = 0.3
		poly.visible = true
		shape.collision_polygon_node_path = shape.get_path_to(poly)
		shape.set_as_dirty()
