@tool
extends Resource
class_name HumanizerMacroService

static var macro_ranges :Dictionary = {
		age = [["baby",0],["child",.12],["young",.25],["old",1]],
		gender = [["female",0.0],["male",1.0]],
		height = [["minheight",0],["",.5],["maxheight",1]],
		muscle = [["minmuscle",0],["averagemuscle",0.5],["maxmuscle",1]],
		proportions = [["uncommonproportions",0],["",0.5],["idealproportions",1]],
		weight = [["minweight",0],["averageweight",0.5],["maxweight",1]],
		cupsize = [["mincup",0],["averagecup",0.5],["maxcup",1]],
		firmness = [["minfirmness",0],["averagefirmness",0.5],["maxfirmness",1]]
	}

static var macro_combos : Dictionary = {
		"racegenderage": ["race", "gender", "age"],
		"genderagemuscleweight": ["universal", "gender", "age", "muscle", "weight"],
		"genderagemuscleweightproportions": ["gender", "age", "muscle", "weight", "proportions"],
		"genderagemuscleweightheight": ["gender", "age", "muscle", "weight", "height"],
		"genderagemuscleweightcupsizefirmness": ["gender", "age", "muscle", "weight", "cupsize", "firmness"]
	}

const macro_options = ["age","gender","height","weight","muscle","proportions","cupsize","firmness"]

const race_options = ["african","asian","caucasian"]


static func set_macros(new_macros:Dictionary,current_targets:Dictionary):
	var changed = PackedStringArray()
	for m in macro_options:
		if m in new_macros:
			changed.append(m)
		else:
			new_macros[m] = current_targets.macro.get(m,0.5) #if macro not set, default to .5
	var race_changed = false
	for r in race_options:
		if r in new_macros:
			race_changed = true
		else:
			new_macros[r] = current_targets.macro[r]
	if race_changed:
		normalize_race_values(new_macros)
		changed.append("race")
	var new_combo_data = get_macro_target_combos(new_macros,changed)	
	#set previous combo values to 0
	for combo_name in current_targets.combo:
		for target_name in current_targets.combo[combo_name]:
			if combo_name in new_combo_data and target_name not in new_combo_data[combo_name]:
				new_combo_data[combo_name][target_name] = 0
	
	for m in new_macros:
		current_targets.macro[m] = new_macros[m]
	
	return new_combo_data
	
			
static func get_default_macros():
	var macros = {}
	for m in macro_options:
		macros[m] = .5
	for r in race_options:
		macros[r] = 1.0/race_options.size()
	return macros	

# age-gender-race , height-weight-age-gender ect..
static func get_macro_target_combos(macros:Dictionary,changed_list:PackedStringArray=[]):
	if changed_list.is_empty():
		#default to recalculate all
		for m in macro_options:
			changed_list.append(m)
		changed_list.append("race")
	
	var macro_data = {}
	#var new_targets = {}
	var new_combos = {}
	for macro_name in macros:
		if macro_name in race_options:
			macro_data[macro_name] = macros[macro_name]
		elif macro_name in macro_options:
			macro_data[macro_name] = get_macro_category_offset(macro_name,macros[macro_name])
	for combo_name in macro_combos:
		for changed_name in changed_list:
			if changed_name in macro_combos[combo_name]:
				var combo_shapekeys = get_combination_values(combo_name,macro_data)
				new_combos[combo_name] = combo_shapekeys
				break	
	return new_combos

static func normalize_race_values(macros:Dictionary):
	var total = 0
	for race in race_options:
		total += macros[race]
	if total == 1:
		return #already normalized
	elif total == 0:
		for race in race_options:
			macros[race] = 1/race_options.size()
	else:
		var ratio = 1/total
		for race in race_options:
			macros[race] *= ratio
	
static func get_combination_values(combo_name:String,data:Dictionary):
	var next_shapes = {}
	var combo_shapekeys = {""=1} # shapekey name / value pairs
	for macro_name in macro_combos[combo_name]:
		if macro_name == "universal":
			next_shapes = {"universal"=1}
		elif macro_name == "race":
			for race in race_options:
				next_shapes[race] = data[race]
		else:
			if not macro_name in data:
				# printerr("no macro data for name '" + macro_name + "'")
				# printerr(str(data))
				# print_stack()
				continue
			var curr_macro = data[macro_name]
			for shape_name in combo_shapekeys:
				for offset_counter in curr_macro.offset.size():
					var offset_id = curr_macro.offset[offset_counter]
					var new_shape_name = shape_name 
					if not shape_name == "":
						new_shape_name += "-"
					new_shape_name += macro_ranges[macro_name][offset_id][0]
					var new_shape_value = combo_shapekeys[shape_name] * curr_macro.ratio[offset_counter]
					next_shapes[new_shape_name] = new_shape_value
		combo_shapekeys = next_shapes
		next_shapes = {}
		
	for shape_name in combo_shapekeys.keys():
		if not shape_name in HumanizerTargetService.data:
			combo_shapekeys.erase(shape_name)
	
	return combo_shapekeys
	
static func get_macro_category_offset(macro_name,macro_value):
	var category = macro_ranges[macro_name]
	var offset : Array = [] # low and high offset
	var ratio : Array = [] #ratio between low (0) and high (1)
	var counter = 0
	for i in category.size():
		if macro_value == category[i][1]:
			offset = [i]
			ratio = [1]
			break
		elif macro_value < category[i][1]:
			offset = [i-1,i]
			ratio = []
			var high_ratio = (macro_value-category[i-1][1])/(category[i][1]-category[i-1][1])
			ratio.append(1-high_ratio)
			ratio.append(high_ratio)
			break
	for i in range(offset.size()-1,-1,-1): #loop backwards so it doesnt skip any when removing
		if category[offset[i]][0] == "":
			offset.remove_at(i)
			ratio.remove_at(i)
	return {offset=offset,ratio=ratio}
