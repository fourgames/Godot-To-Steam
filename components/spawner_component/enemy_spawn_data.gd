extends Resource
class_name EnemySpawnData


@export var time_start : int = 0
@export var time_end : int = 0
@export var enemy_scene: PackedScene
@export var total_enemies: int = 0

var spawned_enemies: int = 0
