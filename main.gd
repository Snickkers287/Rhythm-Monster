extends Node2D

# 1. Game Data & Stats
var score := 0
var combo := 0
var max_combo := 0
var health := 10.0
var max_health := 10.0
var total_notes_hit := 0
var total_notes_spawned := 150
var is_game_over := false
var last_judgement := ""

# 2. 1080p Positioning
var lane_width := 140
var total_lane_width := lane_width * 4
var start_x := 960 - (total_lane_width / 2) 
var judge_y := 920 

# 3. Visual Juice Variables
var shake_amount := 0.0
var lane_flashes := [0.0, 0.0, 0.0, 0.0]
var lane_colors := [Color.MEDIUM_SPRING_GREEN, Color.INDIAN_RED, Color.DODGER_BLUE, Color.GOLD]
var notes := [[], [], [], []]

# 4. UI Animation Variables
var combo_bounce := 1.0
var score_bounce := 1.0

func _ready() -> void:
	restart_game()

func restart_game() -> void:
	score = 0
	combo = 0
	max_combo = 0
	total_notes_hit = 0
	health = max_health
	is_game_over = false
	last_judgement = ""
	shake_amount = 0.0
	lane_flashes = [0.0, 0.0, 0.0, 0.0]
	
	var btn = get_node_or_null("RestartButton")
	if btn: 
		btn.hide()
		btn.position = Vector2(960 - (btn.size.x / 2), 950)
	
	var cond = get_node_or_null("conductor")
	if cond:
		cond.stop()
		cond.play()
	
	notes = [[], [], [], []]
	seed(Time.get_ticks_msec())
	for i in total_notes_spawned:
		var random_lane = randi() % 4
		var spacing = max(0.6, 1.8 - (i * 0.005)) 
		var random_beat = 4.0 + (i * spacing) + (randf() * 0.2)
		notes[random_lane].append(random_beat)

func _process(delta: float) -> void:
	if shake_amount > 0:
		position = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
		shake_amount = lerp(shake_amount, 0.0, delta * 10.0)
	else:
		position = Vector2.ZERO
		
	combo_bounce = lerp(combo_bounce, 1.0, delta * 8.0)
	score_bounce = lerp(score_bounce, 1.0, delta * 8.0)

	if is_game_over:
		if Input.is_action_just_pressed("restart"): restart_game()
		return

	queue_redraw()
	
	for i in 4:
		if lane_flashes[i] > 0: lane_flashes[i] -= delta

	var cond = get_node_or_null("conductor")
	if cond:
		for i in 4:
			var lane = notes[i]
			while not lane.is_empty():
				if lane[0] < cond.beat - 0.6:
					lane.pop_front()
					trigger_miss()
				else:
					break

func trigger_miss() -> void:
	last_judgement = "MISS!"
	max_combo = max(max_combo, combo)
	combo = 0
	health -= 1.0
	shake_amount = 12.0 
	if health <= 0: end_game("GAME OVER")

func end_game(title_text: String) -> void:
	is_game_over = true
	last_judgement = title_text
	max_combo = max(max_combo, combo) # Lock in final combo
	
	var cond = get_node_or_null("conductor")
	if cond: cond.stop()
	var btn = get_node_or_null("RestartButton")
	if btn: btn.show()

