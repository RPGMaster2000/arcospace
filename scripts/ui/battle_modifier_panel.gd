extends RefCounted
## Format live modifier status from the authoritative combat clock.


static func compact_status(modifier: Node, round_number: int) -> String:
	var name: String = modifier.NAMES[modifier.kind].to_upper()
	var remaining: int = maxi(0, modifier.ends_round - round_number)
	var wait_rounds: int = maxi(0, modifier.next_round - round_number)
	match modifier.kind:
		0:
			return ""
		1:
			return "◆  %s · Asteroid impact in %d rounds" % [name, wait_rounds]
		2, 6, 7:
			return (
				(
					"ϟ  %s · %s effects doubled · %d rounds left"
					% [name, modifier.storm_family(modifier.kind).capitalize(), remaining]
				)
				if modifier.active
				else "ϟ  %s · Next storm in %d rounds" % [name, wait_rounds]
			)
		3:
			return (
				("☀  %s · Shields disabled · %d rounds left" % [name, remaining])
				if modifier.active
				else "☀  %s · Shields online · Flare in %d rounds" % [name, wait_rounds]
			)
		4:
			return "◇  %s · Targeting accuracy: %d%%" % [name, 100 - modifier.miss_rate]
		5:
			return (
				"◈  %s · Uncommon card chance %s"
				% [
					name,
					(
						"doubled"
						if modifier.TEMPORAL_DROP_MULTIPLIER == 2.0
						else "multiplied by %.0f" % modifier.TEMPORAL_DROP_MULTIPLIER
					)
				]
			)
	return ""
