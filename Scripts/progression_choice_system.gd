extends Node


var b := Option.new("Lightning Strike", {
	lightningStats = {
		isSummon = true,
		damage = 20.0,
		afterAmmo = 3,
		amount = 1,
		chain = 0,
		chainDamageRetention = 0.5
	}
}, "Summon a lightning strike on a nearby enemy every 3rd weapon's shot. Lightning deals 20 Electro Damage.", 'I', "res://Assets/HUD Elements/OptionIcons/Lightning.png", true)

var ba := Option.new("Hexa Snail", {
	snailAmmount = 1,
	hexaSnailStats = {
		damage = 20,
		baseCD = 3,
		attackSpeed = 1.0
	}
}, "Summon a snail friend that strikes a random enemy with lightning every 3 seconds dealing 20 Electro Damage.", 'II.I', "res://Assets/HUD Elements/OptionIcons/Lightning.png")

var bb := Option.new("Chain Reaction", {}, 'Your Lighting chains to 1 additional enemy dealing half of the damage.', 'II.II', "res://Assets/HUD Elements/OptionIcons/Lightning.png")

var baa := Option.new('Aggresive Snail', {}, "Hexa-snail lightning damage is increased by 50%", 'III.I', "res://Assets/HUD Elements/OptionIcons/Lightning.png")

var bba := Option.new('More Power Rabit!', {}, 'Chained Lightning strikes now retains +5% damage.', 'III.II', "res://Assets/HUD Elements/OptionIcons/Lightning.png")

var baabbaa := Option.new('Hexa Adapt', {}, 'Hexa snails lightnings gains all the effects of your lightning.', 'IV.I', "res://Assets/HUD Elements/OptionIcons/Lightning.png")

var c := Option.new("Retribution", {
	retriStats = {
		isSummon = true,
		damage = 100.0,
		range = 500.0,
		severeJudgement = 0,
		moreFatForYou = 0
	}
}, "Summon a temporal space distortion near every enemy nearby dealing 20 Exotic Damage.", 'I', "res://Assets/HUD Elements/OptionIcons/Retri.png", true)

var ca := Option.new("Severe Judgement", {
	killMileStoneIncreaseDBy = 0.4
}, 'Killing 500 enemies with Retribution increases Retribution Damage by 40%', 'II.I', "res://Assets/HUD Elements/OptionIcons/Retri.png")

var cb := Option.new("More Fat For you", {
	killMileStoneIncreaseMaxHPBy = 100.0
}, "Killing 500 enemies with Retribution Increases your Max HP by 100.", 'II.II', "res://Assets/HUD Elements/OptionIcons/Retri.png")

var cacba := Option.new('Holy Might', {}, 'For every 100 HP you currently have, increase Retribution Damage by 10.', 'III.I', "res://Assets/HUD Elements/OptionIcons/Retri.png")

var d := Option.new("Silver Storm", {
	silStormStats = {
		isSummon = true,
		damage = 15.0,
		cd = 3.0
	}
}, "Summon & shoot out an ice storm every 3 seconds. Deals 15 Frost Damage to enemies on its path.", 'I', "res://Assets/HUD Elements/OptionIcons/SilverStorm.png", true)

var da := Option.new('Cold Wind', {}, "Freezes enemies on its path.", 'II.I', "res://Assets/HUD Elements/OptionIcons/SilverStorm.png")

var db := Option.new("Quicker Stroms", {}, "Reduce SilverStorm CD by 25%.", 'II.II', "res://Assets/HUD Elements/OptionIcons/SilverStorm.png")

var dadba := Option.new("Lightning Storm", {}, 'Lightning falls on enemies on the Storms path.', 'III.I', "res://Assets/HUD Elements/OptionIcons/SilverStorm.png")

var e := Option.new("Recall Dagger", {
	recallKnifeStats = {
		isSummon = true,
		damage = 10.0,
		cd = 2.5,
		bleedDamage = 2.0,
		amount = 1,
		toStackMult = 0
	}
}, "Summon a large dagger that shoots outwards and flies back to you, dealing 10 Damage to enemies on its path. Inflicts bleed.", 'I', "res://Assets/HUD Elements/OptionIcons/RecallKnife.png", true)

