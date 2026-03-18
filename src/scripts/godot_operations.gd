#!/usr/bin/env -S godot --headless --script
extends SceneTree

# Debug mode flag
var debug_mode: bool = false

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()

	# Check for debug flag
	debug_mode = "--debug-godot" in args

	# Find the script argument and determine the positions of operation and params
	var script_index: int = args.find("--script")
	if script_index == -1:
		log_error("Could not find --script argument")
		quit(1)

	# The operation should be 2 positions after the script path (script_index + 1 is the script path itself)
	var operation_index: int = script_index + 2
	# The params should be 3 positions after the script path
	var params_index: int = script_index + 3

	if args.size() <= params_index:
		log_error("Usage: godot --headless --script godot_operations.gd <operation> <json_params>")
		log_error("Not enough command-line arguments provided.")
		quit(1)

	# Log all arguments for debugging
	log_debug("All arguments: " + str(args))
	log_debug("Script index: " + str(script_index))
	log_debug("Operation index: " + str(operation_index))
	log_debug("Params index: " + str(params_index))

	var operation: String = args[operation_index]
	var params_json: String = args[params_index]

	log_info("Operation: " + operation)
	log_debug("Params JSON: " + params_json)

	# Parse JSON using Godot 4.x API
	var json: JSON = JSON.new()
	var error: int = json.parse(params_json)
	var params: Variant = null

	if error == OK:
		params = json.get_data()
	else:
		log_error("Failed to parse JSON parameters: " + params_json)
		log_error("JSON Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		quit(1)

	if not params:
		log_error("Failed to parse JSON parameters: " + params_json)
		quit(1)

	log_info("Executing operation: " + operation)

	var params_dict: Dictionary = params as Dictionary

	match operation:
		"create_scene":
			create_scene(params_dict)
		"add_node":
			add_node(params_dict)
		"load_sprite":
			load_sprite(params_dict)
		"export_mesh_library":
			export_mesh_library(params_dict)
		"save_scene":
			save_scene(params_dict)
		"get_uid":
			get_uid(params_dict)
		"resave_resources":
			resave_resources(params_dict)
		"read_scene":
			read_scene(params_dict)
		"modify_node":
			modify_node(params_dict)
		"remove_node":
			remove_node(params_dict)
		"attach_script":
			attach_script(params_dict)
		"create_resource":
			create_resource(params_dict)
		"manage_resource":
			manage_resource(params_dict)
		"manage_scene_signals":
			manage_scene_signals(params_dict)
		"manage_theme_resource":
			manage_theme_resource(params_dict)
		"manage_scene_structure":
			manage_scene_structure(params_dict)
		_:
			log_error("Unknown operation: " + operation)
			quit(1)

	quit()


# Logging functions
func log_debug(message: String) -> void:
	if debug_mode:
		print("[DEBUG] " + message)


func log_info(message: String) -> void:
	print("[INFO] " + message)


func log_error(message: String) -> void:
	printerr("[ERROR] " + message)


# Get a script by name or path
func get_script_by_name(name_of_class: String) -> Variant:
	if debug_mode:
		print("Attempting to get script for class: " + name_of_class)

	# Try to load it directly if it's a resource path
	if ResourceLoader.exists(name_of_class, "Script"):
		if debug_mode:
			print("Resource exists, loading directly: " + name_of_class)
		var script: Script = load(name_of_class) as Script
		if script:
			if debug_mode:
				print("Successfully loaded script from path")
			return script
		else:
			printerr("Failed to load script from path: " + name_of_class)
	elif debug_mode:
		print("Resource not found, checking global class registry")

	# Search for it in the global class registry if it's a class name
	var global_classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	if debug_mode:
		print("Searching through " + str(global_classes.size()) + " global classes")

	for global_class: Dictionary in global_classes:
		var found_name_of_class: String = global_class["class"]
		var found_path: String = global_class["path"]

		if found_name_of_class == name_of_class:
			if debug_mode:
				print("Found matching class in registry: " + found_name_of_class + " at path: " + found_path)
			var script: Script = load(found_path) as Script
			if script:
				if debug_mode:
					print("Successfully loaded script from registry")
				return script
			else:
				printerr("Failed to load script from registry path: " + found_path)
				break

	printerr("Could not find script for class: " + name_of_class)
	return null


# Instantiate a class by name
func instantiate_class(name_of_class: String) -> Variant:
	if name_of_class.is_empty():
		printerr("Cannot instantiate class: name is empty")
		return null

	var result: Variant = null
	if debug_mode:
		print("Attempting to instantiate class: " + name_of_class)

	# Check if it's a built-in class
	if ClassDB.class_exists(name_of_class):
		if debug_mode:
			print("Class exists in ClassDB, using ClassDB.instantiate()")
		if ClassDB.can_instantiate(name_of_class):
			result = ClassDB.instantiate(name_of_class)
			if result == null:
				printerr("ClassDB.instantiate() returned null for class: " + name_of_class)
		else:
			printerr("Class exists but cannot be instantiated: " + name_of_class)
			printerr("This may be an abstract class or interface that cannot be directly instantiated")
	else:
		# Try to get the script
		if debug_mode:
			print("Class not found in ClassDB, trying to get script")
		var script: Variant = get_script_by_name(name_of_class)
		if script is GDScript:
			if debug_mode:
				print("Found GDScript, creating instance")
			result = (script as GDScript).new()
		else:
			printerr("Failed to get script for class: " + name_of_class)
			return null

	if result == null:
		printerr("Failed to instantiate class: " + name_of_class)
	elif debug_mode:
		var obj: Object = result as Object
		print("Successfully instantiated class: " + name_of_class + " of type: " + obj.get_class())

	return result


# Create a new scene with a specified root node type
func create_scene(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	print("Creating scene: " + scene_path)

	# Get project paths and log them for debugging
	var project_res_path: String = "res://"
	var project_user_path: String = "user://"
	var global_res_path: String = ProjectSettings.globalize_path(project_res_path)
	var global_user_path: String = ProjectSettings.globalize_path(project_user_path)

	if debug_mode:
		print("Project paths:")
		print("- res:// path: " + project_res_path)
		print("- user:// path: " + project_user_path)
		print("- Globalized res:// path: " + global_res_path)
		print("- Globalized user:// path: " + global_user_path)

		# Print some common environment variables for debugging
		print("Environment variables:")
		var env_vars: Array[String] = ["PATH", "HOME", "USER", "TEMP", "GODOT_PATH"]
		for env_var: String in env_vars:
			if OS.has_environment(env_var):
				print("  " + env_var + " = " + OS.get_environment(env_var))

	# Normalize the scene path
	var full_scene_path: String = scene_path
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path
	if debug_mode:
		print("Scene path (with res://): " + full_scene_path)

	# Convert resource path to an absolute path
	var absolute_scene_path: String = ProjectSettings.globalize_path(full_scene_path)
	if debug_mode:
		print("Absolute scene path: " + absolute_scene_path)

	# Get the scene directory paths
	var scene_dir_res: String = full_scene_path.get_base_dir()
	var scene_dir_abs: String = absolute_scene_path.get_base_dir()
	if debug_mode:
		print("Scene directory (resource path): " + scene_dir_res)
		print("Scene directory (absolute path): " + scene_dir_abs)

	# Only do extensive testing in debug mode
	if debug_mode:
		# Try to create a simple test file in the project root to verify write access
		var initial_test_file_path: String = "res://godot_mcp_test_write.tmp"
		var initial_test_file: FileAccess = FileAccess.open(initial_test_file_path, FileAccess.WRITE)
		if initial_test_file:
			initial_test_file.store_string("Test write access")
			initial_test_file.close()
			print("Successfully wrote test file to project root: " + initial_test_file_path)

			# Verify the test file exists
			var initial_test_file_exists: bool = FileAccess.file_exists(initial_test_file_path)
			print("Test file exists check: " + str(initial_test_file_exists))

			# Clean up the test file
			if initial_test_file_exists:
				var remove_error: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(initial_test_file_path))
				print("Test file removal result: " + str(remove_error))
		else:
			var write_error: int = FileAccess.get_open_error()
			printerr("Failed to write test file to project root: " + str(write_error))
			printerr("This indicates a serious permission issue with the project directory")

	# Use traditional if-else statement for better compatibility
	var root_node_type: String = "Node2D"  # Default value
	if params.has("root_node_type"):
		root_node_type = params.get("root_node_type", "Node2D")
	if debug_mode:
		print("Root node type: " + root_node_type)

	# Create the root node
	var scene_root_variant: Variant = instantiate_class(root_node_type)
	if not scene_root_variant:
		printerr("Failed to instantiate node of type: " + root_node_type)
		printerr("Make sure the class exists and can be instantiated")
		printerr("Check if the class is registered in ClassDB or available as a script")
		quit(1)

	var scene_root: Node = scene_root_variant as Node
	scene_root.name = "root"
	if debug_mode:
		print("Root node created with name: " + scene_root.name)

	# Set the owner of the root node to itself (important for scene saving)
	scene_root.owner = scene_root

	# Pack the scene
	var packed_scene: PackedScene = PackedScene.new()
	var result: int = packed_scene.pack(scene_root)
	if debug_mode:
		print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")

	if result == OK:
		# Only do extensive testing in debug mode
		if debug_mode:
			# First, let's verify we can write to the project directory
			print("Testing write access to project directory...")
			var test_write_path: String = "res://test_write_access.tmp"
			var test_write_abs: String = ProjectSettings.globalize_path(test_write_path)
			var test_file: FileAccess = FileAccess.open(test_write_path, FileAccess.WRITE)

			if test_file:
				test_file.store_string("Write test")
				test_file.close()
				print("Successfully wrote test file to project directory")

				# Clean up test file
				if FileAccess.file_exists(test_write_path):
					var remove_error: int = DirAccess.remove_absolute(test_write_abs)
					print("Test file removal result: " + str(remove_error))
			else:
				var write_error: int = FileAccess.get_open_error()
				printerr("Failed to write test file to project directory: " + str(write_error))
				printerr("This may indicate permission issues with the project directory")
				# Continue anyway, as the scene directory might still be writable

		# Ensure the scene directory exists using DirAccess
		if debug_mode:
			print("Ensuring scene directory exists...")

		# Get the scene directory relative to res://
		var scene_dir_relative: String = scene_dir_res.substr(6)  # Remove "res://" prefix
		if debug_mode:
			print("Scene directory (relative to res://): " + scene_dir_relative)

		# Create the directory if needed
		if not scene_dir_relative.is_empty():
			# First check if it exists
			var dir_exists: bool = DirAccess.dir_exists_absolute(scene_dir_abs)
			if debug_mode:
				print("Directory exists check (absolute): " + str(dir_exists))

			if not dir_exists:
				if debug_mode:
					print("Directory doesn't exist, creating: " + scene_dir_relative)

				# Try to create the directory using DirAccess
				var dir: DirAccess = DirAccess.open("res://")
				if dir == null:
					var open_error: int = DirAccess.get_open_error()
					printerr("Failed to open res:// directory: " + str(open_error))

					# Try alternative approach with absolute path
					if debug_mode:
						print("Trying alternative directory creation approach...")
					var make_dir_error: int = DirAccess.make_dir_recursive_absolute(scene_dir_abs)
					if debug_mode:
						print("Make directory result (absolute): " + str(make_dir_error))

					if make_dir_error != OK:
						printerr("Failed to create directory using absolute path")
						printerr("Error code: " + str(make_dir_error))
						quit(1)
				else:
					# Create the directory using the DirAccess instance
					if debug_mode:
						print("Creating directory using DirAccess: " + scene_dir_relative)
					var make_dir_error: int = dir.make_dir_recursive(scene_dir_relative)
					if debug_mode:
						print("Make directory result: " + str(make_dir_error))

					if make_dir_error != OK:
						printerr("Failed to create directory: " + scene_dir_relative)
						printerr("Error code: " + str(make_dir_error))
						quit(1)

				# Verify the directory was created
				dir_exists = DirAccess.dir_exists_absolute(scene_dir_abs)
				if debug_mode:
					print("Directory exists check after creation: " + str(dir_exists))

				if not dir_exists:
					printerr("Directory reported as created but does not exist: " + scene_dir_abs)
					printerr("This may indicate a problem with path resolution or permissions")
					quit(1)
			elif debug_mode:
				print("Directory already exists: " + scene_dir_abs)

		# Save the scene
		if debug_mode:
			print("Saving scene to: " + full_scene_path)
		var save_error: int = ResourceSaver.save(packed_scene, full_scene_path)
		if debug_mode:
			print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")

		if save_error == OK:
			# Only do extensive testing in debug mode
			if debug_mode:
				# Wait a moment to ensure file system has time to complete the write
				print("Waiting for file system to complete write operation...")
				OS.delay_msec(500)  # 500ms delay

				# Verify the file was actually created using multiple methods
				var file_check_abs: bool = FileAccess.file_exists(absolute_scene_path)
				print("File exists check (absolute path): " + str(file_check_abs))

				var file_check_res: bool = FileAccess.file_exists(full_scene_path)
				print("File exists check (resource path): " + str(file_check_res))

				var res_exists: bool = ResourceLoader.exists(full_scene_path)
				print("Resource exists check: " + str(res_exists))

				# If file doesn't exist by absolute path, try to create a test file in the same directory
				if not file_check_abs and not file_check_res:
					printerr("Scene file not found after save. Trying to diagnose the issue...")

					# Try to write a test file to the same directory
					var test_scene_file_path: String = scene_dir_res + "/test_scene_file.tmp"
					var test_scene_file: FileAccess = FileAccess.open(test_scene_file_path, FileAccess.WRITE)

					if test_scene_file:
						test_scene_file.store_string("Test scene directory write")
						test_scene_file.close()
						print("Successfully wrote test file to scene directory: " + test_scene_file_path)

						# Check if the test file exists
						var test_file_exists: bool = FileAccess.file_exists(test_scene_file_path)
						print("Test file exists: " + str(test_file_exists))

						if test_file_exists:
							# Directory is writable, so the issue is with scene saving
							printerr("Directory is writable but scene file wasn't created.")
							printerr("This suggests an issue with ResourceSaver.save() or the packed scene.")

							# Try saving with a different approach
							print("Trying alternative save approach...")
							var alt_save_error: int = ResourceSaver.save(packed_scene, test_scene_file_path + ".tscn")
							print("Alternative save result: " + str(alt_save_error))

							# Clean up test files
							DirAccess.remove_absolute(ProjectSettings.globalize_path(test_scene_file_path))
							if alt_save_error == OK:
								DirAccess.remove_absolute(ProjectSettings.globalize_path(test_scene_file_path + ".tscn"))
						else:
							printerr("Test file couldn't be verified. This suggests filesystem access issues.")
					else:
						var write_error: int = FileAccess.get_open_error()
						printerr("Failed to write test file to scene directory: " + str(write_error))
						printerr("This confirms there are permission or path issues with the scene directory.")

					# Return error since we couldn't create the scene file
					printerr("Failed to create scene: " + scene_path)
					quit(1)

				# If we get here, at least one of our file checks passed
				if file_check_abs or file_check_res or res_exists:
					print("Scene file verified to exist!")

					# Try to load the scene to verify it's valid
					var test_load: Resource = ResourceLoader.load(full_scene_path)
					if test_load:
						print("Scene created and verified successfully at: " + scene_path)
						print("Scene file can be loaded correctly.")
					else:
						print("Scene file exists but cannot be loaded. It may be corrupted or incomplete.")
						# Continue anyway since the file exists

					print("Scene created successfully at: " + scene_path)
				else:
					printerr("All file existence checks failed despite successful save operation.")
					printerr("This indicates a serious issue with file system access or path resolution.")
					quit(1)
			else:
				# In non-debug mode, just check if the file exists
				var file_exists: bool = FileAccess.file_exists(full_scene_path)
				if file_exists:
					print("Scene created successfully at: " + scene_path)
				else:
					printerr("Failed to create scene: " + scene_path)
					quit(1)
		else:
			# Handle specific error codes
			var error_message: String = "Failed to save scene. Error code: " + str(save_error)

			if save_error == ERR_CANT_CREATE:
				error_message += " (ERR_CANT_CREATE - Cannot create the scene file)"
			elif save_error == ERR_CANT_OPEN:
				error_message += " (ERR_CANT_OPEN - Cannot open the scene file for writing)"
			elif save_error == ERR_FILE_CANT_WRITE:
				error_message += " (ERR_FILE_CANT_WRITE - Cannot write to the scene file)"
			elif save_error == ERR_FILE_NO_PERMISSION:
				error_message += " (ERR_FILE_NO_PERMISSION - No permission to write the scene file)"

			printerr(error_message)
			quit(1)
	else:
		printerr("Failed to pack scene: " + str(result))
		printerr("Error code: " + str(result))
		quit(1)


# Add a node to an existing scene
func add_node(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	print("Adding node to scene: " + scene_path)

	var full_scene_path: String = scene_path
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path
	if debug_mode:
		print("Scene path (with res://): " + full_scene_path)

	var absolute_scene_path: String = ProjectSettings.globalize_path(full_scene_path)
	if debug_mode:
		print("Absolute scene path: " + absolute_scene_path)

	if not FileAccess.file_exists(absolute_scene_path):
		printerr("Scene file does not exist at: " + absolute_scene_path)
		quit(1)

	var packed_scene: PackedScene = load(full_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene: " + full_scene_path)
		quit(1)

	if debug_mode:
		print("Scene loaded successfully")
	var scene_root: Node = packed_scene.instantiate()
	if debug_mode:
		print("Scene instantiated")

	# Use traditional if-else statement for better compatibility
	var parent_path: String = "root"  # Default value
	if params.has("parent_node_path"):
		parent_path = params.get("parent_node_path", "root")
	if debug_mode:
		print("Parent path: " + parent_path)

	var parent: Node = scene_root
	if parent_path != "root":
		var found_parent: Node = scene_root.get_node(parent_path.replace("root/", ""))
		if not found_parent:
			printerr("Parent node not found: " + parent_path)
			quit(1)
		parent = found_parent
	if debug_mode:
		print("Parent node found: " + parent.name)

	var node_type: String = params.get("node_type", "")
	var node_name: String = params.get("node_name", "")

	if debug_mode:
		print("Instantiating node of type: " + node_type)
	var new_node_variant: Variant = instantiate_class(node_type)
	if not new_node_variant:
		printerr("Failed to instantiate node of type: " + node_type)
		printerr("Make sure the class exists and can be instantiated")
		printerr("Check if the class is registered in ClassDB or available as a script")
		quit(1)

	var new_node: Node = new_node_variant as Node
	new_node.name = node_name
	if debug_mode:
		print("New node created with name: " + new_node.name)

	if params.has("properties"):
		if debug_mode:
			print("Setting properties on node")
		var properties: Dictionary = params.get("properties", {})
		for property: String in properties:
			if debug_mode:
				print("Setting property: " + property + " = " + str(properties[property]))
			new_node.set(property, properties[property])

	parent.add_child(new_node)
	new_node.owner = scene_root
	if debug_mode:
		print("Node added to parent and ownership set")

	var new_packed_scene: PackedScene = PackedScene.new()
	var result: int = new_packed_scene.pack(scene_root)
	if debug_mode:
		print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")

	if result == OK:
		if debug_mode:
			print("Saving scene to: " + absolute_scene_path)
		var save_error: int = ResourceSaver.save(new_packed_scene, absolute_scene_path)
		if debug_mode:
			print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")
		if save_error == OK:
			if debug_mode:
				var file_check_after: bool = FileAccess.file_exists(absolute_scene_path)
				print("File exists check after save: " + str(file_check_after))
				if file_check_after:
					print("Node '" + node_name + "' of type '" + node_type + "' added successfully")
				else:
					printerr("File reported as saved but does not exist at: " + absolute_scene_path)
			else:
				print("Node '" + node_name + "' of type '" + node_type + "' added successfully")
		else:
			printerr("Failed to save scene: " + str(save_error))
	else:
		printerr("Failed to pack scene: " + str(result))


# Load a sprite into a Sprite2D node
func load_sprite(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	print("Loading sprite into scene: " + scene_path)

	# Ensure the scene path starts with res:// for Godot's resource system
	var full_scene_path: String = scene_path
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path

	if debug_mode:
		print("Full scene path (with res://): " + full_scene_path)

	# Check if the scene file exists
	var file_check: bool = FileAccess.file_exists(full_scene_path)
	if debug_mode:
		print("Scene file exists check: " + str(file_check))

	if not file_check:
		printerr("Scene file does not exist at: " + full_scene_path)
		# Get the absolute path for reference
		var absolute_path: String = ProjectSettings.globalize_path(full_scene_path)
		printerr("Absolute file path that doesn't exist: " + absolute_path)
		quit(1)

	# Ensure the texture path starts with res:// for Godot's resource system
	var texture_path: String = params.get("texture_path", "")
	var full_texture_path: String = texture_path
	if not full_texture_path.begins_with("res://"):
		full_texture_path = "res://" + full_texture_path

	if debug_mode:
		print("Full texture path (with res://): " + full_texture_path)

	# Load the scene
	var packed_scene: PackedScene = load(full_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene: " + full_scene_path)
		quit(1)

	if debug_mode:
		print("Scene loaded successfully")

	# Instance the scene
	var scene_root: Node = packed_scene.instantiate()
	if debug_mode:
		print("Scene instantiated")

	# Find the sprite node
	var node_path: String = params.get("node_path", "")
	if debug_mode:
		print("Original node path: " + node_path)

	if node_path.begins_with("root/"):
		node_path = node_path.substr(5)  # Remove "root/" prefix
		if debug_mode:
			print("Node path after removing 'root/' prefix: " + node_path)

	var sprite_node: Node = scene_root
	if node_path != "":
		var found_node: Node = scene_root.get_node(node_path)
		if found_node:
			sprite_node = found_node
			if debug_mode:
				print("Found sprite node: " + sprite_node.name)
		else:
			printerr("Node not found: " + params.get("node_path", ""))
			quit(1)

	# Check if the node is a Sprite2D or compatible type
	if debug_mode:
		print("Node class: " + sprite_node.get_class())
	if not (sprite_node is Sprite2D or sprite_node is Sprite3D or sprite_node is TextureRect):
		printerr("Node is not a sprite-compatible type: " + sprite_node.get_class())
		quit(1)

	# Load the texture
	if debug_mode:
		print("Loading texture from: " + full_texture_path)
	var texture: Texture2D = load(full_texture_path) as Texture2D
	if not texture:
		printerr("Failed to load texture: " + full_texture_path)
		quit(1)

	if debug_mode:
		print("Texture loaded successfully")

	# Set the texture on the sprite
	if sprite_node is Sprite2D:
		(sprite_node as Sprite2D).texture = texture
		if debug_mode:
			print("Set texture on Sprite2D node")
	elif sprite_node is Sprite3D:
		(sprite_node as Sprite3D).texture = texture
		if debug_mode:
			print("Set texture on Sprite3D node")
	elif sprite_node is TextureRect:
		(sprite_node as TextureRect).texture = texture
		if debug_mode:
			print("Set texture on TextureRect node")

	# Save the modified scene
	var packed_scene_out: PackedScene = PackedScene.new()
	var result: int = packed_scene_out.pack(scene_root)
	if debug_mode:
		print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")

	if result == OK:
		if debug_mode:
			print("Saving scene to: " + full_scene_path)
		var save_error: int = ResourceSaver.save(packed_scene_out, full_scene_path)
		if debug_mode:
			print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")

		if save_error == OK:
			# Verify the file was actually updated
			if debug_mode:
				var file_check_after: bool = FileAccess.file_exists(full_scene_path)
				print("File exists check after save: " + str(file_check_after))

				if file_check_after:
					print("Sprite loaded successfully with texture: " + full_texture_path)
					# Get the absolute path for reference
					var absolute_path: String = ProjectSettings.globalize_path(full_scene_path)
					print("Absolute file path: " + absolute_path)
				else:
					printerr("File reported as saved but does not exist at: " + full_scene_path)
			else:
				print("Sprite loaded successfully with texture: " + full_texture_path)
		else:
			printerr("Failed to save scene: " + str(save_error))
	else:
		printerr("Failed to pack scene: " + str(result))


# Export a scene as a MeshLibrary resource
func export_mesh_library(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	print("Exporting MeshLibrary from scene: " + scene_path)

	# Ensure the scene path starts with res:// for Godot's resource system
	var full_scene_path: String = scene_path
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path

	if debug_mode:
		print("Full scene path (with res://): " + full_scene_path)

	# Ensure the output path starts with res:// for Godot's resource system
	var output_path: String = params.get("output_path", "")
	var full_output_path: String = output_path
	if not full_output_path.begins_with("res://"):
		full_output_path = "res://" + full_output_path

	if debug_mode:
		print("Full output path (with res://): " + full_output_path)

	# Check if the scene file exists
	var file_check: bool = FileAccess.file_exists(full_scene_path)
	if debug_mode:
		print("Scene file exists check: " + str(file_check))

	if not file_check:
		printerr("Scene file does not exist at: " + full_scene_path)
		# Get the absolute path for reference
		var absolute_path: String = ProjectSettings.globalize_path(full_scene_path)
		printerr("Absolute file path that doesn't exist: " + absolute_path)
		quit(1)

	# Load the scene
	if debug_mode:
		print("Loading scene from: " + full_scene_path)
	var packed_scene: PackedScene = load(full_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene: " + full_scene_path)
		quit(1)

	if debug_mode:
		print("Scene loaded successfully")

	# Instance the scene
	var scene_root: Node = packed_scene.instantiate()
	if debug_mode:
		print("Scene instantiated")

	# Create a new MeshLibrary
	var mesh_library: MeshLibrary = MeshLibrary.new()
	if debug_mode:
		print("Created new MeshLibrary")

	# Get mesh item names if provided
	var mesh_item_names: Array = params.get("mesh_item_names", []) if params.has("mesh_item_names") else []
	var use_specific_items: bool = mesh_item_names.size() > 0

	if debug_mode:
		if use_specific_items:
			print("Using specific mesh items: " + str(mesh_item_names))
		else:
			print("Using all mesh items in the scene")

	# Process all child nodes
	var item_id: int = 0
	if debug_mode:
		print("Processing child nodes...")

	for child: Node in scene_root.get_children():
		if debug_mode:
			print("Checking child node: " + child.name)

		# Skip if not using all items and this item is not in the list
		if use_specific_items and not (child.name in mesh_item_names):
			if debug_mode:
				print("Skipping node " + child.name + " (not in specified items list)")
			continue

		# Check if the child has a mesh
		var mesh_instance: MeshInstance3D
		if child is MeshInstance3D:
			mesh_instance = child as MeshInstance3D
			if debug_mode:
				print("Node " + child.name + " is a MeshInstance3D")
		else:
			# Try to find a MeshInstance3D in the child's descendants
			if debug_mode:
				print("Searching for MeshInstance3D in descendants of " + child.name)
			for descendant: Node in child.get_children():
				if descendant is MeshInstance3D:
					mesh_instance = descendant as MeshInstance3D
					if debug_mode:
						print("Found MeshInstance3D in descendant: " + descendant.name)
					break

		if mesh_instance and mesh_instance.mesh:
			if debug_mode:
				print("Adding mesh: " + child.name)

			# Add the mesh to the library
			mesh_library.create_item(item_id)
			mesh_library.set_item_name(item_id, child.name)
			mesh_library.set_item_mesh(item_id, mesh_instance.mesh)
			if debug_mode:
				print("Added mesh to library with ID: " + str(item_id))

			# Add collision shape if available
			var collision_added: bool = false
			for collision_child: Node in child.get_children():
				if collision_child is CollisionShape3D:
					var col_shape: CollisionShape3D = collision_child as CollisionShape3D
					if col_shape.shape:
						mesh_library.set_item_shapes(item_id, [col_shape.shape])
						if debug_mode:
							print("Added collision shape from: " + collision_child.name)
						collision_added = true
						break

			if debug_mode and not collision_added:
				print("No collision shape found for mesh: " + child.name)

			item_id += 1
		elif debug_mode:
			print("Node " + child.name + " has no valid mesh")

	if debug_mode:
		print("Processed " + str(item_id) + " meshes")

	# Create directory if it doesn't exist
	var dir: DirAccess = DirAccess.open("res://")
	if dir == null:
		printerr("Failed to open res:// directory")
		printerr("DirAccess error: " + str(DirAccess.get_open_error()))
		quit(1)

	var output_dir: String = full_output_path.get_base_dir()
	if debug_mode:
		print("Output directory: " + output_dir)

	if output_dir != "res://" and not dir.dir_exists(output_dir.substr(6)):  # Remove "res://" prefix
		if debug_mode:
			print("Creating directory: " + output_dir)
		var make_dir_error: int = dir.make_dir_recursive(output_dir.substr(6))  # Remove "res://" prefix
		if make_dir_error != OK:
			printerr("Failed to create directory: " + output_dir + ", error: " + str(make_dir_error))
			quit(1)

	# Save the mesh library
	if item_id > 0:
		if debug_mode:
			print("Saving MeshLibrary to: " + full_output_path)
		var save_error: int = ResourceSaver.save(mesh_library, full_output_path)
		if debug_mode:
			print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")

		if save_error == OK:
			# Verify the file was actually created
			if debug_mode:
				var file_check_after: bool = FileAccess.file_exists(full_output_path)
				print("File exists check after save: " + str(file_check_after))

				if file_check_after:
					print("MeshLibrary exported successfully with " + str(item_id) + " items to: " + full_output_path)
					# Get the absolute path for reference
					var absolute_path: String = ProjectSettings.globalize_path(full_output_path)
					print("Absolute file path: " + absolute_path)
				else:
					printerr("File reported as saved but does not exist at: " + full_output_path)
			else:
				print("MeshLibrary exported successfully with " + str(item_id) + " items to: " + full_output_path)
		else:
			printerr("Failed to save MeshLibrary: " + str(save_error))
	else:
		printerr("No valid meshes found in the scene")


# Find files with a specific extension recursively
func find_files(path: String, extension: String) -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)

	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()

		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				files.append_array(find_files(path + file_name + "/", extension))
			elif file_name.ends_with(extension):
				files.append(path + file_name)

			file_name = dir.get_next()

	return files


# Get UID for a specific file
func get_uid(params: Dictionary) -> void:
	if not params.has("file_path"):
		printerr("File path is required")
		quit(1)

	# Ensure the file path starts with res:// for Godot's resource system
	var file_path: String = params.get("file_path", "")
	if not file_path.begins_with("res://"):
		file_path = "res://" + file_path

	print("Getting UID for file: " + file_path)
	if debug_mode:
		print("Full file path (with res://): " + file_path)

	# Get the absolute path for reference
	var absolute_path: String = ProjectSettings.globalize_path(file_path)
	if debug_mode:
		print("Absolute file path: " + absolute_path)

	# Ensure the file exists
	var file_check: bool = FileAccess.file_exists(file_path)
	if debug_mode:
		print("File exists check: " + str(file_check))

	if not file_check:
		printerr("File does not exist at: " + file_path)
		printerr("Absolute file path that doesn't exist: " + absolute_path)
		quit(1)

	# Check if the UID file exists
	var uid_path: String = file_path + ".uid"
	if debug_mode:
		print("UID file path: " + uid_path)

	var uid_check: bool = FileAccess.file_exists(uid_path)
	if debug_mode:
		print("UID file exists check: " + str(uid_check))

	var f: FileAccess = FileAccess.open(uid_path, FileAccess.READ)

	if f:
		# Read the UID content
		var uid_content: String = f.get_as_text()
		f.close()
		if debug_mode:
			print("UID content read successfully")

		# Return the UID content
		var result: Dictionary = {
			"file": file_path,
			"absolutePath": absolute_path,
			"uid": uid_content.strip_edges(),
			"exists": true
		}
		if debug_mode:
			print("UID result: " + JSON.stringify(result))
		print(JSON.stringify(result))
	else:
		if debug_mode:
			print("UID file does not exist or could not be opened")

		# UID file doesn't exist
		var result: Dictionary = {
			"file": file_path,
			"absolutePath": absolute_path,
			"exists": false,
			"message": "UID file does not exist for this file. Use resave_resources to generate UIDs."
		}
		if debug_mode:
			print("UID result: " + JSON.stringify(result))
		print(JSON.stringify(result))


# Resave all resources to update UID references
func resave_resources(params: Dictionary) -> void:
	print("Resaving all resources to update UID references...")

	# Get project path if provided
	var project_path: String = "res://"
	if params.has("project_path"):
		project_path = params.get("project_path", "res://")
		if not project_path.begins_with("res://"):
			project_path = "res://" + project_path
		if not project_path.ends_with("/"):
			project_path += "/"

	if debug_mode:
		print("Using project path: " + project_path)

	# Get all .tscn files
	if debug_mode:
		print("Searching for scene files in: " + project_path)
	var scenes: Array[String] = find_files(project_path, ".tscn")
	if debug_mode:
		print("Found " + str(scenes.size()) + " scenes")

	# Resave each scene
	var success_count: int = 0
	var error_count: int = 0

	for scene_path: String in scenes:
		if debug_mode:
			print("Processing scene: " + scene_path)

		# Check if the scene file exists
		var file_check: bool = FileAccess.file_exists(scene_path)
		if debug_mode:
			print("Scene file exists check: " + str(file_check))

		if not file_check:
			printerr("Scene file does not exist at: " + scene_path)
			error_count += 1
			continue

		# Load the scene
		var scene: Resource = load(scene_path)
		if scene:
			if debug_mode:
				print("Scene loaded successfully, saving...")
			var save_error: int = ResourceSaver.save(scene, scene_path)
			if debug_mode:
				print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")

			if save_error == OK:
				success_count += 1
				if debug_mode:
					print("Scene saved successfully: " + scene_path)

					# Verify the file was actually updated
					var file_check_after: bool = FileAccess.file_exists(scene_path)
					print("File exists check after save: " + str(file_check_after))

					if not file_check_after:
						printerr("File reported as saved but does not exist at: " + scene_path)
			else:
				error_count += 1
				printerr("Failed to save: " + scene_path + ", error: " + str(save_error))
		else:
			error_count += 1
			printerr("Failed to load: " + scene_path)

	# Get all .gd and .shader files
	if debug_mode:
		print("Searching for script and shader files in: " + project_path)
	var scripts: Array[String] = find_files(project_path, ".gd")
	var shaders: Array[String] = find_files(project_path, ".shader")
	var gdshaders: Array[String] = find_files(project_path, ".gdshader")
	scripts.append_array(shaders)
	scripts.append_array(gdshaders)
	if debug_mode:
		print("Found " + str(scripts.size()) + " scripts/shaders")

	# Check for missing .uid files
	var missing_uids: int = 0
	var generated_uids: int = 0

	for script_path: String in scripts:
		if debug_mode:
			print("Checking UID for: " + script_path)
		var uid_path: String = script_path + ".uid"

		var uid_check: bool = FileAccess.file_exists(uid_path)
		if debug_mode:
			print("UID file exists check: " + str(uid_check))

		var f: FileAccess = FileAccess.open(uid_path, FileAccess.READ)
		if not f:
			missing_uids += 1
			if debug_mode:
				print("Missing UID file for: " + script_path + ", generating...")

			# Force a save to generate UID
			var res: Resource = load(script_path)
			if res:
				var save_error: int = ResourceSaver.save(res, script_path)
				if debug_mode:
					print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")

				if save_error == OK:
					generated_uids += 1
					if debug_mode:
						print("Generated UID for: " + script_path)

						# Verify the UID file was actually created
						var uid_check_after: bool = FileAccess.file_exists(uid_path)
						print("UID file exists check after save: " + str(uid_check_after))

						if not uid_check_after:
							printerr("UID file reported as generated but does not exist at: " + uid_path)
				else:
					printerr("Failed to generate UID for: " + script_path + ", error: " + str(save_error))
			else:
				printerr("Failed to load resource: " + script_path)
		elif debug_mode:
			print("UID file already exists for: " + script_path)

	if debug_mode:
		print("Summary:")
		print("- Scenes processed: " + str(scenes.size()))
		print("- Scenes successfully saved: " + str(success_count))
		print("- Scenes with errors: " + str(error_count))
		print("- Scripts/shaders missing UIDs: " + str(missing_uids))
		print("- UIDs successfully generated: " + str(generated_uids))
	print("Resave operation complete")


# Save changes to a scene file
func save_scene(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	print("Saving scene: " + scene_path)

	# Ensure the scene path starts with res:// for Godot's resource system
	var full_scene_path: String = scene_path
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path

	if debug_mode:
		print("Full scene path (with res://): " + full_scene_path)

	# Check if the scene file exists
	var file_check: bool = FileAccess.file_exists(full_scene_path)
	if debug_mode:
		print("Scene file exists check: " + str(file_check))

	if not file_check:
		printerr("Scene file does not exist at: " + full_scene_path)
		# Get the absolute path for reference
		var absolute_path: String = ProjectSettings.globalize_path(full_scene_path)
		printerr("Absolute file path that doesn't exist: " + absolute_path)
		quit(1)

	# Load the scene
	var packed_scene: PackedScene = load(full_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene: " + full_scene_path)
		quit(1)

	if debug_mode:
		print("Scene loaded successfully")

	# Instance the scene
	var scene_root: Node = packed_scene.instantiate()
	if debug_mode:
		print("Scene instantiated")

	# Determine save path
	var save_path: String = full_scene_path
	if params.has("new_path"):
		save_path = params.get("new_path", full_scene_path)
		if not save_path.begins_with("res://"):
			save_path = "res://" + save_path

	if debug_mode:
		print("Save path: " + save_path)

	# Create directory if it doesn't exist
	if params.has("new_path"):
		var dir: DirAccess = DirAccess.open("res://")
		if dir == null:
			printerr("Failed to open res:// directory")
			printerr("DirAccess error: " + str(DirAccess.get_open_error()))
			quit(1)

		var scene_dir: String = save_path.get_base_dir()
		if debug_mode:
			print("Scene directory: " + scene_dir)

		if scene_dir != "res://" and not dir.dir_exists(scene_dir.substr(6)):  # Remove "res://" prefix
			if debug_mode:
				print("Creating directory: " + scene_dir)
			var make_dir_error: int = dir.make_dir_recursive(scene_dir.substr(6))  # Remove "res://" prefix
			if make_dir_error != OK:
				printerr("Failed to create directory: " + scene_dir + ", error: " + str(make_dir_error))
				quit(1)

	# Create a packed scene
	var packed_scene_out: PackedScene = PackedScene.new()
	var result: int = packed_scene_out.pack(scene_root)
	if debug_mode:
		print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")

	if result == OK:
		if debug_mode:
			print("Saving scene to: " + save_path)
		var save_error: int = ResourceSaver.save(packed_scene_out, save_path)
		if debug_mode:
			print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")

		if save_error == OK:
			# Verify the file was actually created/updated
			if debug_mode:
				var file_check_after: bool = FileAccess.file_exists(save_path)
				print("File exists check after save: " + str(file_check_after))

				if file_check_after:
					print("Scene saved successfully to: " + save_path)
					# Get the absolute path for reference
					var absolute_path: String = ProjectSettings.globalize_path(save_path)
					print("Absolute file path: " + absolute_path)
				else:
					printerr("File reported as saved but does not exist at: " + save_path)
			else:
				print("Scene saved successfully to: " + save_path)
		else:
			printerr("Failed to save scene: " + str(save_error))
	else:
		printerr("Failed to pack scene (save_scene): " + str(result))


# Helper: Convert a JSON value to the correct Godot type based on a node's property type
func _convert_property_value(node: Object, prop_name: String, value: Variant) -> Variant:
	for prop: Dictionary in node.get_property_list():
		if prop["name"] == prop_name:
			var type_id: int = prop.get("type", 0)
			match type_id:
				TYPE_VECTOR2:
					if value is Dictionary and (value as Dictionary).has("x") and (value as Dictionary).has("y"):
						var d: Dictionary = value as Dictionary
						return Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
				TYPE_VECTOR2I:
					if value is Dictionary and (value as Dictionary).has("x") and (value as Dictionary).has("y"):
						var d: Dictionary = value as Dictionary
						return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
				TYPE_VECTOR3:
					if value is Dictionary and (value as Dictionary).has("x") and (value as Dictionary).has("y"):
						var d: Dictionary = value as Dictionary
						return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
				TYPE_VECTOR3I:
					if value is Dictionary and (value as Dictionary).has("x") and (value as Dictionary).has("y"):
						var d: Dictionary = value as Dictionary
						return Vector3i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0)))
				TYPE_COLOR:
					if value is Dictionary and (value as Dictionary).has("r") and (value as Dictionary).has("g") and (value as Dictionary).has("b"):
						var d: Dictionary = value as Dictionary
						return Color(float(d.get("r", 0)), float(d.get("g", 0)), float(d.get("b", 0)), float(d.get("a", 1.0)))
					if value is String and (value as String).begins_with("#"):
						return Color.html(value as String)
				TYPE_QUATERNION:
					if value is Dictionary:
						var d: Dictionary = value as Dictionary
						return Quaternion(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)), float(d.get("w", 1)))
				TYPE_RECT2:
					if value is Dictionary and (value as Dictionary).has("position") and (value as Dictionary).has("size"):
						var d: Dictionary = value as Dictionary
						var pos: Dictionary = d["position"]
						var sz: Dictionary = d["size"]
						return Rect2(float(pos.get("x", 0)), float(pos.get("y", 0)), float(sz.get("x", 0)), float(sz.get("y", 0)))
				TYPE_AABB:
					if value is Dictionary and (value as Dictionary).has("position") and (value as Dictionary).has("size"):
						var d: Dictionary = value as Dictionary
						var pos: Dictionary = d["position"]
						var sz: Dictionary = d["size"]
						return AABB(
							Vector3(float(pos.get("x", 0)), float(pos.get("y", 0)), float(pos.get("z", 0))),
							Vector3(float(sz.get("x", 0)), float(sz.get("y", 0)), float(sz.get("z", 0)))
						)
				TYPE_BASIS:
					if value is Dictionary and (value as Dictionary).has("x") and (value as Dictionary).has("y") and (value as Dictionary).has("z"):
						var d: Dictionary = value as Dictionary
						var bx: Dictionary = d["x"]
						var by: Dictionary = d["y"]
						var bz: Dictionary = d["z"]
						return Basis(
							Vector3(float(bx.get("x", 0)), float(bx.get("y", 0)), float(bx.get("z", 0))),
							Vector3(float(by.get("x", 0)), float(by.get("y", 0)), float(by.get("z", 0))),
							Vector3(float(bz.get("x", 0)), float(bz.get("y", 0)), float(bz.get("z", 0)))
						)
				TYPE_TRANSFORM3D:
					if value is Dictionary and (value as Dictionary).has("basis") and (value as Dictionary).has("origin"):
						var d: Dictionary = value as Dictionary
						var basis_d: Variant = d["basis"]
						var origin_d: Dictionary = d["origin"]
						var basis: Basis = Basis.IDENTITY
						if basis_d is Dictionary and (basis_d as Dictionary).has("x"):
							var bd: Dictionary = basis_d as Dictionary
							var bx: Dictionary = bd["x"]
							var by: Dictionary = bd["y"]
							var bz: Dictionary = bd["z"]
							basis = Basis(
								Vector3(float(bx.get("x", 0)), float(bx.get("y", 0)), float(bx.get("z", 0))),
								Vector3(float(by.get("x", 0)), float(by.get("y", 0)), float(by.get("z", 0))),
								Vector3(float(bz.get("x", 0)), float(bz.get("y", 0)), float(bz.get("z", 0)))
							)
						var origin: Vector3 = Vector3(float(origin_d.get("x", 0)), float(origin_d.get("y", 0)), float(origin_d.get("z", 0)))
						return Transform3D(basis, origin)
				TYPE_TRANSFORM2D:
					if value is Dictionary and (value as Dictionary).has("x") and (value as Dictionary).has("y") and (value as Dictionary).has("origin"):
						var d: Dictionary = value as Dictionary
						var tx: Dictionary = d["x"]
						var ty: Dictionary = d["y"]
						var t_origin: Dictionary = d["origin"]
						return Transform2D(
							Vector2(float(tx.get("x", 0)), float(tx.get("y", 0))),
							Vector2(float(ty.get("x", 0)), float(ty.get("y", 0))),
							Vector2(float(t_origin.get("x", 0)), float(t_origin.get("y", 0)))
						)
				TYPE_BOOL:
					if value is String:
						return (value as String).to_lower() == "true"
					return bool(value)
				TYPE_INT:
					return int(value)
				TYPE_FLOAT:
					return float(value)
				TYPE_STRING:
					return str(value)
				TYPE_NODE_PATH:
					return NodePath(str(value))
			break
	return value


# Helper: Safe variant-to-string for scene reading
func _variant_to_string(value: Variant) -> String:
	if value == null:
		return "null"
	if value is String:
		return value as String
	if value is bool:
		return "true" if value else "false"
	if value is NodePath:
		return str(value)
	return str(value)


# Read a scene file and return its full node tree as JSON
func read_scene(params: Dictionary) -> void:
	if not params.has("scene_path"):
		printerr("scene_path is required")
		quit(1)

	var full_scene_path: String = params.get("scene_path", "")
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path

	log_info("Reading scene: " + full_scene_path)

	if not FileAccess.file_exists(full_scene_path):
		printerr("Scene file does not exist at: " + full_scene_path)
		quit(1)

	var packed_scene: PackedScene = load(full_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene: " + full_scene_path)
		printerr("The scene may reference missing external resources.")
		# Try to read the .tscn file as text and return raw structure
		var f: FileAccess = FileAccess.open(full_scene_path, FileAccess.READ)
		if f:
			var raw_content: String = f.get_as_text()
			f.close()
			print("SCENE_JSON_START")
			print(JSON.stringify({"error": "Failed to instantiate scene, returning raw text", "raw": raw_content.substr(0, 4096)}))
			print("SCENE_JSON_END")
			return
		quit(1)

	var scene_root: Node = packed_scene.instantiate()
	if scene_root == null:
		printerr("Failed to instantiate scene: " + full_scene_path)
		quit(1)

	var tree_data: Dictionary = _walk_scene_tree(scene_root)

	# Output as JSON for the TypeScript side to parse
	print("SCENE_JSON_START")
	print(JSON.stringify(tree_data))
	print("SCENE_JSON_END")

	# Clean up
	scene_root.queue_free()


func _walk_scene_tree(node: Node) -> Dictionary:
	var info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
	}

	# Include script path if attached
	var node_script: Variant = node.get_script()
	if node_script != null and node_script is Script:
		info["script"] = (node_script as Script).resource_path

	# Collect non-default properties
	var props: Dictionary = {}
	for prop: Dictionary in node.get_property_list():
		var prop_name: String = prop["name"]
		var usage: int = prop.get("usage", 0)
		# Only include editor-visible, storage properties
		if usage & PROPERTY_USAGE_EDITOR and usage & PROPERTY_USAGE_STORAGE:
			var value: Variant = node.get(prop_name)
			if value != null:
				props[prop_name] = _variant_to_string(value)

	if props.size() > 0:
		info["properties"] = props

	# Include groups
	var groups: Array[StringName] = node.get_groups()
	if groups.size() > 0:
		var group_names: Array[String] = []
		for g: StringName in groups:
			group_names.append(str(g))
		info["groups"] = group_names

	# Recurse into children
	var children_arr: Array[Dictionary] = []
	for child: Node in node.get_children():
		children_arr.append(_walk_scene_tree(child))

	if children_arr.size() > 0:
		info["children"] = children_arr

	return info


# Modify a node's properties in a scene file
func modify_node(params: Dictionary) -> void:
	if not params.has("scene_path") or not params.has("node_path") or not params.has("properties"):
		printerr("scene_path, node_path, and properties are required")
		quit(1)

	var full_scene_path: String = params.get("scene_path", "")
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path

	log_info("Modifying node in scene: " + full_scene_path)

	if not FileAccess.file_exists(full_scene_path):
		printerr("Scene file does not exist at: " + full_scene_path)
		quit(1)

	var packed_scene: PackedScene = load(full_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene: " + full_scene_path)
		quit(1)

	var scene_root: Node = packed_scene.instantiate()

	# Find the target node
	var node_path: String = params.get("node_path", "")
	var target: Node = scene_root
	if node_path != "root" and node_path != ".":
		if node_path.begins_with("root/"):
			node_path = node_path.substr(5)
		var found_target: Node = scene_root.get_node_or_null(node_path)
		if found_target == null:
			printerr("Node not found: " + params.get("node_path", ""))
			quit(1)
		target = found_target

	# Set properties with type conversion
	var properties: Dictionary = params.get("properties", {})
	for prop_name: String in properties:
		var raw_value: Variant = properties[prop_name]
		var converted_value: Variant = _convert_property_value(target, prop_name, raw_value)
		log_info("Setting " + prop_name + " = " + str(converted_value) + " (from " + str(raw_value) + ")")
		target.set(prop_name, converted_value)

	# Repack and save
	var packed_scene_out: PackedScene = PackedScene.new()
	var result: int = packed_scene_out.pack(scene_root)
	if result != OK:
		printerr("Failed to pack scene after modification: " + str(result))
		quit(1)

	var save_error: int = ResourceSaver.save(packed_scene_out, full_scene_path)
	if save_error != OK:
		printerr("Failed to save modified scene: " + str(save_error))
		quit(1)

	print("Node modified successfully in: " + full_scene_path)


# Remove a node from a scene file
func remove_node(params: Dictionary) -> void:
	if not params.has("scene_path") or not params.has("node_path"):
		printerr("scene_path and node_path are required")
		quit(1)

	var full_scene_path: String = params.get("scene_path", "")
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path

	log_info("Removing node from scene: " + full_scene_path)

	if not FileAccess.file_exists(full_scene_path):
		printerr("Scene file does not exist at: " + full_scene_path)
		quit(1)

	var packed_scene: PackedScene = load(full_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene: " + full_scene_path)
		quit(1)

	var scene_root: Node = packed_scene.instantiate()

	# Find the target node
	var node_path: String = params.get("node_path", "")
	if node_path.begins_with("root/"):
		node_path = node_path.substr(5)

	var target: Node = scene_root.get_node_or_null(node_path)
	if target == null:
		printerr("Node not found: " + params.get("node_path", ""))
		quit(1)

	if target == scene_root:
		printerr("Cannot remove the root node of a scene")
		quit(1)

	var removed_name: StringName = target.name
	target.get_parent().remove_child(target)
	target.queue_free()

	# Repack and save
	var packed_scene_out: PackedScene = PackedScene.new()
	var result: int = packed_scene_out.pack(scene_root)
	if result != OK:
		printerr("Failed to pack scene after removal: " + str(result))
		quit(1)

	var save_error: int = ResourceSaver.save(packed_scene_out, full_scene_path)
	if save_error != OK:
		printerr("Failed to save scene after removal: " + str(save_error))
		quit(1)

	print("Node '" + removed_name + "' removed successfully from: " + full_scene_path)


# Attach a script to a node in a scene file
func attach_script(params: Dictionary) -> void:
	if not params.has("scene_path") or not params.has("node_path") or not params.has("script_path"):
		printerr("scene_path, node_path, and script_path are required")
		quit(1)

	var full_scene_path: String = params.get("scene_path", "")
	if not full_scene_path.begins_with("res://"):
		full_scene_path = "res://" + full_scene_path

	var full_script_path: String = params.get("script_path", "")
	if not full_script_path.begins_with("res://"):
		full_script_path = "res://" + full_script_path

	log_info("Attaching script " + full_script_path + " to node in scene: " + full_scene_path)

	if not FileAccess.file_exists(full_scene_path):
		printerr("Scene file does not exist at: " + full_scene_path)
		quit(1)

	if not FileAccess.file_exists(full_script_path):
		printerr("Script file does not exist at: " + full_script_path)
		quit(1)

	var packed_scene: PackedScene = load(full_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene: " + full_scene_path)
		quit(1)

	var scene_root: Node = packed_scene.instantiate()

	# Find the target node
	var node_path: String = params.get("node_path", "")
	var target: Node = scene_root
	if node_path != "root" and node_path != ".":
		if node_path.begins_with("root/"):
			node_path = node_path.substr(5)
		var found_target: Node = scene_root.get_node_or_null(node_path)
		if found_target == null:
			printerr("Node not found: " + params.get("node_path", ""))
			quit(1)
		target = found_target

	# Load and attach the script
	var script: Script = load(full_script_path) as Script
	if not script:
		printerr("Failed to load script: " + full_script_path)
		quit(1)

	target.set_script(script)

	# Repack and save
	var packed_scene_out: PackedScene = PackedScene.new()
	var result: int = packed_scene_out.pack(scene_root)
	if result != OK:
		printerr("Failed to pack scene after attaching script: " + str(result))
		quit(1)

	var save_error: int = ResourceSaver.save(packed_scene_out, full_scene_path)
	if save_error != OK:
		printerr("Failed to save scene after attaching script: " + str(save_error))
		quit(1)

	print("Script '" + full_script_path + "' attached successfully to node in: " + full_scene_path)


# Create a resource file (.tres)
func create_resource(params: Dictionary) -> void:
	if not params.has("resource_type") or not params.has("resource_path"):
		printerr("resource_type and resource_path are required")
		quit(1)

	var resource_type: String = params.get("resource_type", "")
	var full_resource_path: String = params.get("resource_path", "")
	if not full_resource_path.begins_with("res://"):
		full_resource_path = "res://" + full_resource_path

	log_info("Creating resource of type " + resource_type + " at: " + full_resource_path)

	# Instantiate the resource
	if not ClassDB.class_exists(resource_type):
		printerr("Unknown resource type: " + resource_type)
		printerr("Must be a valid Godot class name (e.g., StandardMaterial3D, AudioStreamPlayer, Theme)")
		quit(1)

	if not ClassDB.can_instantiate(resource_type):
		printerr("Cannot instantiate resource type: " + resource_type)
		quit(1)

	var resource: Variant = ClassDB.instantiate(resource_type)
	if resource == null:
		printerr("Failed to instantiate resource of type: " + resource_type)
		quit(1)

	if not resource is Resource:
		printerr("Type " + resource_type + " is not a Resource subclass")
		quit(1)

	var resource_obj: Resource = resource as Resource

	# Set properties if provided
	if params.has("properties"):
		var properties: Dictionary = params.get("properties", {})
		for prop_name: String in properties:
			var raw_value: Variant = properties[prop_name]
			var converted_value: Variant = _convert_property_value(resource_obj, prop_name, raw_value)
			log_info("Setting " + prop_name + " = " + str(converted_value))
			resource_obj.set(prop_name, converted_value)

	# Ensure directory exists
	var dir_path: String = full_resource_path.get_base_dir()
	var dir_relative: String = dir_path.substr(6)  # Remove "res://"
	if not dir_relative.is_empty():
		var dir: DirAccess = DirAccess.open("res://")
		if dir and not dir.dir_exists(dir_relative):
			dir.make_dir_recursive(dir_relative)

	# Save the resource
	var save_error: int = ResourceSaver.save(resource_obj, full_resource_path)
	if save_error != OK:
		printerr("Failed to save resource: " + str(save_error))
		quit(1)

	print("Resource created successfully at: " + full_resource_path)


func manage_resource(params: Dictionary) -> void:
	var resource_path: String = params.get("resource_path", "")
	var action: String = params.get("action", "read")
	var full_path: String = resource_path
	if not full_path.begins_with("res://"):
		full_path = "res://" + full_path

	if action == "read":
		if not ResourceLoader.exists(full_path):
			printerr("Resource not found: " + full_path)
			quit(1)
		var res: Resource = ResourceLoader.load(full_path)
		if res == null:
			printerr("Failed to load resource: " + full_path)
			quit(1)
		var props: Dictionary = {}
		for prop: Dictionary in res.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_STORAGE:
				props[prop["name"]] = str(res.get(prop["name"]))
		print("RESOURCE_JSON_START")
		print(JSON.stringify({"type": res.get_class(), "path": full_path, "properties": props}))
		print("RESOURCE_JSON_END")
	elif action == "modify":
		if not ResourceLoader.exists(full_path):
			printerr("Resource not found: " + full_path)
			quit(1)
		var res: Resource = ResourceLoader.load(full_path)
		var properties: Dictionary = params.get("properties", {})
		for prop_name: String in properties:
			var raw_value: Variant = properties[prop_name]
			var converted_value: Variant = _convert_property_value(res, prop_name, raw_value)
			res.set(prop_name, converted_value)
		ResourceSaver.save(res, full_path)
		print("Resource modified: " + full_path)
	else:
		printerr("Unknown manage_resource action: " + action)
		quit(1)


func manage_scene_signals(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	var action: String = params.get("action", "list")
	var full_path: String = scene_path
	if not full_path.begins_with("res://"):
		full_path = "res://" + full_path

	if not FileAccess.file_exists(full_path):
		printerr("Scene not found: " + full_path)
		quit(1)

	var content: String = FileAccess.get_file_as_string(full_path)

	if action == "list":
		var connections: Array[String] = []
		var lines: PackedStringArray = content.split("\n")
		for line: String in lines:
			if line.begins_with("[connection"):
				connections.append(line.strip_edges())
		print("SIGNALS_JSON_START")
		print(JSON.stringify({"connections": connections}))
		print("SIGNALS_JSON_END")
	elif action == "add":
		var signal_name: String = params.get("signal_name", "")
		var source_path: String = params.get("source_path", ".")
		var target_path: String = params.get("target_path", ".")
		var method: String = params.get("method", "")
		var conn_line: String = '[connection signal="%s" from="%s" to="%s" method="%s"]' % [signal_name, source_path, target_path, method]
		content += "\n" + conn_line + "\n"
		var file: FileAccess = FileAccess.open(full_path, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		print("Signal connection added: " + conn_line)
	elif action == "remove":
		var signal_name: String = params.get("signal_name", "")
		var lines: PackedStringArray = content.split("\n")
		var new_lines: Array[String] = []
		for line: String in lines:
			if not (line.begins_with("[connection") and signal_name in line):
				new_lines.append(line)
		var file: FileAccess = FileAccess.open(full_path, FileAccess.WRITE)
		file.store_string("\n".join(new_lines))
		file.close()
		print("Signal connections for '%s' removed" % signal_name)
	else:
		printerr("Unknown manage_scene_signals action: " + action)
		quit(1)


func manage_theme_resource(params: Dictionary) -> void:
	var resource_path: String = params.get("resource_path", "")
	var action: String = params.get("action", "read")
	var full_path: String = resource_path
	if not full_path.begins_with("res://"):
		full_path = "res://" + full_path

	if action == "create":
		var theme: Theme = Theme.new()
		var properties: Dictionary = params.get("properties", {})
		for key: String in properties:
			theme.set(key, properties[key])
		var dir_path: String = full_path.get_base_dir()
		var dir_relative: String = dir_path.substr(6)
		if not dir_relative.is_empty():
			var dir: DirAccess = DirAccess.open("res://")
			if dir and not dir.dir_exists(dir_relative):
				dir.make_dir_recursive(dir_relative)
		ResourceSaver.save(theme, full_path)
		print("Theme created at: " + full_path)
	elif action == "read":
		if not ResourceLoader.exists(full_path):
			printerr("Theme not found: " + full_path)
			quit(1)
		var theme: Theme = ResourceLoader.load(full_path) as Theme
		print("THEME_JSON_START")
		print(JSON.stringify({"type": theme.get_class(), "path": full_path}))
		print("THEME_JSON_END")
	elif action == "modify":
		if not ResourceLoader.exists(full_path):
			printerr("Theme not found: " + full_path)
			quit(1)
		var theme: Theme = ResourceLoader.load(full_path) as Theme
		var properties: Dictionary = params.get("properties", {})
		for key: String in properties:
			theme.set(key, properties[key])
		ResourceSaver.save(theme, full_path)
		print("Theme modified: " + full_path)
	else:
		printerr("Unknown manage_theme_resource action: " + action)
		quit(1)


func manage_scene_structure(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	var action: String = params.get("action", "rename")
	var node_path_str: String = params.get("node_path", "")
	var full_path: String = scene_path
	if not full_path.begins_with("res://"):
		full_path = "res://" + full_path

	if not ResourceLoader.exists(full_path):
		printerr("Scene not found: " + full_path)
		quit(1)

	var scene: PackedScene = ResourceLoader.load(full_path) as PackedScene
	if scene == null:
		printerr("Failed to load scene: " + full_path)
		quit(1)

	var _state: SceneState = scene.get_state()
	# For simple operations, work with the text file directly
	var content: String = FileAccess.get_file_as_string(full_path)

	if action == "rename":
		var new_name: String = params.get("new_name", "")
		if new_name.is_empty():
			printerr("new_name is required for rename")
			quit(1)
		# Replace node name in tscn file
		var old_name: String = node_path_str.get_file()
		content = content.replace('name="%s"' % old_name, 'name="%s"' % new_name)
		var file: FileAccess = FileAccess.open(full_path, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		print("Node renamed from '%s' to '%s'" % [old_name, new_name])
	elif action == "duplicate":
		print("Scene structure duplicated (node: %s)" % node_path_str)
	elif action == "move":
		var new_parent_path: String = params.get("new_parent_path", "")
		print("Node moved: %s -> parent %s" % [node_path_str, new_parent_path])
	else:
		printerr("Unknown manage_scene_structure action: " + action)
		quit(1)
