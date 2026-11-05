class_name GaussAccessibilityProfile
extends RefCounted

const DEFAULTS := {"version": 1, "textScale": 1, "contrast": "standard", "reducedMotion": false, "focusMode": false, "pace": "normal", "soundEffects": "on", "audioAssistance": false, "captions": true, "preferredInput": "auto", "accessibleActivity": "auto"}

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("version") != 1:
		return {}
	var result := DEFAULTS.duplicate()
	for key in DEFAULTS:
		if not value.has(key):
			return {}
		var item: Variant = value[key]
		match key:
			"version":
				if typeof(item) not in [TYPE_INT, TYPE_FLOAT] or item != 1: return {}
			"textScale":
				if typeof(item) not in [TYPE_INT, TYPE_FLOAT] or float(item) not in [1.0, 1.25, 1.5, 2.0]: return {}
			"reducedMotion", "focusMode", "audioAssistance", "captions":
				if typeof(item) != TYPE_BOOL: return {}
			"contrast":
				if item not in ["standard", "high"]: return {}
			"pace":
				if item not in ["normal", "extended", "untimed"]: return {}
			"soundEffects":
				if item not in ["on", "off"]: return {}
			"preferredInput":
				if item not in ["auto", "keyboard", "touch"]: return {}
			"accessibleActivity":
				if item not in ["auto", "game", "react"]: return {}
		result[key] = item
	return result
