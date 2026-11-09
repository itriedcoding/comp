class_name GameData
extends RefCounted
## Static game data: weapons, attachments, missions, modes, difficulty tuning.

const WEAPONS := {
	"kx15": {
		"name": "KX-15",
		"class": "Assault Rifle",
		"caliber": "5.56x45mm",
		"damage": 31.0,
		"headshot": 3.3,
		"limb": 0.72,
		"rpm": 740.0,
		"fire_mode": "auto",
		"burst_count": 3,
		"burst_delay": 0.085,
		"mag": 30,
		"reserve": 210,
		"reload_tac": 2.05,
		"reload_empty": 2.65,
		"draw": 0.55,
		"spread_hip": 2.4,
		"spread_ads": 0.12,
		"spread_move": 1.9,
		"spread_air": 4.5,
		"recoil_v": 0.72,
		"recoil_h": 0.34,
		"recoil_recovery": 8.0,
		"recoil_stiffness": 26.0,
		"penetration": 2,
		"range": 320.0,
		"falloff_start": 45.0,
		"falloff_end": 150.0,
		"falloff_min": 0.62,
		"ads_zoom": 1.35,
		"ads_time": 0.17,
		"noise": 62.0,
		"pellets": 1,
		"pellet_spread": 0.0,
		"sound": "shot_rifle",
		"weight": 1.0,
		"optic_options": ["none", "red_dot", "holo", "acog"],
		"viewmodel": {"length": 0.62, "height": 0.10, "width": 0.075, "barrel": 0.30, "stock": true, "magazine": "curved", "rail": 0.32},
	},
	"m14": {
		"name": "M14 EBR",
		"class": "Designated Marksman Rifle",
		"caliber": "7.62x51mm",
		"damage": 68.0,
		"headshot": 2.6,
		"limb": 0.8,
		"rpm": 220.0,
		"fire_mode": "semi",
		"burst_count": 1,
		"burst_delay": 0.0,
		"mag": 20,
		"reserve": 120,
		"reload_tac": 2.5,
		"reload_empty": 3.1,
		"draw": 0.7,
		"spread_hip": 3.6,
		"spread_ads": 0.04,
		"spread_move": 2.8,
		"spread_air": 6.0,
		"recoil_v": 1.85,
		"recoil_h": 0.6,
		"recoil_recovery": 6.0,
		"recoil_stiffness": 20.0,
		"penetration": 3,
		"range": 500.0,
		"falloff_start": 90.0,
		"falloff_end": 300.0,
		"falloff_min": 0.78,
		"ads_zoom": 2.0,
		"ads_time": 0.24,
		"noise": 78.0,
		"pellets": 1,
		"pellet_spread": 0.0,
		"sound": "shot_dmr",
		"weight": 1.35,
		"optic_options": ["none", "red_dot", "acog", "scope_4x"],
		"viewmodel": {"length": 0.78, "height": 0.11, "width": 0.08, "barrel": 0.44, "stock": true, "magazine": "box", "rail": 0.36},
	},
	"m590": {
		"name": "M590 Tactical",
		"class": "Pump Shotgun",
		"caliber": "12 gauge",
		"damage": 13.0,
		"headshot": 1.9,
		"limb": 0.75,
		"rpm": 75.0,
		"fire_mode": "pump",
		"burst_count": 1,
		"burst_delay": 0.0,
		"mag": 7,
		"reserve": 48,
		"reload_tac": 3.4,
		"reload_empty": 3.8,
		"draw": 0.65,
		"spread_hip": 3.2,
		"spread_ads": 1.6,
		"spread_move": 2.0,
		"spread_air": 5.0,
		"recoil_v": 2.4,
		"recoil_h": 0.8,
		"recoil_recovery": 5.5,
		"recoil_stiffness": 18.0,
		"penetration": 1,
		"range": 90.0,
		"falloff_start": 8.0,
		"falloff_end": 40.0,
		"falloff_min": 0.25,
		"ads_zoom": 1.15,
		"ads_time": 0.2,
		"noise": 86.0,
		"pellets": 9,
		"pellet_spread": 2.6,
		"pump_time": 0.75,
		"sound": "shot_shotgun",
		"weight": 1.2,
		"optic_options": ["none", "red_dot"],
		"viewmodel": {"length": 0.72, "height": 0.10, "width": 0.08, "barrel": 0.42, "stock": true, "magazine": "tube", "rail": 0.2},
	},
	"mp5": {
		"name": "MP5-K",
		"class": "Submachine Gun",
		"caliber": "9x19mm",
		"damage": 22.0,
		"headshot": 2.8,
		"limb": 0.7,
		"rpm": 880.0,
		"fire_mode": "auto",
		"burst_count": 3,
		"burst_delay": 0.075,
		"mag": 30,
		"reserve": 240,
		"reload_tac": 1.75,
		"reload_empty": 2.3,
		"draw": 0.42,
		"spread_hip": 2.0,
		"spread_ads": 0.22,
		"spread_move": 1.3,
		"spread_air": 3.8,
		"recoil_v": 0.48,
		"recoil_h": 0.28,
		"recoil_recovery": 9.0,
		"recoil_stiffness": 30.0,
		"penetration": 1,
		"range": 180.0,
		"falloff_start": 25.0,
		"falloff_end": 80.0,
		"falloff_min": 0.5,
		"ads_zoom": 1.25,
		"ads_time": 0.14,
		"noise": 52.0,
		"pellets": 1,
		"pellet_spread": 0.0,
		"sound": "shot_smg",
		"weight": 0.75,
		"optic_options": ["none", "red_dot", "holo"],
		"viewmodel": {"length": 0.5, "height": 0.095, "width": 0.065, "barrel": 0.18, "stock": true, "magazine": "curved", "rail": 0.24},
	},
	"p226": {
		"name": "P226",
		"class": "Sidearm",
		"caliber": "9x19mm",
		"damage": 26.0,
		"headshot": 3.0,
		"limb": 0.8,
		"rpm": 400.0,
		"fire_mode": "semi",
		"burst_count": 1,
		"burst_delay": 0.0,
		"mag": 15,
		"reserve": 90,
		"reload_tac": 1.55,
		"reload_empty": 2.0,
		"draw": 0.3,
		"spread_hip": 2.2,
		"spread_ads": 0.3,
		"spread_move": 1.5,
		"spread_air": 4.0,
		"recoil_v": 0.95,
		"recoil_h": 0.4,
		"recoil_recovery": 10.0,
		"recoil_stiffness": 32.0,
		"penetration": 1,
		"range": 120.0,
		"falloff_start": 20.0,
		"falloff_end": 60.0,
		"falloff_min": 0.55,
		"ads_zoom": 1.2,
		"ads_time": 0.13,
		"noise": 48.0,
		"pellets": 1,
		"pellet_spread": 0.0,
		"sound": "shot_pistol",
		"weight": 0.6,
		"optic_options": ["none", "red_dot"],
		"viewmodel": {"length": 0.28, "height": 0.10, "width": 0.05, "barrel": 0.1, "stock": false, "magazine": "pistol", "rail": 0.1},
	},
}

