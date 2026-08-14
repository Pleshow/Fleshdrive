@tool
extends Node2D

@export var texture: Texture2D
@export var map_size := Vector2.ZERO
@export var image_size := Vector2.ZERO
@export var anchor_x := 0.0
@export var anchor_y := 0.0
@export var repeat_x := true
@export var vertical_extend_enabled := false
@export var top_height := 0.0
@export var bottom_height := 0.0

func _ready() -> void:
    queue_redraw()

func _draw() -> void:
    if texture == null or image_size.x <= 0 or image_size.y <= 0:
        return
    if not repeat_x:
        _draw_column(anchor_x)
        return
    var x: float = anchor_x + floorf(-anchor_x / image_size.x) * image_size.x
    while x < map_size.x:
        _draw_column(x)
        x += image_size.x

func _draw_column(x: float) -> void:
    if vertical_extend_enabled and top_height > 0:
        var y := anchor_y - top_height
        while y + top_height > 0:
            draw_texture_rect_region(
                texture,
                Rect2(x, y, image_size.x, top_height),
                Rect2(0, 0, image_size.x, top_height)
            )
            y -= top_height

    draw_texture_rect_region(
        texture,
        Rect2(x, anchor_y, image_size.x, image_size.y),
        Rect2(Vector2.ZERO, image_size)
    )

    if vertical_extend_enabled and bottom_height > 0:
        var y := anchor_y + image_size.y
        while y < map_size.y:
            draw_texture_rect_region(
                texture,
                Rect2(x, y, image_size.x, bottom_height),
                Rect2(
                    0,
                    image_size.y - bottom_height,
                    image_size.x,
                    bottom_height
                )
            )
            y += bottom_height
