extends Node2D
enum GameState  {SELECTING,  PLAYING,GAME_OVER }
enum Difficulty {EASY,NORMAL,HARD,EXPERT }
const DIFFICULTIES := {
	Difficulty.EASY: {
		"label": "EASY","color": Color.LIME_GREEN,"note_speed": 120.0,"perfect_win": 0.30,"great_win": 0.90,"note_h": 28.0,
		"note_count": 100,"spacing_min": 0.90,"max_hp": 15.0,"hp_drain": 0.5},
	Difficulty.NORMAL: {
		"label": "NORMAL","color": Color.DODGER_BLUE,"note_speed": 165.0,"perfect_win": 0.20,"great_win": 0.65,"note_h": 20.0,
		"note_count": 150, "spacing_min": 0.60,"max_hp": 10.0, "hp_drain": 1.0},
	Difficulty.HARD: {
		"label": "HARD",  "color": Color.ORANGE_RED,"note_speed": 225.0,   "perfect_win": 0.13,  "great_win": 0.46,
		"note_h": 13.0,"note_count": 200,"spacing_min": 0.38,"max_hp": 8.0,"hp_drain": 1.5},
	Difficulty.EXPERT: {
		"label": "DJ IRL","color": Color.MEDIUM_ORCHID, "note_speed": 295.0, "perfect_win": 0.08,  "great_win": 0.30,
		"note_h": 7.0, "note_count": 260,"spacing_min": 0.22,"max_hp": 5.0,"hp_drain": 2.0
	}
}
var game_state   := GameState.SELECTING
var current_diff := Difficulty.NORMAL
var _cfg         : Dictionary
var score               := 0
var combo               := 0
var max_combo           := 0
var health              := 10.0
var max_health          := 10.0
var total_notes_hit     := 0
var total_notes_spawned := 150
var last_judgement      := ""
var first_miss_occurred := false
const SCREEN_W       := 1280
const SCREEN_H       := 720
var lane_width        := 120
var total_lane_width  := 480
var start_x           := 400
var judge_y           := 618
var shake_amount : float           = 0.0
var lane_flashes : Array[float]    = [0.0, 0.0, 0.0, 0.0]
var lane_colors  : Array[Color]    = [
	Color.MEDIUM_SPRING_GREEN,
	Color.INDIAN_RED,
	Color.DODGER_BLUE,
	Color.GOLD
]
var notes : Array = [[], [], [], []]
var combo_bounce := 1.0
var score_bounce := 1.0
var conductor : AudioStreamPlayer = null
func _ready() -> void:
	_cfg = DIFFICULTIES[current_diff]
func start_game(diff: Difficulty) -> void:
	current_diff    = diff
	_cfg            = DIFFICULTIES[diff]
	score           = 0
	combo           = 0
	max_combo       = 0
	total_notes_hit = 0
	max_health      = float(_cfg["max_hp"])
	health          = max_health
	last_judgement  = ""
	shake_amount    = 0.0
	lane_flashes    = [0.0, 0.0, 0.0, 0.0]
	first_miss_occurred    = false
	total_notes_spawned    = int(_cfg["note_count"])
	game_state             = GameState.PLAYING
	conductor = get_node_or_null("conductor")
	if conductor:
		conductor.volume_db = -30.0
		conductor.stop()
		conductor.play()
	notes = [[], [], [], []]
	seed(Time.get_ticks_msec())
	var sp_min := float(_cfg["spacing_min"])
	for i in total_notes_spawned:
		var lane: int   = randi() % 4
		var spacing: float = max(sp_min, 1.8 - float(i) * 0.005)
		var beat: float = 4.0 + float(i) * spacing + randf() * 0.2
		notes[lane].append(beat)
func _process(delta: float) -> void:
	if shake_amount > 0.0:
		position= Vector2(randf_range(-shake_amount, shake_amount),
						   randf_range(-shake_amount, shake_amount))
		shake_amount = lerp(shake_amount, 0.0, delta * 10.0)
	else:
		position = Vector2.ZERO
	combo_bounce =lerp(combo_bounce, 1.0, delta * 8.0)
	score_bounce=lerp(score_bounce, 1.0, delta * 8.0)
	if game_state != GameState.PLAYING:
		queue_redraw()
		return
	for i in 4:
		if lane_flashes[i] > 0.0:
			lane_flashes[i] -= delta
	if conductor and conductor.playing:
		var beat       : float= conductor.get_playback_position() * float(conductor.bpm) / 60.0
		var miss_fence := float(_cfg["great_win"])
		for i in 4:
			var lane : Array = notes[i]
			while not lane.is_empty() and float(lane[0]) < beat - miss_fence:
				lane.pop_front()
				trigger_miss()
	queue_redraw()
func trigger_miss() -> void:
	last_judgement      = "MISS!"
	max_combo           = max(max_combo, combo)
	combo               = 0
	health             -= float(_cfg["hp_drain"])
	shake_amount        = 12.0
	first_miss_occurred = true
	if health <= 0.0:
		end_game("GAME OVER")
