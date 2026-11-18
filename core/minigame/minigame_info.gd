class_name MiniGameInfo
extends Resource
## Metadata for one mini-game. Each mini-game folder has an info.tres;
## the dev main menu lists every one it finds.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
## Stored as a path (not a PackedScene) so the menu doesn't load every game.
@export_file("*.tscn") var main_scene: String = ""
@export var icon: Texture2D