var ea := Option.new('Heavy Dagger', {}, "Dagger gets a KnockBack effect.", 'II.I', "res://Assets/HUD Elements/OptionIcons/RecallKnife.png")

var eb := Option.new("Quick Draw", {}, "Dagger CD Reduced by 25%", 'II.II', "res://Assets/HUD Elements/OptionIcons/RecallKnife.png") 

var eaeba := Option.new("Accumulate", {}, "Gain a stack for each enemy hit during the outward throw. Each stack increases the dagger's return damage by 2. Stacks reset on next throw.", 'III.I', "res://Assets/HUD Elements/OptionIcons/RecallKnife.png")

var eaebaa := Option.new("Soul Harveste", {}, "Get +50 max Hp for every 600 enemies killed using flying daggers.", 'IV.I', "res://Assets/HUD Elements/OptionIcons/RecallKnife.png")

var f := Option.new("Aura", {
	auraStats = {
		isSummon = true,
		damage = 10.0,
		cd = 1.0,
		range = 150.0,
		killMilestoneMult = 0,
		killCount = 0
	}
}, "Gain an aura that deals 10 Exotic damage to all nearby enemies.", 'I', "res://Assets/HUD Elements/OptionIcons/Aura.png", true)

var fa := Option.new("Rhythm Increase", {}, "Aura deals damage more frequently.", 'II.I', "res://Assets/HUD Elements/OptionIcons/Aura.png")

var fb := Option.new("Aura Farm", {}, "Aura Damage doubled.", 'II.II', "res://Assets/HUD Elements/OptionIcons/Aura.png")

var fc := Option.new("Broader Field", {}, "Aura range +25%", 'II.III', "res://Assets/HUD Elements/OptionIcons/Aura.png")

var fafbfca := Option.new("Overflowing Might", {}, 'Every 250 enemies killed by Aura increases weapon damage by 1', 'III.I', "res://Assets/HUD Elements/OptionIcons/Aura.png")

var g := Option.new("Miniature Star", {
	starAmount = 1,
	starStats = {
		isSummon = true,
		damage = 15.0,
		burnDamage = 4.0,
		cd = 4.0/TAU,
	}
}, "Summon a mini star that orbits around you and deals 15 Inferno Daamge. Inflicts burn.", 'I', "res://Assets/HUD Elements/OptionIcons/MiniStar.png", true)

var ga := Option.new("More Fusion", {}, "Star increases in size by 25%.", 'II.I', "res://Assets/HUD Elements/OptionIcons/MiniStar.png")

var gb := Option.new("Faster Orbit", {}, "Star Orbits 20% faster.", 'II.II', "res://Assets/HUD Elements/OptionIcons/MiniStar.png")

var gagba := Option.new("Anomaly", {}, "Star collapses into a black hole.", 'III.I', "res://Assets/HUD Elements/OptionIcons/MiniStar.png")

var gagbaa := Option.new("Feed the Monster", {},  "Black holes Event horizon enlargens by 10%", 'IV.I', "res://Assets/HUD Elements/OptionIcons/MiniStar.png")

var h := Option.new("Laser Orb", {
	orbStats = {
		isSummon = true,
		damage = 5.0,
		cd = 2.0,
		burnDamage = 4.0,
		beamThickness = 3.0,
		hasLock = false
	}
}, "Summon an Orb that shoots a weak laser beam towards nearest enemy. Inflicts short burn.", 'I', "res://Assets/HUD Elements/OptionIcons/LaserOrb.png", true)

var ha := Option.new("Thiccer Beam", {}, "Increase Beam Thickness and damage", 'II.I', "res://Assets/HUD Elements/OptionIcons/LaserOrb.png")

var hb := Option.new("Quicker Strikes", {}, "Reduce Laser CD by 20%.", 'II.II', "res://Assets/HUD Elements/OptionIcons/LaserOrb.png")

var hba := Option.new("Focus", {}, "Locks on and Keeps beaming an enemy until it dies. No effect on Boss.", 'III.I', "res://Assets/HUD Elements/OptionIcons/LaserOrb.png")