func end_game(title: String) -> void:
	game_state     = GameState.GAME_OVER
	last_judgement = title
	max_combo      = max(max_combo, combo)
	if conductor:
		conductor.stop()
func _draw() -> void:
	match game_state:
		GameState.SELECTING:
			_draw_select_screen()
		GameState.PLAYING:
			_draw_game()
		GameState.GAME_OVER:
			_draw_game()
			_draw_end_screen()
func _draw_select_screen() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.03, 0.02, 0.07))

	draw_string(ThemeDB.fallback_font, Vector2(640, 100),
		"RHYTHM GAME", HORIZONTAL_ALIGNMENT_CENTER, -1, 68, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(640, 158),
		"SELECT DIFFICULTY", HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color(0.55, 0.55, 0.70))

	var diffs : Array[Difficulty] = [Difficulty.EASY, Difficulty.NORMAL, Difficulty.HARD, Difficulty.EXPERT]
	var keys  : Array[String]     = ["1", "2", "3", "4"]
	var descs : Array[String]     = [
		"Wide notes  |  Forgiving timing  |  15 HP",
		"Balanced    |  Standard speed    |  10 HP",
		"Thin notes  |  Tight timing      |   8 HP",
		"Razor timing  |  Extreme speed   |   5 HP"]
	for idx in 4:
		var d   : Difficulty = diffs[idx]
		var cfg : Dictionary = DIFFICULTIES[d]
		var col : Color      = cfg["color"]
		var y   := 250 + idx * 105
		var sel := (current_diff == d)
		if sel:
			draw_rect(Rect2(200, y - 36, 880, 72), col * Color(1, 1, 1, 0.13))
			draw_rect(Rect2(200, y - 36,   4, 72), col)
		var label_col := col if sel else col * Color(1, 1, 1, 0.55)
		var desc_col  := Color(0.80, 0.80, 0.85) if sel else Color(0.50, 0.50, 0.58)
		draw_string(ThemeDB.fallback_font,
			Vector2(230, y), "[%s]  %s" % [keys[idx], cfg["label"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 38, label_col)
		draw_string(ThemeDB.fallback_font,
			Vector2(490, y), descs[idx],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, desc_col)
	draw_string(ThemeDB.fallback_font, Vector2(640, 668),
		"UP/DOWN  NAVIGATE    ENTER  CONFIRM    OR PRESS 1-4",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0.35, 0.35, 0.45))
	draw_string(ThemeDB.fallback_font, Vector2(640, 700),
		"LANES:  [S]  [D]  [K]  [L]",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0.40, 0.40, 0.50))
