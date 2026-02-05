extends Node2D

@onready var player: CharacterBody2D = $"../Player"

var a := Option.new("Dragon", {
	dragonAmount = 1,
	summonStats = {
		damage = 10,
		ammoAmount = 3,
		baseCD = 3,
		attackSpeed = 0.0
	}
}, "Summon a tiny dragon that throws fire onto enemies. Deals 10 damage & inflicts burn", true)

var b := Option.new("Lightning Strike", {
	L_StrikeOnShoot = true,
	L_StrikeDamage = 20,
	L_StrikeAfterAmmo = 3,
	L_StrikeAmount = 1
}, "Summon a lightning strike on a nearby enemy every 3rd weapon's shot. Lightning deals 20 Electro Damage.", true)

var c := Option.new("Retribution", {
	retriDamage = 20,
	shotAfterLastAmmo = true
}, "Summon a temporal space distortion near every enemy nearby dealing 20 Exotic Damage.", true)

var d := Option.new("Silver Storm", {
	silStormDamage = 15,
}, "Summon & shoot out an ice storm every 3 seconds. Deals 15 Frost Damage to enemies on its path.", true)

var e := Option.new("Dagger", {
	daggerAmount = 2,
	summonStats = {
		damage = 10,
		baseCD = 2.5,
		attackSpeed = 0.0,
		bleedDamage = 2
	}
}, "Summon a large dagger that shoots outwards and flies back to you, dealing 10 Damage to enemies on its path. Inflicts bleed.", true)

var f := Option.new("Aura", {
	effectStats = {
		damage = 10,
		baseCD = 2,
		attackSpeed = 0.0,
		range = 100
	}
}, "Gain an aura that deals 10 Exotic damage to all nearby enemies.", true)

var g := Option.new("Miniature Star", {
	orbAmount = 1,
	starStats = {
		damage = 30,
		baseCD = 4,
		attackSpeed = 1.0
	}
}, "Summon a gravity orb that orbits around you and deals 30 Exotic Daamge.", true)

var h := Option.new("Laser Drone", {
	droneAmount = 1,
	summonStats = {
		damage = 5,
		baseCD = 2,
		attackSpeed = 0.0,
		burnDamage = 3
	}
}, "Summon a drone that shoots a weak laser beam towards a random direction. Inflicts short burn.", true)

var ba := Option.new("Hexa Snail", {
	snailAmmount = 1,
	hexaSnailStats = {
		isSummon = true,
		damage = 20,
		baseCD = 3,
		attackSpeed = 1.0
	}
}, "Summon a snail friend that strikes a random enemy with lightning every 3 seconds dealing 20 Electro Damage.")


var optionTree: Array[Option] = [a, b, c, d, e, f, g, h]
var allOptions: Array[Option] = [a, b, c, d, e, f, g, h, ba]


func give_selectable_options(amountOfOptionsToReturn: int, _playerState: Dictionary = {}) -> Array:
	var tempAllOptionsArr: Array[Option] = []
	for option in allOptions:
		if option.isAvailable:
			tempAllOptionsArr.append(option.duplicate_deep())
	
	tempAllOptionsArr.shuffle()
	
	return tempAllOptionsArr.slice(0, amountOfOptionsToReturn)


func _ready() -> void:
	b.augment_child(ba)
