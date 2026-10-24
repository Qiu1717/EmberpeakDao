extends Resource

@export var stages: Array[Dictionary] = []

func current(realm: int, subrealm: int) -> Dictionary:
	for stage: Dictionary in stages:
		if stage.get("realm", -1) == realm and stage.get("subrealm", -1) == subrealm:
			return stage.duplicate(true) if _valid_stage(stage) else {}
	return {}

func next(realm: int, subrealm: int) -> Dictionary:
	if current(realm, subrealm).is_empty():
		return {}
	return current(realm + 1, 0) if subrealm == 3 else current(realm, subrealm + 1)

func _valid_stage(stage: Dictionary) -> bool:
	for key in ["realm", "subrealm", "max_health", "max_qi", "required_spirit"]:
		if typeof(stage.get(key)) != TYPE_INT or stage[key] < 0:
			return false
	if stage.subrealm > 3 or stage.max_health == 0 or stage.max_qi == 0:
		return false
	if typeof(stage.get("name")) != TYPE_STRING or stage.name.is_empty() or typeof(stage.get("material_id")) != TYPE_STRING:
		return false
	var multiplier: Variant = stage.get("attack_multiplier")
	return (typeof(multiplier) == TYPE_FLOAT or typeof(multiplier) == TYPE_INT) and is_finite(float(multiplier)) and multiplier > 0
