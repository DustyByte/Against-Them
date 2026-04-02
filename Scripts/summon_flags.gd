extends Node2D

signal outerMostOrbitalRadiusChanged(updatedOuterMostOrbitalRadius: float)

var existingFlags: Array[Array] = [[]]
var existingOrbitals: Array[Node2D] = []
var orbitalRadiusDifference: float = 100.0
var currentOuterMostOrbitalRadius: float = 100.0
var flagsPerOrbital: int = 5
var orbitalsOrbitAngularSpeed: float = TAU / 16


func update_outer_most_orbital_radand_ping(value: float) -> void:
	currentOuterMostOrbitalRadius = value
	outerMostOrbitalRadiusChanged.emit(currentOuterMostOrbitalRadius)


func get_new_flag() -> Node2D:
	if existingFlags[-1].size() == flagsPerOrbital:
		existingFlags.append([])
	
	var r: float = existingFlags.size() * orbitalRadiusDifference
	var flagAmount: int = existingFlags[-1].size()
	var firstFlagsPosition: Vector2 = Vector2.LEFT * r
	var flag: Node2D = Node2D.new()
	
	if flagAmount == 0:
		var orbital: Node2D = Node2D.new()
		
		existingFlags[-1].append(flag)
		flag.position = firstFlagsPosition
		orbital.add_child(flag)
		
		existingOrbitals.append(orbital)
		add_child(orbital)
		
		update_outer_most_orbital_radand_ping(currentOuterMostOrbitalRadius + orbitalRadiusDifference)
		return flag
	
	existingFlags[-1].append(flag)
	flagAmount += 1
	var thetaBetweenEach: float = TAU / flagAmount
	for flagIndex in range(flagAmount):
		existingFlags[-1][flagIndex].position = firstFlagsPosition.rotated(thetaBetweenEach * flagIndex)
	
	existingOrbitals[-1].add_child(flag)
	return flag


func _process(delta: float) -> void:
	for orbitalIndex in range(existingOrbitals.size()):
		existingOrbitals[orbitalIndex].rotation += (1-orbitalIndex/10.0) * orbitalsOrbitAngularSpeed * delta