const ATTACHMENTS := {
	"none": {"name": "None", "slot": "optic", "zoom": 1.0, "spread_mult": 1.0, "desc": "Iron sights."},
	"red_dot": {"name": "T-1 Red Dot", "slot": "optic", "zoom": 1.3, "spread_mult": 0.92, "desc": "Low-profile reflex sight. Fast target acquisition."},
	"holo": {"name": "H-552 Holo", "slot": "optic", "zoom": 1.4, "spread_mult": 0.88, "desc": "Holographic sight with a wide window."},
	"acog": {"name": "TA31 3.5x", "slot": "optic", "zoom": 3.2, "spread_mult": 0.78, "desc": "Prismatic combat optic for medium range."},
	"scope_4x": {"name": "Mk4 6x", "slot": "optic", "zoom": 5.0, "spread_mult": 0.55, "desc": "High-magnification precision scope."},
	"suppressor": {"name": "QD Suppressor", "slot": "suppressor", "noise": 0.34, "damage": 0.94, "recoil": 0.92, "desc": "Cuts muzzle report and flash. Slightly reduces velocity."},
	"extended": {"name": "Extended Mag", "slot": "magazine", "mag_mult": 1.5, "reload_add": 0.18, "desc": "More rounds, slower reload."},
	"vertical": {"name": "Vertical Grip", "slot": "grip", "recoil": 0.80, "sway": 0.82, "desc": "Reduces vertical recoil and sway."},
	"angled": {"name": "Angled Grip", "slot": "grip", "recoil": 0.9, "ads_time": 0.85, "sway": 0.9, "desc": "Faster aim down sights with moderate recoil control."},
}

const PRIMARY_OPTIONS := ["kx15", "m14", "m590"]
const SECONDARY_OPTIONS := ["mp5"]
const SIDEARM_OPTIONS := ["p226"]

