@tool
extends EditorScenePostImportPlugin

var DEBUG = 0
var MATERIALS : Dictionary = {}

var gltf_path = null
var shader_parameters : Array[String] = [
	'albedo_color',
	'albedo_texture',
	'normal_enabled',
	'normal_scale',
	'normal_texture',
	'vertex_color_use_as_albedo',
	'vertex_color_is_srgb',
	'metallic',
	'metallic_texture',
	'roughness',
	'roughness_texture',
]

func _get_import_options(path: String) -> void:
	# save the file path to the import setting
	add_import_option("file_path", path)# TODO hack to access import file path

func _get_option_visibility(path: String, for_animation: bool, option: String) -> Variant:
	if option == 'file_path':
		return false
	else:
		return true
	
func _pre_process(scene: Node) -> void:
	if DEBUG >=1:
		print('POST-PLUGIN: PRE-PROCESS '+str(scene))
	self.gltf_path = get_option_value('file_path')
	
	var exists = FileAccess.file_exists(gltf_path+'.import')

func register_animations(import_config: ConfigFile, gltf: Dictionary, asset_index: Dictionary) -> void:
	if DEBUG >=1:
		print('REGISTERING ANIMATIONS')
		
	if not 'params' in import_config.get_sections():
		return
	var subres = import_config.get_value('params', '_subresources', null)
	if not subres:
		return
	if 'animations' not in subres.keys():
		return
	
	for anim_name in subres['animations'].keys():
		# fetch animation library
		var ref_asset_id = gltf['scenes'][0]['extras']['ref_asset_id']
		var char_info = asset_index[ref_asset_id]
		var char_name = char_info['name']
		var char_path = 'res://'.path_join(char_info['filepath'])
		
		var anim_lib = null
		var anim_lib_path = char_path.get_base_dir().path_join(char_name+'-anim_lib.tres')

		if ResourceLoader.exists(anim_lib_path):
			anim_lib = load(anim_lib_path)
		else:
			anim_lib = AnimationLibrary.new()
			anim_lib.resource_path = anim_lib_path
			anim_lib.resource_name = char_name+' Animation Library'
			
		var anim = load(subres['animations'][anim_name]['save_to_file/path'])
		
		if not anim:
			push_warning('Could not find animation resource at '+subres['animations'][anim_name]['save_to_file/path'])
		anim_lib.add_animation(anim.resource_name, anim)
		
		ResourceSaver.save(anim_lib)

func _internal_process(category: int, base_node: Node, node: Node, resource: Resource) -> void:
	if DEBUG >=1:
		print('POST-PLUGIN: INT-PROCESS '+str(resource))
	if resource:
		if resource.is_class('StandardMaterial3D'):
			if resource.resource_name not in MATERIALS.keys():
				MATERIALS[resource.resource_name] = resource
	return

func _post_process(scene: Node) -> void:
	if DEBUG >=1:
		print('POST-PLUGIN: POST-PROCESS '+str(scene))
	var gltf_path = self.gltf_path
	
	var asset_type = null
	
	var gltf = JSON.parse_string(FileAccess.open(gltf_path, FileAccess.READ).get_as_text())
	if 'extras' in gltf['scenes'][0].keys():
		var extras = gltf['scenes'][0]['extras']
		if 'asset_type' in extras.keys():
			asset_type = extras['asset_type']
		
	if not asset_type or asset_type in ['ASSET', 'CHARACTER']:
		process_materials(gltf)
		var scene_path = '.'.join(gltf_path.split('.').slice(0, -1))+'.tscn'
		if not FileAccess.file_exists(scene_path):
			var filesystem = EditorInterface.get_resource_filesystem()
			filesystem.update_file(gltf_path)
			filesystem.scan_sources()
	
	var import_config_path = gltf_path+'.import'
	var asset_index = JSON.parse_string(FileAccess.open('res://asset_index.json', FileAccess.READ).get_as_text())['assets']
	
	var import_config = ConfigFile.new()
	import_config.load(import_config_path)
	
	if not asset_type or asset_type in ['ANIMATION']:
		register_animations(import_config, gltf, asset_index)
	
	MATERIALS.clear()

func process_materials(gltf: Dictionary) -> void:
	if 'materials' not in gltf.keys():
		return
	var material_index = JSON.parse_string(FileAccess.open('res://material_index.json', FileAccess.READ).get_as_text())['assets']
	
	for mat_info in gltf['materials']:
		var mat_name = mat_info['name']
		if mat_name not in MATERIALS.keys():
			push_warning("Could not find imported material "+mat_name)
			continue
		var import_mat : StandardMaterial3D = MATERIALS[mat_name]
		var res_mat : ShaderMaterial = get_extracted_material(mat_info, material_index)
		if not res_mat:
			push_warning("Could not find extracted material resource"+mat_name)
			continue
		
		update_material(res_mat, import_mat, mat_info)

func get_extracted_material(mat_info: Dictionary, material_index: Dictionary) -> ShaderMaterial:
	if 'extras' not in mat_info.keys():
		return null
	if 'asset_id' not in mat_info['extras'].keys():
		return null
		
	var asset_id: String = mat_info['extras']['asset_id']
	
	if asset_id not in material_index.keys():
		return null
	
	var mat_asset: Dictionary = material_index[asset_id]
	var res_path: String = 'res://'+material_index[asset_id]['filepath']
	
	if not FileAccess.file_exists(res_path):
		return null
	
	return ResourceLoader.load(res_path)

func update_material(mat: ShaderMaterial, ref_mat: StandardMaterial3D, mat_info: Dictionary) -> void:
	var mat_name = ref_mat.resource_name
	if DEBUG >=1:
		print('UPDATING MATERIAL: '+mat_name)
		print('Material Info: '+str(mat_info))
		print('Material Resource: '+str(mat))
	if not mat.shader:
		mat.shader = preload('res://source/shaders/paper-default.gdshader')
	for param in shader_parameters:
		mat.set_shader_parameter(param, ref_mat[param])
	if ref_mat.albedo_texture:
		mat.set_shader_parameter('albedo_texture_size', Vector2i(ref_mat.albedo_texture.get_size()))
	
	ResourceSaver.save(mat)
	
	return
