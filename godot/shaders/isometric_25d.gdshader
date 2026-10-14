shader_type canvas_item;

// Path 1 Standard (5/5): 24/32-Bit Isometric Pixel Art + 2.5D Normal Map +
// Emissive Mask + Foreground Silhouette Bloom Occlusion + 3-Stratum Cutaway
uniform sampler2D normal_map : filter_nearest;
uniform sampler2D emissive_mask : filter_nearest;
uniform vec3 light_direction = vec3(-0.45, -0.55, 0.70);
uniform vec4 light_color : source_color = vec4(0.25, 0.88, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 1.65;
uniform float bloom_strength : hint_range(0.0, 4.0) = 1.40;
uniform float background_bloom : hint_range(0.0, 1.0) = 0.35;
uniform float stratum_cutaway_alpha : hint_range(0.05, 1.0) = 1.0;

void fragment() {
	vec4 fg = texture(TEXTURE, UV);
	vec3 n_sample = texture(normal_map, UV).rgb * 2.0 - 1.0;
	vec3 normal = normalize(n_sample);
	vec3 l_dir = normalize(light_direction);

	float ndotl = max(dot(normal, l_dir), 0.15);
	float rim = pow(1.0 - max(normal.z, 0.0), 2.0) * max(dot(normal.xy, l_dir.xy), 0.0) * rim_strength;

	vec4 emissive = texture(emissive_mask, UV);
	// Foreground silhouettes occlude background bloom so dark trenchcoats read cleanly against neon rain.
	float occluded_bg_bloom = background_bloom * (1.0 - fg.a);

	vec3 lit_rgb = fg.rgb * ndotl + light_color.rgb * rim + emissive.rgb * bloom_strength + vec3(occluded_bg_bloom * 0.15);
	COLOR = vec4(lit_rgb, fg.a * stratum_cutaway_alpha);
}