var hahbaa := Option.new("Eliminate", {}, "Keeps Increasing beam thickness periodically if enemy takes longer to die.", 'IV.I', "res://Assets/HUD Elements/OptionIcons/LaserOrb.png")

var i := Option.new("Overload", {
	overload = true,
	overloadMultiplier = 1.7
}, "Striking a burning enemy with lightning takes critical damage.", 'I', "res://Assets/HUD Elements/OptionIcons/Overload.png", true)

var ia := Option.new("Overload Explosion", {
	overloadExplosion = true,
	overloadExplosionMult = 0.01
}, "If the enemy dies from overload, it explodes dealing 1% of the overload damage to nearby enemies.", 'II.I', "res://Assets/HUD Elements/OptionIcons/Overload.png")

var j := Option.new("Life", {
	maxHPIncrease = 50.0
}, "Max HP +50", 'I', "res://Assets/HUD Elements/OptionIcons/HP.png", true)

var ja := Option.new("Reaper’s Rebate", {}, "Killing 100 enemies Regains 20 HP.", 'II.I', "res://Assets/HUD Elements/OptionIcons/HP.png")

var jaa := Option.new("Regen", {}, "Regain 5 HP per 5 seconds", 'III.I', "res://Assets/HUD Elements/OptionIcons/HP.png")

var k := Option.new("Force", {
	weaponDamageMultiplier = 1.10
}, "Weapon Damage +10%", 'I', "res://Assets/HUD Elements/OptionIcons/StrongerWeapon.png", true)

var ka := Option.new("Rhythm", {}, "For every enemy killed there is a 1% chance to get +1% Weapon damage.", 'II.I', "res://Assets/HUD Elements/OptionIcons/StrongerWeapon.png")

var kb := Option.new("Heavy Impact", {}, "+20% weapon damage & + 30% knockback.", 'II.II', "res://Assets/HUD Elements/OptionIcons/StrongerWeapon.png")

var kaa := Option.new("Monster Hunter", {}, "Killing a boss increases weapon damage by +5% & increases chances of Rhythm", 'III.I', "res://Assets/HUD Elements/OptionIcons/StrongerWeapon.png")

var kakba := Option.new("Rhythm Accumulate", {}, "Ammo +1. If the chance to gain damage in Rhythm fails to trigger, then add the chance to next kill. Resets upon weapon damage gain from Rhythm.", 'III.II', "res://Assets/HUD Elements/OptionIcons/StrongerWeapon.png")

var kaakakbaa := Option.new("Slayer's Tithe", {}, "Killing a boss will permanently increase weapons damage by 0.5% for all future descends. Only that weapons damage is increased which dealt the last blow.", 'IV.I', "res://Assets/HUD Elements/OptionIcons/StrongerWeapon.png")

var l := Option.new("Greed", {
	pickUpRangeMultiplier = 1.5
}, "Pickup Range +50%", 'I', "res://Assets/HUD Elements/OptionIcons/Greed.png", true)

var la : = Option.new("Momentum Pickups", {}, "Picking up an exp has 0.5% chance to increases attack speed.", 'II.I', "res://Assets/HUD Elements/OptionIcons/Greed.png")

var laa := Option.new("Recycle", {}, "Picking up an exp has 5% chance to refill 1 ammo of the selected Weapon.", 'III.I', "res://Assets/HUD Elements/OptionIcons/Greed.png")

var m := Option.new("Faster", {
	weaponAttackSpeedMultiplier = 0.75
}, "Weapon Attack Speed +15%", 'I', "res://Assets/HUD Elements/OptionIcons/Faster.png", true)

var ma := Option.new('Adrenaline', {}, "Taking damage increases movement speed & attack speed by 60% for 5 seconds.", 'II.I', "res://Assets/HUD Elements/OptionIcons/Faster.png")

var mb := Option.new('Rapid Manifestation', {}, "Summon Attack Speed +15%", 'II.II', "res://Assets/HUD Elements/OptionIcons/Faster.png")

var mamba := Option.new("Summon Adrenaline", {}, "Taking Damage now increases attack speed of Summons as well for 5 seconds.", 'III.I', "res://Assets/HUD Elements/OptionIcons/Faster.png")

