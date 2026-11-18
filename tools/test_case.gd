class_name TestCase
extends RefCounted
## Base class for headless tests in res://tools/tests/test_*.gd.
## Every method named test_* runs on a fresh instance; it may await.

var tree: SceneTree

var _failures: PackedStringArray = []
var _nodes: Array[Node] = []


func expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func failures() -> PackedStringArray:
	return _failures


## Prints a measurement under the current test (handy when tuning).
func note(message: String) -> void:
	print("      · ", message)


## Adds a node to the scene root; it is freed by cleanup().
func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func wait_physics_frames(count: int) -> void:
	for i: int in count:
		await tree.physics_frame


func cleanup() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	await tree.process_frame