const DIFFICULTY := {
	"Recruit": {
		"label": "Recruit",
		"desc": "Light resistance. Enemies are slower to react and less accurate.",
		"damage": 0.55, "health": 0.85, "accuracy": 0.55, "reaction": 1.6,
		"detection": 0.7, "aggression": 0.6, "count": 0.85, "fire_rate": 0.75,
	},
	"Regular": {
		"label": "Regular",
		"desc": "Standard threat level. Balanced accuracy and reaction times.",
		"damage": 1.0, "health": 1.0, "accuracy": 1.0, "reaction": 1.0,
		"detection": 1.0, "aggression": 1.0, "count": 1.0, "fire_rate": 1.0,
	},
	"Veteran": {
		"label": "Veteran",
		"desc": "Trained operators. They flank, suppress and use cover well.",
		"damage": 1.35, "health": 1.25, "accuracy": 1.35, "reaction": 0.75,
		"detection": 1.3, "aggression": 1.35, "count": 1.1, "fire_rate": 1.1,
	},
	"Elite": {
		"label": "Elite",
		"desc": "Hardened unit. Fast, precise, relentless. Not forgiving.",
		"damage": 1.7, "health": 1.5, "accuracy": 1.7, "reaction": 0.55,
		"detection": 1.6, "aggression": 1.7, "count": 1.2, "fire_rate": 1.25,
	},
}

const MISSIONS := [
	{
		"id": "m1",
		"name": "Cold Storage",
		"location": "Kessler Industrial Complex",
		"map": "industrial",
		"time": "Dusk",
		"weather": "Overcast",
		"briefing": "A private military contractor has turned the Kessler warehouse into a weapons depot. Move in quietly, clear the loading floor, recover the shipping manifest and exfiltrate through the south gate.",
		"objectives": [
			{"type": "reach", "marker": "entry", "label": "Infiltrate the loading bay"},
			{"type": "eliminate", "count": 8, "label": "Clear hostile presence"},
			{"type": "reach", "marker": "intel", "label": "Recover the shipping manifest"},
			{"type": "extract", "marker": "extract", "label": "Exfiltrate via the south gate"},
		],
		"enemies": 10,
		"par_time": 420.0,
	},
	{
		"id": "m2",
		"name": "Dead Signal",
		"location": "Sokol Heights, Sector 4",
		"map": "urban",
		"time": "Night",
		"weather": "Rain",
		"briefing": "The network that bought the manifest is operating out of an apartment block in Sokol Heights. Cut through the plaza, breach the ground floor and destroy the comms relay on the roof before they can burn the intel.",
		"objectives": [
			{"type": "reach", "marker": "plaza", "label": "Cross the plaza"},
			{"type": "destroy", "marker": "relay", "label": "Destroy the comms relay"},
			{"type": "eliminate", "count": 12, "label": "Neutralise the response team"},
			{"type": "extract", "marker": "extract", "label": "Reach the extraction point"},
		],
		"enemies": 14,
		"par_time": 540.0,
	},
	{
		"id": "m3",
		"name": "Iron Ridge",
		"location": "Verkhout Ridge Outpost",
		"map": "outpost",
		"time": "Dawn",
		"weather": "Fog",
		"briefing": "The relay traffic leads to a border outpost dug into the ridge. Push uphill through the treeline, silence the watchtower, secure the command bunker and recover the operation ledger.",
		"objectives": [
			{"type": "eliminate", "count": 10, "label": "Break the perimeter"},
			{"type": "reach", "marker": "bunker", "label": "Secure the command bunker"},
			{"type": "reach", "marker": "ledger", "label": "Recover the operation ledger"},
			{"type": "extract", "marker": "extract", "label": "Withdraw to the landing zone"},
		],
		"enemies": 16,
		"par_time": 660.0,
	},
]

const MODES := {
	"campaign": {
		"name": "Campaign",
		"tagline": "Three linked operations. Full mission briefings.",
		"desc": "Infiltrate the Kessler depot, break the Sokol Heights network and take the Verkhout ridge outpost. Objectives, checkpoints and progression.",
	},
	"training": {
		"name": "Shooting Range",
		"tagline": "Timed drills on the indoor range.",
		"desc": "Three drills with pop-up targets, accuracy scoring and grades. Learn recoil control, tracking and reload timing.",
	},
	"survival": {
		"name": "Survival",
		"tagline": "Endless waves in the warehouse.",
		"desc": "Hold the loading floor against escalating waves. Earn credits for kills, resupply between waves, see how long you last.",
	},
	"tactical": {
		"name": "Tactical Mission",
		"tagline": "Stealth extraction under a time limit.",
		"desc": "Recover the intel without raising the alarm. Suppressed weapons and quiet movement matter. If the alarm sounds, reinforcements arrive.",
	},
	"botmatch": {
		"name": "Bot Match",
		"tagline": "Offline deathmatch against AI operators.",
		"desc": "Seven bots hunt you on the urban map. First to 25 eliminations. Full AI combat behaviour, no network required.",
	},
}

