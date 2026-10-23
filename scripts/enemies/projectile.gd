extends Node2D
## 射线扫过本帧位移，避免高速弹穿透玩家或墙体。
var velocity := Vector2.ZERO
var damage := 0.0
var lifetime := 4.0
var source: Node
var ground_wave := false

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0 or not is_instance_valid(source) or source.health <= 0 or not is_instance_valid(source.target) or source.target.health <= 0:
		queue_free()
		return
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 3)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("receive_hit"):
			hit.collider.receive_hit(damage, Vector2(signf(velocity.x) * 180, -100))
		queue_free()
		return
	global_position = next
	queue_redraw()

func _draw() -> void:
	if ground_wave:
		draw_rect(Rect2(-14, -7, 28, 14), Color("b89a60"))
	else:
		draw_line(Vector2(-12, 0), Vector2(12, 0), Color("83dce8"), 4)
