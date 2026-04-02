extends Node

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
	lightningStats = {
		isSummon = true,
		damage = 20.0,
		afterAmmo = 3,
		amount = 1,
		chain = 0,
		chainDamageRetention = 0.5
	}
}, "Summon a lightning strike on a nearby enemy every 3rd weapon's shot. Lightning deals 20 Electro Damage.", true)

var ba := Option.new("Hexa Snail", {
	snailAmmount = 1,
	hexaSnailStats = {
		damage = 20,
		baseCD = 3,
		attackSpeed = 1.0
	}
}, "Summon a snail friend that strikes a random enemy with lightning every 3 seconds dealing 20 Electro Damage.")

var bb := Option.new("Chain Reaction", {}, 'Your Lighting chains to 1 additional enemy dealing half of the damage. ')

var baa := Option.new('Aggresive Snail', {}, "Hexa-snail lightning damage is increased by 50%")

var bba := Option.new('More Power Rabit!', {}, 'Chained Lightning strikes now retains +5% damage.')

var baabbaa := Option.new('Hexa Adapt', {}, 'Hexa snails lightnings gains all the effects of your lightning.')

var c := Option.new("Retribution", {
	retriStats = {
		isSummon = true,
		damage = 100.0,
		range = 500.0,
		severeJudgement = 0,
		moreFatForYou = 0
	}
}, "Summon a temporal space distortion near every enemy nearby dealing 20 Exotic Damage.", true)

var ca := Option.new("Severe Judgement", {
	killMileStoneIncreaseDBy = 0.4
}, 'Killing 500 enemies with Retribution increases Retribution Damage by 40%')

var cb := Option.new("More Fat For you", {
	killMileStoneIncreaseMaxHPBy = 100.0
}, "Killing 500 enemies with Retribution Increases your Max HP by 100.")

var cacba := Option.new('Holy Might', {}, 'For every 100 HP you currently have, increase Retribution Damage by 10.')

var d := Option.new("Silver Storm", {
	silStormStats = {
		isSummon = true,
		damage = 15.0,
		cd = 3.0
	}
}, "Summon & shoot out an ice storm every 3 seconds. Deals 15 Frost Damage to enemies on its path.", true)

var da := Option.new('Cold Wind', {}, "Freezes enemies on its path.")

var db := Option.new("Quicker Stroms", {}, "Reduce SilverStorm CD by 25%.")

var dadba := Option.new("Lightning Storm", {}, 'Lightning falls on enemies on the Storms path.')

var e := Option.new("Recall Dagger", {
	recallKnifeStats = {
		isSummon = true,
		damage = 10.0,
		cd = 2.5,
		bleedDamage = 2.0,
		amount = 1,
		toStackMult = 0
	}
}, "Summon a large dagger that shoots outwards and flies back to you, dealing 10 Damage to enemies on its path. Inflicts bleed.", true)

var ea := Option.new('Heavy Dagger', {}, "Dagger gets a KnockBack effect.")

var eb := Option.new("Quick Draw", {}, "Dagger CD Reduced by 25%") 

var eaeba := Option.new("Accumulate", {}, "Gain a stack for each enemy hit during the outward throw. Each stack increases the dagger's return damage by 2. Stacks reset on next throw.")

var eaebaa := Option.new("Soul Harveste", {}, "Get +50 max Hp for every 600 enemies killed using flying daggers.")

var f := Option.new("Aura", {
	auraStats = {
		isSummon = true,
		damage = 10.0,
		cd = 1.0,
		range = 150.0,
		killMileStoneMult = 0,
		killCount = 0
	}
}, "Gain an aura that deals 10 Exotic damage to all nearby enemies.", true)

var fa := Option.new("Rhythm Increase", {}, "Aura deals damage more frequently.")

var fb := Option.new("Aura Farm", {}, "Aura Damage doubled.")

var fc := Option.new("Broader Field", {}, "Aura range +25%")

var fafbfca := Option.new("Overflowing Might", {}, 'Every 250 enemies killed by Aura increases weapon damage by 1')

var g := Option.new("Miniature Star", {
	starAmount = 1,
	starStats = {
		isSummon = true,
		damage = 15.0,
		burnDamage = 4.0,
		cd = 4.0/TAU,
	}
}, "Summon a mini star that orbits around you and deals 15 Inferno Daamge. Inflicts burn.", true)

var ga := Option.new("More Fusion", {}, "Star increases in size by 25%.")

var gb := Option.new("Faster Orbit", {}, "Star Orbits 20% faster.")

var gagba := Option.new("Anomaly", {}, "Star collapses into a black hole.")

var gagbaa := Option.new("Feed the Monster", {},  "Black holes Event horizon enlargens by 10%")

