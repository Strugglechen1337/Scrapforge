extends Resource
class_name UpgradeDefinition

@export var id: String
@export var title: String
@export_multiline var description: String
@export var socket: String
@export var visual_script: Script
@export var values: Array[float] = []
@export var visuals: Array[Texture2D] = []
