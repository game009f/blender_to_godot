// NOTE: Shader automatically converted from Godot Engine 4.4.beta1's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

uniform vec4 albedo_color : source_color = vec4(1,1,1,1);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale: hint_range(0.,10.,.01) = 1.;
uniform bool invert_normal;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float metallic : hint_range(0.0, 1.0, 0.01);
uniform float specular : hint_range(0.0, 1.0, 0.01);


uniform bool fake_depth = true;
uniform float heightmap_scale : hint_range(-16.0, 16.0, 0.001) = .5;
uniform int heightmap_min_layers : hint_range(1, 64) = 4;
uniform int heightmap_max_layers : hint_range(1, 64) = 16;
uniform vec2 heightmap_flip = vec2(1,1);

uniform vec3 uv1_scale = vec3(1,1,1);
uniform vec3 uv1_offset;
uniform vec3 uv2_scale = vec3(1,1,1);
uniform vec3 uv2_offset;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(albedo_texture, UV);
	vec4 normal_tex;
	
	if(fake_depth && albedo_tex.a<.9)
	{
		// Height: Enabled
		vec3 view_dir = normalize(normalize(-VERTEX + EYE_OFFSET) * mat3(TANGENT * heightmap_flip.x, -BINORMAL * heightmap_flip.y, NORMAL));

		// Height Deep Parallax: Enabled
		float num_layers = mix(float(heightmap_max_layers), float(heightmap_min_layers), abs(dot(vec3(0.0, 0.0, 1.0), view_dir)));
		float layer_depth = 1.0 / num_layers;
		float current_layer_depth = 0.0;
		vec2 p = view_dir.xy * heightmap_scale * 0.01;
		vec2 delta = p / num_layers;
		vec2 ofs = base_uv;
		float depth = 1.0 - texture(albedo_texture, ofs).a;

		float current_depth = 0.0;
		while (current_depth < depth) {
			ofs -= delta;
			depth = 1.0 - texture(albedo_texture, ofs).a;

			current_depth += layer_depth;
		}

		vec2 prev_ofs = ofs + delta;
		float after_depth = depth - current_depth;
		float before_depth = (1.0 - texture(albedo_texture, prev_ofs).a) - current_depth + layer_depth;

		float weight = after_depth / (after_depth - before_depth);
		ofs = mix(ofs, prev_ofs, weight);

		vec2 rim_normal = vec2(dot(TANGENT, view_dir),dot(-BINORMAL, view_dir));
		vec3 view_tangent = vec3(rim_normal.x, rim_normal.y, sqrt(1.f-pow(rim_normal.x, 2.f)-pow(rim_normal.y, 2.f)));

		float texsize = 1024.f;
		float offset = 2./texsize;
		vec2 offsetX = vec2(offset, 0.);
		vec2 offsetY = vec2(0., offset);
		vec2 height_grad = vec2(0,0);
		int count = 0;
		vec2 shift[9] = vec2[9](
			vec2(0,0),
			vec2(0,1),
			vec2(1,1),
			vec2(1,0),
			vec2(1,-1),
			vec2(0,-1),
			vec2(-1,-1),
			vec2(-1,0),
			vec2(-1,1)
			);
		for(int i=0;i<9;++i)
		{	
			vec2 coord = ofs+shift[i]/texsize;
			height_grad += vec2((texture(albedo_texture, coord-offsetX).r-texture(albedo_texture, coord+offsetX).r), (texture(albedo_texture, coord+offsetY).r-texture(albedo_texture, coord-offsetY).r));
			count += int(length(height_grad) > 0.);
		}
		height_grad = normalize(mix(vec2(0., 1.), height_grad, float(length(height_grad)>0.)));
		vec3 normal_map = vec3(height_grad, 0.)*0.5f+0.5f;
		float lerp_floor = 0.1f;
		NORMAL_MAP = mix(vec3(.5f, .5f, 1.f), normal_map, pow(max(depth/(1.f-lerp_floor)-lerp_floor, 0.), 0.2));
		albedo_tex = texture(albedo_texture, ofs);
		albedo_tex.rgb = mix(albedo_color.rgb * albedo_tex.rgb,vec3(.8f), max(min(depth*50.f-.5f, 1.f), 0.f));
		//ALBEDO = vec3(height_grad, 0.);
	}
	else
	{	
		normal_tex = texture(texture_normal, UV);
		normal_tex -= .5;
		if(invert_normal)
		{
			normal_tex *= vec4(-1,-1,1,1);
		}
		normal_tex *= vec4(normal_scale,normal_scale,1,1);
		normal_tex += .5;
		NORMAL_MAP = normal_tex.rgb;
	}
	ALBEDO = albedo_color.rgb * albedo_tex.rgb;
	ALBEDO = mix(vec3(1.f), ALBEDO, float(FRONT_FACING));
	ALPHA *= albedo_color.a * albedo_tex.a;


	float metallic_tex = texture(metallic_texture, base_uv).r;
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = texture(roughness_texture, base_uv).r;
	ROUGHNESS = roughness_tex * roughness;
	//ALPHA_SCISSOR_THRESHOLD = 0.1f;
	ALPHA = pow(ALPHA, 0.1);
}