var n := Option.new("Gravity Bomb", {
	gravityBombStats = {
		isSummon = true,
		amount = 1,
		damage = 5.0,
		cd = 5.0,
		hitCD = 0.5,
		damageType = global.DAMAGE_TYPES.EXOTIC,
		pullStrength = 80.0,
		duration = 3.0,
		range = 1.0,
		hasResonance = false
	}
}, "Throws a gravity bomb to a random place creating a gravity zone.", 'I', "res://Assets/HUD Elements/OptionIcons/GravityBomb.png", true)

var na := Option.new("Crushing Weight", {}, "Gravity zone deals damage twice as fast.", 'II.I', "res://Assets/HUD Elements/OptionIcons/GravityBomb.png")

var nb := Option.new("Extended Singularity", {}, "Gravity zone radius increases by 10%.", 'II.II', "res://Assets/HUD Elements/OptionIcons/GravityBomb.png")

var nc := Option.new("Lasting Anomaly", {}, "Gravity zone remains active for 1 second longer.", 'II.III', "res://Assets/HUD Elements/OptionIcons/GravityBomb.png")

var nanbnca := Option.new("Resonance", {}, "Gravity zone resonates. Any damage dealt to an enemy within the zone is also applied to all other enemies inside the zone.", 'III.I', "res://Assets/HUD Elements/OptionIcons/GravityBomb.png")

var fieryFieldIconPath: String = "res://icon.svg"
var o := Option.new("Fiery Field", {
	fieryFieldStats = {
		isSummon = true,
		amount = 1,
		damage = 7.0,
		burnDamage = 2.0,
		hitCD = 0.74,
		duration = 2.5,
		cd = 5.0,
		radius = 150.0,
		hasBrittleVeins = false
	}
}, "Drop a Bomb that ignites the ground on fire.", 'I', fieryFieldIconPath, true)

var oa := Option.new("Quicker Wildfire", {}, "Reduce drop CD by 0.5 sec.", 'II.I', fieryFieldIconPath)

var ob := Option.new("Brittle Veins", {}, "When dropped over frozen enemies, they explode into 3 ice shards, causing bleed upon hitting enemy.", 'II.II', fieryFieldIconPath)

var oaa := Option.new("Rapid Ignition", {}, "Fire Area radius +20%. Reduce drop CD by 0.1 sec", 'III.I', fieryFieldIconPath)

var oaoba := Option.new("Relentless Pulse", {}, "Deals damage twice as often.", 'III.II', fieryFieldIconPath)

var cryoliteIconPath: String = "res://Assets/HUD Elements/OptionIcons/Cryolite.png"
var p := Option.new("Cryolite", {
	cryoliteStats = {
		isSummon = true,
		amount = 1,
		damage = 15.0,
		cd = 0.75,
		knockBackIntensity = 25.0,
		damageType = global.DAMAGE_TYPES.FROST,
		freezeDuration = 2.0,
		lifeSteal = 0.0,
		icicleExplosion = false
	}
}, "Summon a Crystal that shoots out icicles towards enemy dealing 10 Frost damage & Freezing them.", 'I', cryoliteIconPath, true)

var pa := Option.new("Cryolite II", {}, 'For every 100 HP you currently have, inccrease Icicle damage by 5.', 'II.I', cryoliteIconPath)

var pb := Option.new("Cryo Increase", {}, "Throw one additional Icicle.", 'II.II', cryoliteIconPath)

var pc := Option.new("Colder", {}, "Increase freeze duration", 'II.III', cryoliteIconPath)

var pbpca := Option.new("Icicle Explosion", {}, "Frozen enemies killed with icicle, explodes into more icicles.", 'III.I', cryoliteIconPath)

var papba := Option.new("Life Steal", {}, 'Take 0.1% amount of damage dealt from an Icicle and add it to your HP.', 'III.II', cryoliteIconPath)

var hastenBeastIconPath: String = "res://Assets/HUD Elements/OptionIcons/HastenTheBeast.png"
var q := Option.new("Hasten The Beast", {}, "All summon Attack Speed +30%", 'I', hastenBeastIconPath, true)

