class_name LevelGridNode
extends Node
## Puts a level's LevelGrid in the scene so AI can find it.

@export var grid: LevelGrid


func _enter_tree() -> void:
	add_to_group(Groups.LEVEL_GRID)


## The grid of the current level, or null.
static func find_grid(tree: SceneTree) -> LevelGrid:
	var node := tree.get_first_node_in_group(Groups.LEVEL_GRID) as LevelGridNode
	return node.grid if node != null else null
