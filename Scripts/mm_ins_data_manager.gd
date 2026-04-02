class_name MMInstanceNodeManager

var head: MMInstanceNode = null
var tail: MMInstanceNode = null
var mid: MMInstanceNode = null
var midIncrementCount: int = 1
var size: int = 1
var isEmpty: bool = true


func find_index_for(yValue: float) -> int:
	var runner: MMInstanceNode = null
	var index: int = 0
	var d1: float = 0.0
	var d2: float = 0.0
	
	if yValue < mid.position.y:
		d1 = mid.position.y - yValue
		d2 = yValue - head.position.y
		if d1 < d2:
			index = size >> 1
			runner = mid
			while true:
				if yValue > runner.prev.position.y:
					break
				runner = runner.prev
				index -= 1
			return index
		
		runner = head
		while true:
			if yValue < runner.position.y:
				break
			runner = runner.next
			index += 1
		return index
	
	d1 = yValue - mid.position.y
	d2 = tail.position.y - yValue
	
	if d1 < d2:
		runner = mid.next
		index = 1 + (size >> 1)
		
		while true:
			if yValue < runner.position.y:
				break
			runner = runner.next
			index += 1
		
		return index
	
	runner = tail
	index = size
	
	while true:
		if yValue > runner.position.y:
			break
		runner = runner.prev
		index -= 1
	
	return index


func insert(node: MMInstanceNode) -> void:
	if isEmpty:
		head = node
		tail = node
		mid = node
		
		isEmpty = false
		size += 1
		return
	
	var at: int = find_index_for(node.position.y)
	
	if at == 0:
		head.prev = node
		node.next = head
		head = node
		
		size += 1
		midIncrementCount += 1
		if midIncrementCount >= 2:
			mid = mid.prev
			midIncrementCount = 0
		
		return
	
	elif at == size:
		tail.next = node
		node.prev = tail
		tail = node
		
		size += 1
		
		midIncrementCount += 1
		if midIncrementCount >= 2:
			mid = mid.next
			midIncrementCount = 0
		
		return
	
	var runner: MMInstanceNode = null
	if at < size >> 1: 
		runner = head
		for i in range(at-1):
			runner = runner.next
		
		runner.next.prev = node
		node.next = runner.next
		runner.next = node
		node.prev = runner
		
		size += 1
		
		midIncrementCount += 1
		if midIncrementCount == 2:
			mid = mid.prev
			midIncrementCount = 0
		
		return
	
	runner = tail
	for i in range(size-at-1):
		runner = runner.prev
	
	runner.prev.next = node
	node.prev = runner.prev
	node.next = runner
	runner.prev = node
	
	size += 1
	
	midIncrementCount += 1
	if midIncrementCount == 2:
		mid = mid.prev
		midIncrementCount = 0


func print_list() -> void:
	var runner: MMInstanceNode = head
	for i in range(size):
		print(runner.position)
		runner = runner.next


func get_left_portion_size() -> int:
	var i: int = 0
	var runner: MMInstanceNode = mid
	while runner:
		runner = runner.prev
		i += 1
	return i


func get_right_portion_size() -> int:
	var i: int = 1
	var runner: MMInstanceNode = mid
	while runner:
		runner = runner.next
		i += 1
	return i
