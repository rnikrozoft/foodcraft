extends Node

const HOST_MOBILE := "192.168.0.104"
const PORT := 7350
const SERVER_KEY := "foodcraft_dev_key"
const USE_SSL := false

const BOARD_FAME := "culinary_fame"
const BOARD_EXPLORER := "explorer"

const SPEED_SCORE_BASE := 2_000_000_000

const FALLBACK_BOARDS := [
	{"id": "culinary_fame", "title": "ชื่อเสียง", "tier": 1, "description": "แต้มค้นพบรวม — เมนูหายากได้แต้มมากกว่า", "score_unit": "แต้ม"},
	{"id": "explorer", "title": "นักสำรวจ", "tier": 1, "description": "จำนวนเมนูที่ค้นพบทั้งหมด", "score_unit": "เมนู"},
	{"id": "first_discoverer", "title": "ผู้ค้นพบคนแรก", "tier": 1, "description": "จำนวนเมนูที่เป็นคนแรกของเซิร์ฟเวอร์", "score_unit": "ครั้ง"},
	{"id": "efficiency", "title": "ประสิทธิภาพ", "tier": 2, "description": "เมนูที่ค้นพบ ÷ จำนวนครั้งที่ผสม (ยิ่งสูงยิ่งเก่ง)", "score_unit": "%"},
	{"id": "speed_runner_100", "title": "ความเร็ว 100 เมนู", "tier": 2, "description": "ใครค้นพบครบ 100 เมนูเร็วที่สุด", "score_unit": "คะแนน"},
	{"id": "speed_runner_500", "title": "ความเร็ว 500 เมนู", "tier": 2, "description": "ใครค้นพบครบ 500 เมนูเร็วที่สุด", "score_unit": "คะแนน"},
	{"id": "combo_master", "title": "คอมโบมาสเตอร์", "tier": 2, "description": "ค้นพบเมนูใหม่ติดต่อกันสูงสุด", "score_unit": "ครั้ง"},
	{"id": "rare_hunter", "title": "นักล่าของหายาก", "tier": 2, "description": "จำนวนเมนูระดับหายาก (tier 3+) ที่ค้นพบ", "score_unit": "เมนู"},
	{"id": "category_thai", "title": "อาหารไทย", "tier": 3, "description": "จำนวนเมนูอาหารไทยที่ค้นพบ", "score_unit": "เมนู"},
	{"id": "category_japanese", "title": "อาหารญี่ปุ่น", "tier": 3, "description": "จำนวนเมนูอาหารญี่ปุ่นที่ค้นพบ", "score_unit": "เมนู"},
	{"id": "category_chinese", "title": "อาหารจีน", "tier": 3, "description": "จำนวนเมนูอาหารจีนที่ค้นพบ", "score_unit": "เมนู"},
	{"id": "category_western", "title": "อาหารตะวันตก", "tier": 3, "description": "จำนวนเมนูอาหารตะวันตกที่ค้นพบ", "score_unit": "เมนู"},
	{"id": "category_dessert", "title": "ของหวาน", "tier": 3, "description": "จำนวนเมนูของหวานที่ค้นพบ", "score_unit": "เมนู"},
	{"id": "season_explorer", "title": "นักสำรวจประจำเดือน", "tier": 5, "description": "เมนูที่ค้นพบใหม่ในเดือนนี้", "score_unit": "เมนู"},
	{"id": "season_efficiency", "title": "ประสิทธิภาพประจำเดือน", "tier": 5, "description": "ประสิทธิภาพการผสมในเดือนนี้", "score_unit": "%"},
]


func get_fallback_boards() -> Array:
	return FALLBACK_BOARDS.duplicate(true)


func get_base_url() -> String:
	var scheme := "https" if USE_SSL else "http"
	var host := "127.0.0.1" if OS.get_name() in ["macOS", "Windows", "Linux"] else HOST_MOBILE
	return "%s://%s:%d" % [scheme, host, PORT]