func _draw() -> void:
	# Background
	draw_rect(Rect2(0,0, 1920, 1080), Color(0.01, 0.01, 0.02))

	# Lane Glows & Borders
	for i in 4:
		var x_pos = start_x + (lane_width * i)
		if lane_flashes[i] > 0:
			draw_rect(Rect2(x_pos, 0, lane_width, 1080), lane_colors[i] * Color(1,1,1, 0.08 * lane_flashes[i]))
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, 1080), Color(0.12, 0.12, 0.15), 2)
		if i == 3: draw_line(Vector2(x_pos + lane_width, 0), Vector2(x_pos + lane_width, 1080), Color(0.12, 0.12, 0.15), 2)

	draw_line(Vector2(start_x, judge_y), Vector2(start_x + total_lane_width, judge_y), Color.WHITE, 2)

	# Falling Notes
	var cond = get_node_or_null("conductor")
	if not is_game_over and cond:
		for i in 4:
			for note_beat in notes[i]:
				var y_pos = judge_y + 150 * (cond.beat - note_beat)
				if y_pos > -100 and y_pos < 1200:
					draw_line(Vector2(start_x + (lane_width * i) + 10, y_pos), Vector2(start_x + (lane_width * (i + 1)) - 10, y_pos), lane_colors[i], 24)

	# --- LIVE UI (Corners) ---
	# TOP LEFT: Score & Health
	draw_string(ThemeDB.fallback_font, Vector2(50, 80), "SCORE: " + str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 45 * score_bounce)
	draw_rect(Rect2(50, 100, 300, 12), Color.DARK_SLATE_GRAY)
	draw_rect(Rect2(50, 100, 300 * (health/max_health), 12), Color.SPRING_GREEN if health > 3 else Color.RED)
	
	# RIGHT SIDE: Combo & Judgement (Visible relative to lanes)
	var ui_right = start_x + total_lane_width + 40 
	if not is_game_over:
		var judge_col = Color.CYAN if "PERFECT" in last_judgement else Color.WHITE
		draw_string(ThemeDB.fallback_font, Vector2(ui_right, 880), last_judgement, HORIZONTAL_ALIGNMENT_LEFT, -1, 45, judge_col)
		if combo > 1:
			draw_string(ThemeDB.fallback_font, Vector2(ui_right, 450), "COMBO", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.GOLD)
			draw_string(ThemeDB.fallback_font, Vector2(ui_right, 520), str(combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 80 * combo_bounce)

	# --- STATS SCREEN (End of Game) ---
	if is_game_over:
		draw_rect(Rect2(0,0, 1920, 1080), Color(0,0,0,0.85))
		
		# Large Title
		var title_col = Color.RED if health <= 0 else Color.CYAN
		draw_string(ThemeDB.fallback_font, Vector2(960, 400), last_judgement, HORIZONTAL_ALIGNMENT_CENTER, -1, 110, title_col)
		
		# Detailed Stats
		draw_string(ThemeDB.fallback_font, Vector2(960, 520), "FINAL SCORE: " + str(score), HORIZONTAL_ALIGNMENT_CENTER, -1, 50)
		draw_string(ThemeDB.fallback_font, Vector2(960, 590), "MAX COMBO: " + str(max_combo), HORIZONTAL_ALIGNMENT_CENTER, -1, 45, Color.GOLD)
		
		var acc = (float(total_notes_hit) / float(max(1, total_notes_spawned))) * 100.0
		draw_string(ThemeDB.fallback_font, Vector2(960, 660), "ACCURACY: " + str(snapped(acc, 0.1)) + "%", HORIZONTAL_ALIGNMENT_CENTER, -1, 45)
		
		# Restart Hint
		draw_string(ThemeDB.fallback_font, Vector2(960, 800), "PRESS 'R' TO RESTART DEMO", HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color.DIM_GRAY)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_game_over: return
	if event.is_action_pressed("1"): _handle_press(0)
	elif event.is_action_pressed("2"): _handle_press(1)
	elif event.is_action_pressed("3"): _handle_press(2)
	elif event.is_action_pressed("4"): _handle_press(3)

func _handle_press(lane_index: int) -> void:
	var lane_notes = notes[lane_index]
	var cond = get_node_or_null("conductor")
	if lane_notes.is_empty() or not cond: return
	
	var diff = abs(cond.beat - lane_notes[0])
	if diff < 0.7: 
		combo += 1
		total_notes_hit += 1
		max_combo = max(max_combo, combo) # Update live for accuracy
		
		# Multiplier Fix
		score += 10 * (1 + int(combo / 10.0))
		
		# Early/Late Indicators
		if diff < 0.2: last_judgement = "PERFECT!"
		elif cond.beat < lane_notes[0]: last_judgement = "GREAT (EARLY)"
		else: last_judgement = "GREAT (LATE)"
		
		combo_bounce = 1.4
		score_bounce = 1.2
		lane_flashes[lane_index] = 1.0
		shake_amount = 15.0 if diff < 0.2 else 5.0
		
		lane_notes.pop_front()
	else:
		trigger_miss()
