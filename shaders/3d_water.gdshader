shader_type spatial;
render_mode cull_disabled; // Cho phép nhìn thấy mặt dưới của nước nếu cần

// Cấu hình màu sắc Stylized
uniform vec4 water_color : source_color = vec4(0.39, 0.61, 0.53, 1.0); // Màu rêu phấn mặc định
uniform vec4 deep_water_color : source_color = vec4(0.22, 0.38, 0.31, 1.0);

// Thuộc tính bề mặt PBR
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float metallic : hint_range(0.0, 1.0) = 0.0; // Để 0.0 để nước bệt màu nhựa, không hóa kim loại

// Tốc độ và kích thước gợn sóng
uniform float speed : hint_range(0.0, 0.1) = 0.01;
uniform float noise_scale = 1.0;

// BIẾN ĐIỀU CHỈNH ĐỘ DÀY SÓNG NGOÀI INSPECTOR
uniform float wave_threshold : hint_range(0.1, 0.9) = 0.6; 

// Độ sâu mờ dần (Beer's Law tối giản)
uniform float beer_law_factor = 2.0;
uniform float _distance = 10.0;

// Cấu hình dải bọt viền quanh Ghe
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_scale : hint_range(0.0, 2.0) = 0.2;

// Kết cấu nhiễu hạt
uniform sampler2D noise_texture : repeat_enable;
uniform sampler2D normalmap_texture : hint_normal, repeat_enable;

// Khai báo kết cấu độ sâu tích hợp của Godot 4
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

void vertex() {
	// Khóa cứng đỉnh lưới phẳng hoàn toàn để tránh lỗi bóng đổ mảng đen gắt
}

void fragment() {
	// 1. Ép kéo giãn trục X gấp 10 lần và làm thưa trục Y để vân sóng lờ lững dịu mắt
	vec2 stretched_uv1 = vec2(UV.x * 0.1, UV.y * 0.5) * noise_scale + vec2(TIME * speed, TIME * speed * 0.2);
	vec2 stretched_uv2 = vec2(UV.x * 0.1, UV.y * 0.5) * noise_scale - vec2(TIME * speed * 0.3, TIME * speed * 0.1);
	
	// Nạp UV đã kéo dẹt vào texture tạo sóng
	float n1 = texture(noise_texture, stretched_uv1).r;
	float n2 = texture(noise_texture, stretched_uv2).r;
	float combined_noise = (n1 + n2) * 0.5;
	
	// 2. Thuật toán đo độ sâu (Depth-fade) tuyến tính hóa chuẩn xác cho Godot 4
	float depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	
	float depth_diff = -view_pos.z + VERTEX.z;
	float depth_fade = clamp(exp(-depth_diff * beer_law_factor) / _distance, 0.0, 1.0);
	
	// Trộn màu nền nước theo độ phân tách nông sâu
	vec4 base_color = mix(water_color, deep_water_color, depth_fade);
	
	// ÉP KHỐI BỆT (Cel-shading) NGUYÊN BẢN:
	// Sử dụng biến `wave_threshold` thay vì số cứng để điều khiển độ hiển thị của sóng
	float wave_mask = step(wave_threshold, combined_noise);
	// Khi có sóng, ta trộn với màu foam_color trắng tinh theo các mảng cắt sắc nét, không bị nhòe màu
	vec3 wave_shading = mix(base_color.rgb, foam_color.rgb, wave_mask * 0.15);
	
	// 3. ĐÈ DẢI BỌT TRẮNG (FOAM) QUANH MẠN GHE:
	float foam_mask = step(depth_diff, foam_scale);
	
	if (depth_diff > 0.0) {
		ALBEDO = mix(wave_shading, foam_color.rgb, foam_mask);
	} else {
		ALBEDO = wave_shading;
	}
	
	// 4. Áp luôn UV đã kéo giãn vào Normal Map để đồng bộ ánh sáng lấp lánh dẹt ngang
	vec3 normal1 = texture(normalmap_texture, stretched_uv1).rgb;
	vec3 normal2 = texture(normalmap_texture, stretched_uv2).rgb;
	NORMAL_MAP = mix(normal1, normal2, 0.5);
	
	ROUGHNESS = roughness;
	METALLIC = metallic;
}