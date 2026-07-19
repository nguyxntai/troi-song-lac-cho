extends RefCounted
class_name UIStyle

## Bảng màu + helper UI DÙNG CHUNG cho toàn game, để mọi khung/chữ đồng bộ một "chất
## liệu gỗ - giấy cũ - viền vàng". KHÔNG đổi font (giữ font mặc định), chỉ chuẩn hoá
## màu, cỡ chữ, viền, khung. Gọi tĩnh: UIStyle.wood_panel(), UIStyle.style_label(...).

# ---- Bảng màu chuẩn ----
const WOOD_BG := Color(0.22, 0.13, 0.06, 0.96)       # nền gỗ đậm
const WOOD_BG_DEEP := Color(0.15, 0.08, 0.04, 0.97)  # nền gỗ đậm hơn (banner)
const GOLD := Color(0.82, 0.56, 0.24)                # viền vàng đồng
const GOLD_TEXT := Color(0.98, 0.80, 0.42)           # chữ tiêu đề vàng
const CREAM := Color(1.0, 0.96, 0.84)                # chữ thân
const CREAM_SOFT := Color(0.96, 0.90, 0.78)
const OUTLINE_DARK := Color(0.12, 0.06, 0.02)        # viền chữ
const COMMON_BUTTON_TEXTURE: Texture2D = preload("res://assets/UI/common_buttons/button_blank.png")

# Màu thanh (progress)
const TRACK := Color(0.06, 0.035, 0.02, 0.92)        # rãnh thanh
const FILL_GOOD := Color(0.30, 0.82, 0.46)           # xanh (uy tín/quỹ)
const FILL_BUSY := Color(1.0, 0.62, 0.12)            # cam (chợ đông)
const FILL_HEALTH := Color(0.95, 0.55, 0.35)         # cam đào (sức khỏe)
const FILL_HEALTH_LOW := Color(0.92, 0.30, 0.30)     # đỏ (sức khỏe thấp)
const FILL_WARN := Color(1.0, 0.78, 0.30)            # vàng cảnh báo

# Cỡ chữ chuẩn
const FS_SMALL := 14
const FS_BODY := 20
const FS_TITLE := 22
const FS_BIG := 28


## Khung gỗ viền vàng bo góc, có đổ bóng nhẹ.
static func wood_panel(radius: int = 12, margin: int = 14, deep: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = WOOD_BG_DEEP if deep else WOOD_BG
	s.border_color = GOLD
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0.0, 4.0)
	return s


## Rãnh nền cho ProgressBar.
static func bar_track(radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = TRACK
	s.set_corner_radius_all(radius)
	return s


## Phần đầy cho ProgressBar.
static func bar_fill(color: Color, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	return s


## Chuẩn hoá một Label: cỡ, màu chữ, viền tối. outline<0 => tự tính theo cỡ.
static func style_label(label: Control, size: int = FS_BODY, color: Color = CREAM, outline: int = -1) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	var o: int = outline if outline >= 0 else maxi(4, int(round(size / 5.0)))
	label.add_theme_constant_override("outline_size", o)


## Tiêu đề vàng.
static func style_title(label: Label, size: int = FS_TITLE) -> void:
	style_label(label, size, GOLD_TEXT)


## Nút dùng cho mọi UI dựng bằng code. Dùng cùng bảng gỗ/khăn caro với các TextureButton.
static func style_button(button: Button, _accent: Color = GOLD, font_size: int = FS_BODY) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(1.0, 0.67, 0.08))
	button.add_theme_color_override("font_outline_color", Color(0.34, 0.14, 0.01))
	button.add_theme_constant_override("outline_size", maxi(3, int(round(font_size / 5.5))))

	var normal := _common_button_style(Color.WHITE)
	var hover := _common_button_style(Color(1.08, 1.08, 1.02, 1.0))
	var pressed := _common_button_style(Color(0.82, 0.82, 0.82, 1.0))
	var disabled := _common_button_style(Color(0.52, 0.52, 0.52, 0.72))

	button.add_theme_color_override("font_hover_color", Color(1.0, 0.77, 0.22))
	button.add_theme_color_override("font_pressed_color", Color(0.85, 0.46, 0.04))
	button.add_theme_color_override("font_disabled_color", CREAM_SOFT.darkened(0.35))

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)


static func _common_button_style(modulate: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = COMMON_BUTTON_TEXTURE
	style.set_texture_margin(SIDE_LEFT, 58.0)
	style.set_texture_margin(SIDE_TOP, 28.0)
	style.set_texture_margin(SIDE_RIGHT, 58.0)
	style.set_texture_margin(SIDE_BOTTOM, 28.0)
	style.set_content_margin_all(10.0)
	style.modulate_color = modulate
	return style
