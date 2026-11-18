class_name PromptLabel
extends Label
## Shows the prompt of whichever Interactable the player is in
## (Events.interaction_prompt_changed). Hidden when there is none.

var _prompts: Dictionary = {}


func _ready() -> void:
	visible = false
	Events.interaction_prompt_changed.connect(_on_prompt_changed)


func _on_prompt_changed(source: Node, prompt_text: String) -> void:
	if prompt_text == "":
		_prompts.erase(source)
	else:
		_prompts[source] = prompt_text
	# Drop prompts whose zones were freed.
	for key: Variant in _prompts.keys():
		if not is_instance_valid(key):
			_prompts.erase(key)
	visible = not _prompts.is_empty()
	if visible:
		text = _prompts.values().back()
