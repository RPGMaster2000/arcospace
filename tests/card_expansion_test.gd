extends SceneTree
const Library = preload("res://scripts/cards/card_library.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Modifier = preload("res://scripts/combat_modifier.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func state() -> Dictionary:
	return {"hull":40,"hull_capacity":80,"shields":20,"materials":100,"energy":100,"crew":100,"synthesizer":2,"reactor":2,"quarters":2}
func custom(values: Dictionary, family: String = "energy", cost: int = 0) -> Resource:
	var card = preload("res://scripts/cards/card_data.gd").new()
	card.family = family
	card.cost = cost
	card.effects = values
	return card
func expect(actual: Dictionary, wanted: Dictionary, context: String) -> void:
	for key in wanted: check(actual[key] == wanted[key], context + " " + key + " expected " + str(wanted[key]) + " got " + str(actual[key]))
func run() -> void:
	check(Library.CARDS.size() == 80, "74 distinct resources")
	var identities: Dictionary = {}
	var counts: Dictionary = {"materials":0,"energy":0,"crew":0}
	# Per-level outcomes from the prototype specification, with the same public combat state.
	var cases: Array = [
		[{"shields":29},{"shields":31},{"shields":33}], [{},{},{}],
		[{"hull":31},{"hull":29},{"hull":27}], [{"synthesizer":1},{"synthesizer":1},{"synthesizer":1}],
		[{"hull":47,"shields":15,"energy":105},{"hull":49,"energy":106},{"hull":51,"energy":107}],
		[{"shields":12},{"shields":10},{"shields":8}],
		[{"hull":44,"shields":26,"synthesizer":3},{"hull":45,"shields":28,"synthesizer":3},{"hull":46,"shields":30,"synthesizer":3}],
		[{"hull":36},{"hull":35},{"hull":34}], [{"shields":5},{"shields":2},{"shields":0}],
		[{"shields":26,"materials":105,"crew":103},{"shields":28,"materials":106,"crew":103},{"shields":30,"materials":106,"crew":104}],
		[{"materials":107,"reactor":2},{"materials":109,"reactor":2},{"materials":111,"reactor":2}],
		[{"reactor":1,"shields":15},{"reactor":1,"shields":13},{"reactor":1,"shields":11}],
		[{"shields":8},{"shields":5},{"shields":2}],
		[{"shields":24},{"shields":26},{"shields":28}],
		[{"shields":6},{"shields":3},{"shields":0}],
		[{"reactor":3,"shields":16,"materials":104,"crew":103},{"reactor":3,"materials":105,"crew":104},{"reactor":3,"materials":106,"crew":105}],
		[{"hull":33},{"hull":31},{"hull":29}],
		[{"hull":46},{"hull":48},{"hull":50}],
		[{"hull":35},{"hull":33},{"hull":31}],
		[{"quarters":3},{"quarters":3,"materials":102},{"quarters":3,"materials":104}],
		[{"energy":105,"reactor":2},{"energy":107,"reactor":2},{"energy":109,"reactor":2}],
		[{"hull":45,"shields":25,"materials":103},{"hull":46,"shields":27,"materials":103},{"hull":47,"shields":29,"materials":104}],
		[{"reactor":1,"energy":93},{"reactor":1,"energy":91},{"reactor":1,"energy":89}],
		[{"hull":34,"shields":14},{"hull":32,"shields":12},{"hull":30,"shields":10}]
	]
	var new_costs: Array = [8,10,12,14,9,11,13,15,11,9,15,17,10,14,12,13,9,10,14,17,12,9,13,12]
	var uncommon_indices: Array = [47,50,51,54,55,57,59,62,63,64,66]
	var actor_cases: Array = [0,1,4,6,9,10,13,15,17,19,20,21]
	for index in range(Library.CARDS.size()):
		var base: Resource = Library.CARDS[index]
		check(not identities.has(base.identity_key()), "Unique identity " + base.card_name)
		identities[base.identity_key()] = true
		if 44 <= index and index < 68:
			counts[base.family] += 1
			check(base.cost == new_costs[index-44] and base.tier == (2 if index in uncommon_indices else 1), "Prototype cost and tier " + base.card_name)
			check(base.allocation_category in ["offense","defense","systems"] and base.upgrade_effects.size()==2, "Allocation and upgrades serialized")
		for level in [0,1,2]:
			var card: Resource = base.with_upgrade(level)
			var a: Dictionary = state()
			var b: Dictionary = state()
			var original: Dictionary = card.effects.duplicate(true)
			check(Effects.play(card,a,b), "All card levels resolve " + card.card_name)
			check(card.effects == original and card.identity_key() == base.identity_key(), "No mutation or identity drift")
			check(a[card.family] >= 0 and a.shields >= 0 and b.shields >= 0, "Valid reserves")
			for key in Effects.PRODUCTION: check(a[key] >= 0 and b[key] >= 0, "Production floors")
			if 44 <= index and index < 68:
				var n: int = index - 44
				expect(a if n in actor_cases else b, cases[n][level], card.card_name)
				if n == 1: expect(a, {"hull":45+level,"shields":17,"energy":[104,105,105][level],"crew":[103,103,104][level]}, card.card_name)
	check(counts == {"materials":8,"energy":8,"crew":8}, "Eight new identities per family")
	for level in [0,1,2]:
		var a: Dictionary=state()
		Effects.play(Library.CARDS[0].with_upgrade(level),a,state())
		expect(a,{"materials":97,"shields":[24,26,28][level],"crew":[102,103,104][level]},"Revised Shield Plating")
		a=state()
		Effects.play(Library.CARDS[8].with_upgrade(level),a,state())
		expect(a,{"energy":93,"hull":[45,47,49][level],"materials":[103,104,105][level]},"Revised Nanobots")
		a=state(); a.energy=0
		Effects.play(Library.CARDS[7].with_upgrade(level),a,state())
		expect(a,{"energy":[3,4,5][level],"materials":[103,104,104][level],"crew":[103,103,104][level]},"Revised Power Cell")
	# Generic comparison boundaries and cross-target production comparisons.
	for operation in ["below","at_most","equal","at_least","above"]:
		for value in [9,10,11]:
			var a: Dictionary = state()
			a.energy = value
			var c: Dictionary = {"target":"self","attribute":"energy","comparison":operation,"threshold":10}
			var expected: bool = [value<10,value<=10,value==10,value>=10,value>10][["below","at_most","equal","at_least","above"].find(operation)]
			check(Effects.condition_matches(c,a,state()) == expected, "Comparison " + operation)
	for reserve in [0,1,6,100,250]:
		for opposite in [0,5,120]:
			var a: Dictionary = state()
			var b: Dictionary = state()
			a.materials = reserve
			b.materials = opposite
			Effects.play(Library.CARDS[57],a,b)
			check(a.materials == opposite and b.materials == reserve and a.energy == 86, "Snapshot exchange and cost")
	var a: Dictionary = state()
	var b: Dictionary = state()
	Effects.play(custom({"swap_resource":"energy"},"energy",10),a,b)
	check(a.energy == 90 and b.energy == 100, "Cannot exchange cost family")
	a = state(); b = state(); a.energy = 6
	Effects.play(custom({"conditional":{"target":"self","attribute":"energy","comparison":"at_most","threshold":5,"then":{"materials":7}}},"energy",1),a,b)
	check(a.energy == 5 and a.materials == 107, "Payment precedes condition")
	for level in [0,1,2]:
		for hull in [19,20,21]:
			a = state(); b = state(); a.hull = hull
			Effects.play(Library.CARDS[2].with_upgrade(level),a,b)
			check(a.shields == (25+level if hull<=20 else 20), "Hull Patch pre-repair boundary")
		for hull in [39,40,41]:
			a = state(); b = state(); a.hull = hull
			Effects.play(Library.CARDS[61].with_upgrade(level),a,b)
			check(a.hull == hull + ([12,15,18][level] if hull<40 else [6,8,10][level]), "Medical strict half-capacity boundary")
		for shields in [5,6,7]:
			a = state(); b = state(); b.shields = shields
			Effects.play(Library.CARDS[11],a,b)
			check(b.hull == (31+shields if shields<=6 else 40), "Laser follow-up after Shields depleted")
		for reactor in [1,2,3]:
			a = state(); b = state(); b.reactor = reactor
			Effects.play(Library.CARDS[54].with_upgrade(level),a,b)
			check(a.reactor == (3 if reactor>2 else 2), "Synchronization live production comparison")
		for card_index in [47,55,63,66]:
			a = state(); b = state()
			for key in Effects.PRODUCTION: b[key] = 1
			Effects.play(Library.CARDS[card_index].with_upgrade(level),a,b)
			for key in Effects.PRODUCTION: check(b[key] == (0 if Library.CARDS[card_index].effects.get("enemy_production", {}).has(key) else 1), "Targeted production minimum is zero")
	# New combat branches cannot bypass Nebula; Ion scales branch rewards, never predicates or swaps.
	for pair in [[51,"energy"],[62,"materials"]]:
		var actor: Dictionary=state()
		var enemy: Dictionary=state()
		actor[pair[1]]=0; enemy[pair[1]]=150
		Effects.play(Library.CARDS[pair[0]],actor,enemy)
		check(actor[pair[1]]==150 and enemy[pair[1]]==0, "All authored exchange identities use correct reserve")
	var mod = Modifier.new()
	mod.kind = 4; mod.miss_rate = 100
	for index in range(44,68):
		var card: Resource = Library.CARDS[index]
		a = state(); b = state()
		var before: Dictionary = b.duplicate(true)
		mod.play(card,a,b,0)
		if Modifier.is_combat(card.effects): check(b == before and a[card.family] == 100-card.cost, "Nebula misses new combat effects " + card.card_name)
	mod.kind = 2; mod.active = true
	for factor in [.5,2.0]:
		mod.ion_factor = factor
		var preview: Resource = mod.preview(Library.CARDS[58])
		check(preview.effects.conditional.threshold == 12 and preview.effects.conditional.then.break_shields == floori(14*factor), "Ion scales outcome not threshold")
		a = state(); b = state()
		mod.play(Library.CARDS[57],a,b)
		check(a.energy == 86 and a.materials == 100 and a.shields == 20+floori(4*factor), "Ion exchange is unscaled, cost unchanged")
	mod.free()
	# Both branches of tactical predicates at their exact thresholds, at every upgrade level.
	for level in [0,1,2]:
		for hull in [20,21]:
			a=state(); b=state(); a.hull=hull
			Effects.play(Library.CARDS[44].with_upgrade(level),a,b)
			check(a.shields == 20+[9,11,13][level]+([5,6,7][level] if hull<=20 else 0), "Bulkheads Hull boundary")
		for shields in [5,6]:
			a=state(); b=state(); b.shields=shields
			var report: Dictionary = {}
			Effects.play(Library.CARDS[46].with_upgrade(level),a,b,null,false,report)
			var hit: int = [9,11,13][level]+([7,8,9][level] if shields<=5 else 0)
			check(b.hull==40-hit and b.shields==shields and report.target==hit and report.target_before==40, "Siege bypasses Shields and aggregates Hull report")
		for reserve in [14,15]:
			a=state(); b=state(); b.materials=reserve
			Effects.play(Library.CARDS[47].with_upgrade(level),a,b)
			check(a.energy==100+([6,8,10][level] if reserve>=15 else 0), "Industrial reserve boundary")
		for shield_extra in [0,1]:
			a=state(); b=state(); b.shields=[8,10,12][level]+shield_extra
			Effects.play(Library.CARDS[49].with_upgrade(level),a,b)
			check(b.crew==(100-[5,6,7][level] if shield_extra==0 else 100), "Demolition checks after Shield damage")
		for reserve in [9,10]:
			a=state(); b=state(); b.energy=reserve
			Effects.play(Library.CARDS[52].with_upgrade(level),a,b)
			check(b.shields==maxi(0,20-[8,10,12][level]-([7,8,9][level] if reserve>=10 else 0)) and b.hull==40, "Capacitor Shield-only boundary")
		for shields in [11,12]:
			a=state(); b=state(); b.shields=shields
			Effects.play(Library.CARDS[58].with_upgrade(level),a,b)
			check((a.materials==100+[5,6,7][level] and b.shields==11) if shields<12 else (a.materials==100 and b.shields==0), "Feedback branches")
		for hull in [39,40]:
			a=state(); b=state(); b.hull=hull
			Effects.play(Library.CARDS[60].with_upgrade(level),a,b)
			check(b.hull==hull-[7,9,11][level]-([6,7,8][level] if hull<40 else 0), "Tactical strict half boundary before attack")
		for reactor in [2,3]:
			a=state(); b=state(); b.reactor=reactor
			Effects.play(Library.CARDS[64].with_upgrade(level),a,b)
			check(a.reactor==(3 if reactor>2 else 2) and a.energy==(100 if reactor>2 else 100+[5,7,9][level]), "Scientific live comparison")
		for reserve in [14,15]:
			a=state(); b=state(); b.energy=reserve
			Effects.play(Library.CARDS[66].with_upgrade(level),a,b)
			check(b.energy==(reserve-[7,9,11][level] if reserve>=15 else reserve) and a.materials==(100+[4,5,6][level] if reserve>=15 else 100), "Sabotage reserve condition")
		for reserve in [5,6]:
			a=state(); b=state(); a.energy=reserve
			Effects.play(Library.CARDS[7].with_upgrade(level),a,b)
			check(a.energy==reserve+([3,4,5][level] if reserve<=5 else 0) and not Library.CARDS[7].play_again, "Emergency Power Cell threshold and turn cost")
		for shields in [9,10]:
			a=state(); b=state(); b.shields=shields
			Effects.play(Library.CARDS[15].with_upgrade(level),a,b)
			var remaining: int = maxi(0,shields-([4,5,6][level] if shields>=10 else 0))
			check(b.hull==40-maxi(0,[6,8,10][level]-remaining) and b.shields==maxi(0,remaining-[6,8,10][level]), "Missile branch breaks before damage")
		for hull in [15,16]:
			a=state(); b=state(); b.hull=hull; b.shields=30
			Effects.play(Library.CARDS[19].with_upgrade(level),a,b)
			check(b.shields==30-[12,15,18][level]-([4,5,6][level] if hull<=15 else 0) and b.hull==hull, "Torpedo finisher evaluated before attack")
		for extra in [0,1]:
			a=state(); b=state(); b.shields=[8,11,14][level]+extra
			Effects.play(Library.CARDS[16].with_upgrade(level),a,b)
			check(a.materials==100+([4,5,6][level] if extra==0 else 0), "Breachers check after breaking Shields")
	var compared: String = preload("res://scripts/ui/card_effect_text.gd").comparison(Library.CARDS[46].with_upgrade(1),Library.CARDS[46])
	check(compared.contains("11 Hull damage") and compared.contains("8 Hull damage") and not compared.contains("[color=91e6ad]If"), "Upgrade preview keeps bypass semantics and neutral unchanged predicate")
	# Actual battle snapshots carry capacity for percentage predicates; AI uses identical simulation.
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled=false
	root.add_child(board)
	board.enemy_timer.stop()
	check(board.ship_snapshot("player").hull_capacity==board.player_hull_capacity and board.ship_snapshot("enemy").hull_capacity==board.enemy_hull_capacity, "Board supplies both original Hull capacities")
	board.free()
	await process_frame
	var ai = preload("res://scripts/enemy_ai.gd").new()
	ai.tactical_weights={"resources":1.0,"disruption":1.0,"damage":1.0}
	ai.tactical_variation=0
	a=state(); b=state(); a.materials=0; b.materials=90
	var before_ai: Dictionary = a.duplicate(true)
	check(ai.choose([Library.CARDS[57], Library.CARDS[11]],a,b).slot==0 and a==before_ai, "Existing tactical AI values advantageous snapshot exchange without mutation")
	ai.free()
	await test_decks()
	print("Card expansion: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func test_decks() -> void:
	for ship in range(6):
		var run = State.new()
		run.start(ship,Rules,1707)
		check(run.player_pool().size() == 29 and run.deck_limit() == 36, "Expanded starting pool and capacity")
		for card in run.player_pool().slice(0,25): check(Library.CARDS.find(card)<44, "Original identities preserved")
		for n in range(7):
			run.pending_choice = "card"; run.card_offers = run.random_card_offers()
			check(run.choose_card(0) and run.player_pool().size()==30+n and run.pending_choice.is_empty(), "Eight normal acquisitions")
		var retained: Resource = run.player_pool()[1]
		var removed: Resource = run.player_pool()[0]
		run.start_upgrade_event(2)
		run.choose_upgrade(retained.identity_key()); run.choose_upgrade(removed.identity_key())
		var pool_before: Array = run.player_pool()
		run.pending_choice = "card"; run.card_offers = run.random_card_offers()
		var incoming: Resource = run.card_offers[0]
		check(run.choose_card(0) and run.pending_choice == "replace" and run.pending_card == incoming and run.player_pool() == pool_before, "Full deck fixes incoming without mutation")
		check(not run.can_jump() and not run.replace_card("unowned") and not run.choose_card(0), "Pending/stale safeguards")
		check(run.replace_card(removed.identity_key()) and run.player_pool().size() == 36 and not run.replace_card(retained.identity_key()), "Replacement atomic and single use")
		var keys: Array = []
		for card in run.player_pool():
			keys.append(card.identity_key())
			if card.identity_key() == retained.identity_key(): check(card.upgrade_level == 1, "Retained upgrade persists")
			if card.identity_key() == incoming.identity_key(): check(card.upgrade_level == 0, "Removed upgrade never transferred")
		check(not keys.has(removed.identity_key()) and keys.has(incoming.identity_key()) and not run.upgraded_cards.has(removed.identity_key()), "Removed identity and upgrade gone")
		check(run.acquired_draw_weights()[incoming.identity_key()] == 3.0, "New acquisition retains weight")
		var reacquired_offer: Array[Resource] = [removed]
		run.pending_choice = "card"; run.card_offers = reacquired_offer
		run.choose_card(0)
		check(run.pending_card == removed, "Removed starting card can be reacquired")
		check(run.replace_card(incoming.identity_key()) and run.player_pool().size() == 36, "Can replace acquired identity too")
		for card in run.player_pool():
			if card.identity_key() == removed.identity_key(): check(card.upgrade_level == 0, "Reacquisition starts at base")
		pool_before = run.player_pool()
		run.pending_choice = "card"; run.card_offers = run.random_card_offers(); run.choose_card(0)
		check(run.decline_card() and not run.decline_card() and run.player_pool() == pool_before, "Decline single use, no mutation")
		check(run.shared_pool().size()==80, "Enemy pool unaffected by capacity")
		var hand = preload("res://scripts/cards/card_hand.gd").new()
		hand.card_pool=run.player_pool()
		var evicted: Resource = run.player_pool()[0]
		hand.cards.assign([evicted,evicted,run.player_pool()[2],run.player_pool()[3],run.player_pool()[4],run.player_pool()[5]])
		run.pending_choice="card"; run.card_offers=run.random_card_offers(); run.choose_card(0)
		check(run.replace_card(evicted.identity_key()) and hand.cards.size()==6, "Replacement updates active hand without changing hand size")
		preload("res://scripts/combat/battle_adapter.gd").sync_hand(hand, run.player_pool(), run.acquired_draw_weights(), run.upgraded_cards)
		for held in hand.cards: check(held.identity_key()!=evicted.identity_key(), "No removed identity remains held")
		check(hand.card_pool==run.player_pool() and hand.identity_weights==run.acquired_draw_weights(), "Active draw pool and weights synchronized")
		hand.free()
		var deck_before_jump: Array=run.player_pool()
		var weights_before_jump: Dictionary=run.acquired_draw_weights()
		run.ftl_access = true
		check(run.generate_system() and run.player_pool()==deck_before_jump and run.acquired_draw_weights()==weights_before_jump, "Ownership, upgrades and weights survive system transition")
		# A paid station card reward uses the same fixed replacement/decline flow without refund.
		run.service={"kind":"service","poi":Rules.trading_outpost,"completed":false}
		run.salvage=100
		var price: int=run.service_cost(2)
		check(run.purchase_service(2,run.service_revision), "Full-deck station reward can be purchased")
		run.choose_card(0)
		check(run.pending_choice=="replace" and run.decline_card() and run.salvage==100-price and run.player_pool()==deck_before_jump, "Declining paid card keeps deck and spent Salvage")
		var config: Resource = Rules.duplicate(true)
		config.max_deck_identities = 29
		run.start(ship,config,1708)
		run.pending_choice = "card"; run.card_offers = run.random_card_offers(); run.choose_card(0)
		check(run.pending_choice == "replace" and run.deck_limit()==29, "Inspector capacity honored")
