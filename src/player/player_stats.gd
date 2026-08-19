class_name PlayerStats
extends Resource

@export var move_speed: float = 100.0
@export var gravity: float = 600.0
@export var jump_speed: float = 240.0

@export var max_health: int = 100
@export var regen_delay: float = 3.0
@export var regen_per_second: float = 20.0

@export var primary_interval: float = 0.12
@export var primary_damage: int = 10
@export var primary_bullet_speed: float = 400.0

@export var secondary_charge_time: float = 0.8
@export var secondary_cooldown: float = 2.0
@export var secondary_damage: int = 50
@export var secondary_bullet_speed: float = 300.0

@export var bullet_max_distance: float = 400.0

@export var ability_uses: int = 3
@export var ability_cooldown: float = 1.5
@export var ability_damage: int = 20
@export var ability_bullet_speed: float = 300.0
