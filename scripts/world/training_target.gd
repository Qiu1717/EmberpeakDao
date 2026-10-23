extends CharacterBody2D
## 可受击木桩，无敌人 AI、奖励或成长数据。
const Damage := preload("res://scripts/combat/damage.gd")
var health := 200
var flash := 0.0

func _physics_process(delta: float) -> void:
	velocity.y += 1500 * delta
	velocity.x = move_toward(velocity.x, 0, 1800 * delta)
	move_and_slide()
	flash = maxf(0, flash - delta)
	queue_redraw()

func receive_hit(amount: float, impulse: Vector2) -> bool:
	if health <= 0:
		return false
	health = maxi(0, health - Damage.resolve(amount, 0))
	velocity = impulse
	flash = 0.20
	return true

func _draw() -> void:
	draw_rect(Rect2(-18, -60, 36, 60), Color("9e302a") if flash > 0 else Color("b89a60"))
	draw_line(Vector2(-30, -40), Vector2(30, -40), Color("d7e2e2"), 6)
	draw_rect(Rect2(-24, -75, 48, 5), Color("315461"))
	draw_rect(Rect2(-24, -75, 48.0 * health / 200.0, 5), Color("83dce8"))