func _draw_game() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.01, 0.01, 0.02))
	for i in 4:
		var xp := start_x + lane_width * i
		if lane_flashes[i] > 0.0:
			draw_rect(Rect2(xp, 0, lane_width, SCREEN_H),
				lane_colors[i] * Color(1.0, 1.0, 1.0, 0.15 * lane_flashes[i]))
		draw_line(Vector2(xp, 0), Vector2(xp, SCREEN_H), Color(0.12, 0.12, 0.15), 2)
		if i == 3:
			draw_line(Vector2(xp + lane_width, 0), Vector2(xp + lane_width, SCREEN_H),
				Color(0.12, 0.12, 0.15), 2)
	draw_line(Vector2(start_x, judge_y),
			  Vector2(start_x + total_lane_width, judge_y), Color.WHITE, 2)
	var key_labels : Array[String] = ["S", "D", "K", "L"]
	for i in 4:
		var cx := start_x + lane_width * i + lane_width / 2
		draw_string(ThemeDB.fallback_font, Vector2(cx, judge_y + 34),
			key_labels[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 22,
			lane_colors[i] * Color(1.0, 1.0, 1.0, 0.55))
	if game_state == GameState.PLAYING and conductor and conductor.playing:
		var beat       : float = conductor.get_playback_position() * float(conductor.bpm) / 60.0
		var note_speed : float = float(_cfg["note_speed"])
		var note_h     : float = float(_cfg["note_h"])
		for i in 4:
			for nb in notes[i]:
				var yp    : float = float(judge_y) + note_speed * (beat - float(nb))
				if yp > -60.0 and yp < float(SCREEN_H) + 60.0:
					var dist  : float = abs(yp - float(judge_y))
					var scale : float = clamp(1.0 - dist / 350.0, 0.45, 1.0)
					draw_line(
						Vector2(start_x + lane_width * i + 7,       yp),
						Vector2(start_x + lane_width * (i + 1) - 7, yp),
						lane_colors[i], note_h * scale)
	var hp_ratio := health / max_health
	var hp_col   := Color.SPRING_GREEN.lerp(Color.RED, 1.0 - hp_ratio)
	draw_string(ThemeDB.fallback_font, Vector2(28, 42),
		"SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.50, 0.50, 0.62))
	draw_string(ThemeDB.fallback_font, Vector2(28, 76),
		str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, int(40.0 * score_bounce))
	draw_rect(Rect2(28, 86, 210, 8), Color.DARK_SLATE_GRAY)
	draw_rect(Rect2(28, 86, 210.0 * hp_ratio, 8.0), hp_col)
	var d_col   : Color  = _cfg["color"]
	var d_label : String = _cfg["label"]
	draw_string(ThemeDB.fallback_font, Vector2(SCREEN_W - 24, 42),
		d_label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 22, d_col * Color(1.0, 1.0, 1.0, 0.80))
	var ui_right := start_x + total_lane_width + 26
	if game_state == GameState.PLAYING:
		var jcol : Color
		if "PERFECT" in last_judgement:
			jcol = Color.CYAN
		elif "MISS" in last_judgement:
			jcol = Color.RED
		else:
			jcol = Color.WHITE
		draw_string(ThemeDB.fallback_font, Vector2(ui_right, 570),
			last_judgement, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, jcol)
		if combo > 1:
			draw_string(ThemeDB.fallback_font, Vector2(ui_right, 290),
				"COMBO", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.GOLD)
			draw_string(ThemeDB.fallback_font, Vector2(ui_right, 348),
				str(combo), HORIZONTAL_ALIGNMENT_LEFT, -1, int(55.0 * combo_bounce))
func _draw_end_screen() -> void:
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.0, 0.0, 0.0, 0.86))
	var title_col : Color = Color.RED if health <= 0.0 else Color.CYAN
	draw_string(ThemeDB.fallback_font, Vector2(640, 210),
		last_judgement, HORIZONTAL_ALIGNMENT_CENTER, -1, 78, title_col)
	var d_col : Color = _cfg["color"]
	draw_string(ThemeDB.fallback_font, Vector2(640, 278),
		_cfg["label"] + " DIFFICULTY", HORIZONTAL_ALIGNMENT_CENTER, -1, 26, d_col)
	draw_string(ThemeDB.fallback_font, Vector2(640, 358),
		"FINAL SCORE:  " + str(score), HORIZONTAL_ALIGNMENT_CENTER, -1, 42)
	draw_string(ThemeDB.fallback_font, Vector2(640, 418),
		"MAX COMBO:  " + str(max_combo), HORIZONTAL_ALIGNMENT_CENTER, -1, 36, Color.GOLD)
	var pct     := float(total_notes_hit) / float(max(1, total_notes_spawned)) * 100.0
	var acc_col : Color
	if pct >= 90.0:
		acc_col = Color.LIME_GREEN
	elif pct >= 70.0:
		acc_col = Color.YELLOW
	else:
		acc_col = Color.WHITE
	draw_string(ThemeDB.fallback_font, Vector2(640, 476),
		"ACCURACY:  " + str(snapped(pct, 0.1)) + "%",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 36, acc_col)
	draw_string(ThemeDB.fallback_font, Vector2(640, 580),
		"[R]  PLAY AGAIN       [ESC]  CHANGE DIFFICULTY",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.DIM_GRAY)
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	match game_state:
		GameState.SELECTING:
			match key:
				KEY_1:                start_game(Difficulty.EASY)
				KEY_2:                start_game(Difficulty.NORMAL)
				KEY_3:                start_game(Difficulty.HARD)
				KEY_4:                start_game(Difficulty.EXPERT)
				KEY_UP:
					current_diff = ((int(current_diff) - 1 + 4) % 4) as Difficulty
					queue_redraw()
				KEY_DOWN:
					current_diff = ((int(current_diff) + 1) % 4) as Difficulty
					queue_redraw()
				KEY_ENTER, KEY_KP_ENTER:
					start_game(current_diff)
		GameState.PLAYING:
			match key:
				KEY_S: _handle_press(0)
				KEY_D: _handle_press(1)
				KEY_K: _handle_press(2)
				KEY_L: _handle_press(3)
		GameState.GAME_OVER:
			match key:
				KEY_R:
					start_game(current_diff)
				KEY_ESCAPE:
					game_state = GameState.SELECTING
					queue_redraw()
func _handle_press(lane_index: int) -> void:
	var lane_notes : Array = notes[lane_index]
	if not conductor or lane_notes.is_empty() or not conductor.playing:
		return
	var beat      : float = conductor.get_playback_position() * float(conductor.bpm) / 60.0
	var note_beat : float = float(lane_notes[0])
	var diff      : float = abs(beat - note_beat)
	var p_win     := float(_cfg["perfect_win"])
	var g_win     := float(_cfg["great_win"])
	if diff < g_win:
		combo           += 1
		total_notes_hit += 1
		max_combo        = max(max_combo, combo)
		score           += 10 + int(floor(float(combo) / 10.0)) * 5
		if diff < p_win:
			last_judgement           = "PERFECT!"
			lane_flashes[lane_index] = 1.0
			shake_amount             = 6.0
		else:
			last_judgement           = "GREAT (EARLY)" if beat < note_beat else "GREAT (LATE)"
			lane_flashes[lane_index] = 0.5
			shake_amount             = 3.0
		combo_bounce = 1.4
		score_bounce = 1.2
		lane_notes.pop_front()
	else:
		trigger_miss()