const BOT_NAMES := ["HARRIS", "VOLKOV", "MERCER", "OKAFOR", "REYES", "LINDQVIST", "TANAKA", "BRANDT", "KOVAC", "SIERRA"]

const MATERIAL_SURFACES := {
	"concrete": {"footstep": "concrete", "impact": "impact_concrete", "penetrable": false, "damage_mult": 1.0, "decal": "concrete"},
	"metal": {"footstep": "metal", "impact": "impact_metal", "penetrable": true, "damage_mult": 0.9, "decal": "metal", "pen_power": 2},
	"wood": {"footstep": "wood", "impact": "impact_wood", "penetrable": true, "damage_mult": 1.0, "decal": "wood", "pen_power": 3},
	"glass": {"footstep": "concrete", "impact": "impact_glass", "penetrable": true, "damage_mult": 0.8, "decal": "glass", "pen_power": 4},
	"dirt": {"footstep": "dirt", "impact": "impact_dirt", "penetrable": false, "damage_mult": 1.0, "decal": "dirt"},
	"grass": {"footstep": "grass", "impact": "impact_dirt", "penetrable": false, "damage_mult": 1.0, "decal": "dirt"},
	"flesh": {"footstep": "concrete", "impact": "impact_flesh", "penetrable": true, "damage_mult": 1.0, "decal": "blood", "pen_power": 1},
}


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["kx15"])


static func weapon_name(id: String) -> String:
	return String(weapon(id)["name"])


static func mission_index(mission_id: String) -> int:
	for i in MISSIONS.size():
		if MISSIONS[i]["id"] == mission_id:
			return i
	return -1


static func mission(mission_id: String) -> Dictionary:
	var index := mission_index(mission_id)
	if index < 0:
		return MISSIONS[0]
	return MISSIONS[index]


static func mission_by_map(map_id: String) -> Dictionary:
	for m in MISSIONS:
		if m["map"] == map_id:
			return m
	return MISSIONS[0]


static func surface(surface_id: String) -> Dictionary:
	return MATERIAL_SURFACES.get(surface_id, MATERIAL_SURFACES["concrete"])


static func attachment_options(slot: String) -> Array:
	var out: Array = []
	for id in ATTACHMENTS.keys():
		if ATTACHMENTS[id]["slot"] == slot:
			out.append(id)
	return out


static func attachment(slot: String, id: String) -> Dictionary:
	var att: Dictionary = ATTACHMENTS.get(id, {})
	if String(att.get("slot", "")) != slot:
		return ATTACHMENTS["none"] if slot == "optic" else {"name": "None", "slot": slot}
	return att


## Returns the effective stats for a weapon after its attachments.
static func resolved_weapon(weapon_id: String, attachments: Dictionary) -> Dictionary:
	var stats: Dictionary = weapon(weapon_id).duplicate(true)
	var optic := attachment("optic", String(attachments.get("optic", "none")))
	stats["ads_zoom"] = float(stats["ads_zoom"]) * float(optic.get("zoom", 1.0))
	stats["spread_ads"] = float(stats["spread_ads"]) * float(optic.get("spread_mult", 1.0))
	var supp := attachment("suppressor", String(attachments.get("suppressor", "none")))
	if String(attachments.get("suppressor", "none")) == "suppressor":
		stats["noise"] = float(stats["noise"]) * float(supp.get("noise", 1.0))
		stats["damage"] = float(stats["damage"]) * float(supp.get("damage", 1.0))
		stats["recoil_v"] = float(stats["recoil_v"]) * float(supp.get("recoil", 1.0))
		stats["suppressed"] = true
	else:
		stats["suppressed"] = false
	if String(attachments.get("magazine", "standard")) == "extended":
		var ext := ATTACHMENTS["extended"]
		stats["mag"] = int(round(float(stats["mag"]) * float(ext["mag_mult"])))
		stats["reload_tac"] = float(stats["reload_tac"]) + float(ext["reload_add"])
		stats["reload_empty"] = float(stats["reload_empty"]) + float(ext["reload_add"])
	var grip := String(attachments.get("grip", "none"))
	if grip != "none":
		var g: Dictionary = ATTACHMENTS.get(grip, {})
		stats["recoil_v"] = float(stats["recoil_v"]) * float(g.get("recoil", 1.0))
		stats["recoil_h"] = float(stats["recoil_h"]) * float(g.get("recoil", 1.0))
		stats["ads_time"] = float(stats["ads_time"]) * float(g.get("ads_time", 1.0))
	return stats
