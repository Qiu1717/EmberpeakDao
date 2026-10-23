extends RefCounted

static func resolve(base: float, defense: float, realm: float = 1.0, skill: float = 1.0, critical: float = 1.0) -> int:
	return maxi(0, roundi(base * realm * skill * critical * 100.0 / (100.0 + maxf(defense, 0.0))))
