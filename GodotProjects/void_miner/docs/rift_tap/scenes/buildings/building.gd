extends PanelContainer
## Cosmetic marker for a placed building, configured at runtime from its BuildingData.
## Visual only — it NEVER feeds the economy simulation (that reads GameState).

@onready var _label: Label = $Label

const CATEGORY_COLOR := {
	BuildingData.Category.EXTRACTOR: Color(1.0, 0.55, 0.30),
	BuildingData.Category.COLLECTOR: Color(0.40, 0.80, 1.0),
	BuildingData.Category.SUPPORT: Color(0.70, 0.90, 0.50),
}

## Call AFTER add_child (so _ready has run and $Label exists).
func configure(data: BuildingData) -> void:
	_label.text = _abbrev(data.display_name)
	tooltip_text = "%s\n%s" % [data.display_name, data.description]
	self_modulate = CATEGORY_COLOR.get(data.category, Color.WHITE)

func _abbrev(building_name: String) -> String:
	var parts := building_name.split("-", false)
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()
	return building_name.substr(0, 2).to_upper()