#var qa := Option.new("Conductive Hallows", {}, "All summon attack speed +15%. Summons Have a 33% Chance to Summon a lightning strike on a random enemy.")
#
#var qb := Option.new("Glowing Hallows", {}, "All Summons Attack Speed +10%. summons have 35% chance to Call down a fire field bomb.")
#
#var qaqba := Option.new("Sync", {}, "All Summon gains attack speed equivalent to your attack speed")

var enrageBeast: String = "res://Assets/HUD Elements/OptionIcons/EnrageTheBeast.png"
var r := Option.new("Enrage The Beast", {}, "All Summon damage +30%", 'I', enrageBeast, true)

var allOptions: Array[Option] = []


func give_selectable_options(amountOfOptionsToReturn: int) -> Array[Option]:
	var availableOptions: Array[Option] = []
	for option in allOptions:
		if option.isAvailable:
			availableOptions.append(option)
	
	amountOfOptionsToReturn = clamp(amountOfOptionsToReturn, 0, availableOptions.size())
	availableOptions.shuffle()
	
	return availableOptions.slice(0, amountOfOptionsToReturn)


func _ready() -> void:
#region Lightning
	baa.augment_child(baabbaa)
	bba.augment_child(baabbaa)
	ba.augment_children([baa])
	bb.augment_children([bba])
	b.augment_children([ba, bb])
#endregion
	
#region Retribution
	c.augment_children([ca, cb])
	ca.augment_child(cacba)
	cb.augment_child(cacba)
#endregion
	
#region Silver Storm
	d.augment_children([da, db])
	da.augment_child(dadba)
	db.augment_child(dadba)
#endregion
	
#region Recall Dagger
	e.augment_children([ea, eb])
	ea.augment_child(eaeba)
	eb.augment_child(eaeba)
	eaeba.augment_child(eaebaa)
#endregion
	
#region Aura
	f.augment_children([fa, fb, fc])
	fa.augment_child(fafbfca)
	fb.augment_child(fafbfca)
	fc.augment_child(fafbfca)
#endregion
	
#region Star
	g.augment_children([ga, gb])
	ga.augment_child(gagba)
	gb.augment_child(gagba)
	gagba.augment_child(gagbaa)
#endregion
	
#region Laser Orb
	h.augment_children([ha, hb])
	hb.augment_child(hba)
	ha.augment_child(hahbaa)
	hba.augment_child(hahbaa)
#endregion
	
#region Cryolite
	p.augment_children([pa, pb, pc])
	pa.augment_child(papba)
	pb.augment_children([papba, pbpca])
	pc.augment_child(pbpca)
#endregion
	
#region Overload
	i.augment_child(ia)
#endregion
	
#region Stronger Weapon
	k.augment_children([ka, kb])
	ka.augment_children([kaa, kakba])
	kb.augment_child(kakba)
	kaa.augment_child(kaakakbaa)
	kakba.augment_child(kaakakbaa)
#endregion
	
#region Faster
	m.augment_children([ma, mb])
	ma.augment_child(mamba)
	mb.augment_child(mamba)
#endregion
	
#region Gravity Bomb
	n.augment_children([na, nb, nc])
	na.augment_child(nanbnca)
	nb.augment_child(nanbnca)
	nc.augment_child(nanbnca)
#endregion
	
#region Fiery Field
	o.augment_children([oa, ob])
	oa.augment_children([oaa, oaoba])
	ob.augment_child(oaoba)
#endregion
	
#region Life
	j.augment_child(ja)
	ja.augment_child(jaa)
#endregion
	
#region Greed
	l.augment_child(la)
	la.augment_child(laa)
#endregion
	
#region Hasten The Beast
	#q.augment_children([qa, qb])
	#qa.augment_child(qaqba)
	#qb.augment_child(qaqba)
#endregion
	
	var properties: Array[Dictionary] = get_property_list()
	var optionStringName: StringName = &"Option"
	for prop in properties:
		if prop.class_name == optionStringName:
			var value = get(prop.name)
			allOptions.append(value)
	
	global.PROGRESSION_CHOICE_SYSTEM = self
