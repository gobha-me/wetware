shader_type canvas_item;

// Path 1 Standard (5/5): 24/32-Bit Isometric Pixel Art + 2.5D Normal Map +
// Emissive Mask + Foreground Silhouette Bloom Occlusion + 3-Stratum Cutaway +
// Proximity Building Occlusion Cutaway + Procedural Civilian Palette Remapping
uniform sampler2D normal_map : filter_nearest;
uniform sampler2D emissive_mask : filter_nearest;
uniform vec3 light_direction = vec3(-0.45, -0.55, 0.70);
uniform vec4 light_color : source_color = vec4(0.25, 0.88, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 1.65;
uniform float bloom_strength : hint_range(0.0, 4.0) = 1.40;
uniform float background_bloom : hint_range(0.0, 1.0) = 0.35;
uniform float stratum_cutaway_alpha : hint_range(0.05, 1.0) = 1.0;
uniform float building_cutaway_alpha : hint_range(0.10, 1.0) = 1.0;
uniform float blackout_factor : hint_range(0.15, 1.0) = 1.0;
uniform vec3 pulse_tint : source_color = vec3(0.0, 0.0, 0.0);
uniform float pulse_intensity : hint_range(0.0, 3.0) = 0.0;

// Procedural civilian population palette remapping (1 M/F pair -> infinite citizens)
uniform bool enable_palette_remap = false;
uniform int sheet_vframes = 4;
uniform vec3 jacket_tint : source_color = vec3(0.25, 0.72, 0.88);
uniform vec3 pants_tint : source_color = vec3(0.22, 0.26, 0.34);
uniform vec3 skin_tint : source_color = vec3(0.96, 0.78, 0.66);
uniform vec3 hair_tint : source_color = vec3(0.28, 0.18, 0.14);

void fragment() {
	vec4 fg = texture(TEXTURE, UV);
	vec3 base_rgb = fg.rgb;
	float lum = dot(base_rgb, vec3(0.299, 0.587, 0.114));

	if (enable_palette_remap && fg.a > 0.1) {
		float cell_y = fract(UV.y * float(max(sheet_vframes, 1)));
		bool is_skin = (base_rgb.r > base_rgb.g * 1.06) && (base_rgb.g > base_rgb.b * 1.04) && (lum > 0.26) && (cell_y < 0.52);
		bool is_head_hair = (cell_y < 0.23) && !is_skin && (lum > 0.08 && lum < 0.68);
		bool is_jacket = (cell_y >= 0.21 && cell_y <= 0.58) && !is_skin && (lum > 0.10);
		bool is_pants = (cell_y > 0.58 && cell_y <= 0.84) && (lum > 0.08 && lum < 0.62);

		if (is_skin) {
			base_rgb = skin_tint * (0.38 + lum * 0.95);
		} else if (is_head_hair) {
			base_rgb = hair_tint * (0.30 + lum * 1.45);
		} else if (is_jacket) {
			base_rgb = jacket_tint * (0.28 + lum * 1.38);
		} else if (is_pants) {
			base_rgb = pants_tint * (0.32 + lum * 1.42);
		}
	}

	vec3 n_sample = texture(normal_map, UV).rgb * 2.0 - 1.0;
	vec3 normal = normalize(n_sample);
	vec3 l_dir = normalize(light_direction);

	float hemi = clamp(dot(normal, l_dir) * 0.5 + 0.5, 0.0, 1.0);
	float ndotl = mix(0.72, 1.18, hemi) * blackout_factor;
	float rim = pow(1.0 - max(normal.z, 0.0), 2.5) * max(dot(normal.xy, l_dir.xy), 0.0) * (rim_strength * 0.14);

	vec4 emissive = texture(emissive_mask, UV);
	float occluded_bg_bloom = background_bloom * (1.0 - fg.a);

	vec3 dynamic_pulse = pulse_tint * pulse_intensity * (0.25 + 0.45 * pow(1.0 - max(normal.z, 0.0), 1.8));
	vec3 glow = emissive.rgb * emissive.a * (bloom_strength * 0.55);
	vec3 lit_rgb = base_rgb * ndotl + light_color.rgb * rim * (0.35 + 0.65 * blackout_factor) + glow + dynamic_pulse + vec3(occluded_bg_bloom * 0.03 * blackout_factor);

	// Proximity building occlusion cutaway: fade upper stories while keeping ground-floor curb readable
	float prox_alpha = building_cutaway_alpha;
	if (building_cutaway_alpha < 0.99) {
		float ground_keep = smoothstep(0.74, 0.94, UV.y);
		prox_alpha = mix(building_cutaway_alpha, max(building_cutaway_alpha, 0.78), ground_keep);
		// Subtle cyan holographic wireframe edge when building is peeled back
		lit_rgb = mix(lit_rgb, vec3(0.22, 0.88, 1.0), (1.0 - prox_alpha) * 0.18 * (1.0 - max(normal.z, 0.0)));
	}

	COLOR = vec4(lit_rgb, fg.a * stratum_cutaway_alpha * prox_alpha);
}

