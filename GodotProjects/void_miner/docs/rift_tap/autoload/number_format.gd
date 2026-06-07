extends Node
## Display formatting. Centralized so a BigNumber backend can be swapped in later
## without touching UI code.

const SUFFIXES := ["", "K", "M", "B", "T", "aa", "ab", "ac", "ad", "ae"]

func format(value: float) -> String:
	var v := absf(value)
	if v < 1000.0:
		return _trim(value)
	var tier := int(floor(log(v) / log(1000.0)))
	tier = clampi(tier, 0, SUFFIXES.size() - 1)
	var scaled := value / pow(1000.0, tier)
	return "%.2f%s" % [scaled, SUFFIXES[tier]]

func _trim(value: float) -> String:
	if absf(value - roundf(value)) < 0.005:
		return str(int(roundf(value)))
	return "%.1f" % value