var h := Option.new("Laser Orb", {
	orbStats = {
		isSummon = true,
		damage = 5.0,
		cd = 2.0,
		burnDamage = 4.0,
		beamThickness = 3.0,
		hasLock = false
	}
}, "Summon an Orb that shoots a weak laser beam towards nearest enemy. Inflicts short burn.", true)

var ha := Option.new("Thiccer Beam", {}, "Increase Beam Thickness and damage")

var hb := Option.new("Quicker Strikes", {}, "Reduce Laser CD by 20%.")

var hba := Option.new("Focus", {}, "Locks on and Keeps beaming an enemy until it dies. No effect on Boss.")

var hahbaa := Option.new("Eliminate", {}, "Keeps Increasing beam thickness periodically if enemy takes longer to die.")

var i := Option.new("Overload", {
	overload = true,
	overloadMultiplier = 1.7
}, "Striking a burning enemy with lightning takes critical damage.", true)

var ia := Option.new("Overload Explosion", {
	overloadExplosion = true,
	overloadExplosionMult = 0.01
}, "If the enemy dies from overload, it explodes dealing 1% of the overload damage to nearby enemies.")

var j := Option.new("Life", {
	maxHPIncrease = 50.0
}, "Max HP +50", true)

var k := Option.new("Force", {
	weaponDamageMultiplier = 1.10
}, "Weapon Damage +10%", true)

var ka := Option.new("Rhythm", {}, "For every enemy killed there is a 1% chance to get +1% Weapon damage.")

var kb := Option.new("Heavy Impact", {}, "+20% weapon damage & + 30% knockback.")

var kaa := Option.new("Monster Hunter", {}, "Killing a boss increases weapon damage by +5% & increases chances of Rhythm")

var kakba := Option.new("Rhythm Accumulate", {}, "Ammo +1. If the chance to gain damage in Rhythm fails to trigger, then add the chance to next kill. Resets upon weapon damage gain from Rhythm.")

var kaakakbaa := Option.new("Slayer's Tithe", {}, "Killing a boss will permanently increase weapons damage by 0.5% for all future descends. Only that weapons damage is increased which dealt the last blow.")

var l := Option.new("Greed", {
	pickUpRangeMultiplier = 1.5
}, "Pickup Range +50%", true) 

var m := Option.new("Faster", {
	weaponAttackSpeedMultiplier = 0.75
}, "Weapon Attack Speed +15%", true)

var ma := Option.new('Adrenaline', {}, "Taking damage increases movement speed & attack speed by 60% for 5 seconds.")

var mb := Option.new('Rapid Manifestation', {}, "Summon Attack Speed +15%")

var mamba := Option.new("Summon Adrenaline", {}, "Taking Damage now increases attack speed of Summons as well for 5 seconds.")

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
}, "Throws a gravity bomb to a random place creating a gravity zone.", true)

var na := Option.new("Crushing Weight", {}, "Gravity zone deals damage twice as fast.")

var nb := Option.new("Extended Singularity", {}, "Gravity zone radius increases by 10%.")

var nc := Option.new("Lasting Anomaly", {}, "Gravity zone remains active for 1 second longer.")

var nanbnca := Option.new("Resonance", {}, "Gravity zone resonates. Any damage dealt to an enemy within the zone is also applied to all other enemies inside the zone.")

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
}, "Drop a Bomb that ignites the ground on fire.", true)

var oa := Option.new("Quicker Wildfire", {}, "Reduce drop CD by 0.5 sec.")

var ob := Option.new("Brittle Veins", {}, "When dropped over frozen enemies, they explode into 3 ice shards, causing bleed upon hitting enemy.")

var oaa := Option.new("Rapid Ignition", {}, "Fire Area radius +20%. Reduce drop CD by 0.1 sec")

var oaoba := Option.new("Relentless Pulse", {}, "Deals damage twice as often.")

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
}, "Summon a Crystal that shoots out icicles towards enemy dealing 10 Frost damage & Freezing them.", true)

var pa := Option.new("Cryolite II", {}, 'For every 100 HP you currently have, inccrease Icicle damage by 5.')

var pb := Option.new("Cryo Increase", {}, "Throw one additional Icicle.")

var pc := Option.new("Colder", {}, "Increase freeze duration")

var pbpca := Option.new("Icicle Explosion", {}, "Frozen enemies killed with icicle, explodes into more icicles.")

var papba := Option.new("Life Steal", {}, 'Take 0.1% amount of damage dealt from an Icicle and add it to your HP.')

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
	
	var properties: Array[Dictionary] = get_property_list()
	var optionStringName: StringName = &"Option"
	for prop in properties:
		if prop.class_name == optionStringName:
			var value = get(prop.name)
			allOptions.append(value)
	
	global.PROGRESSION_CHOICE_SYSTEM = self
