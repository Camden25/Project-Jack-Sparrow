extends Node

const INTERPOLATION_DELAY = 0.1
const MAX_BUFFER_SIZE = 32

var buffer: Array = []  # array of dicts

var target_node: CharacterBody3D
var head_node: Node3D

func setup(player: CharacterBody3D, head: Node3D):
	target_node = player
	head_node = head

func add_snapshot(pos: Vector3, rot: Vector3, head_rot: Vector3):
	var snapshot = {
		"time": Time.get_ticks_msec() / 1000.0,
		"position": pos,
		"rotation": rot,
		"head_rotation": head_rot
	}
	buffer.append(snapshot)
	if buffer.size() > MAX_BUFFER_SIZE:
		buffer.pop_front()

func interpolate(delta: float):
	if buffer.size() < 2:
		return
	
	var render_time = (Time.get_ticks_msec() / 1000.0) - INTERPOLATION_DELAY
	
	# Find the two snapshots we're interpolating between
	var from_snapshot = null
	var to_snapshot = null
	
	for i in range(buffer.size() - 1):
		if buffer[i].time <= render_time and buffer[i + 1].time >= render_time:
			from_snapshot = buffer[i]
			to_snapshot = buffer[i + 1]
			break
	
	# If render_time is older than our buffer, use oldest
	if from_snapshot == null:
		if buffer[0].time > render_time:
			return  # not enough data yet
		# render_time is newer than buffer — use latest two
		from_snapshot = buffer[buffer.size() - 2]
		to_snapshot = buffer[buffer.size() - 1]
	
	# Calculate interpolation factor
	var time_range = to_snapshot.time - from_snapshot.time
	var t = 0.0
	if time_range > 0:
		t = (render_time - from_snapshot.time) / time_range
	t = clamp(t, 0.0, 1.0)
	
	# Apply interpolated values
	target_node.position = from_snapshot.position.lerp(to_snapshot.position, t)
	target_node.rotation = Vector3(
		lerp_angle(from_snapshot.rotation.x, to_snapshot.rotation.x, t),
		lerp_angle(from_snapshot.rotation.y, to_snapshot.rotation.y, t),
		lerp_angle(from_snapshot.rotation.z, to_snapshot.rotation.z, t)
	)
	head_node.rotation = Vector3(
		lerp_angle(from_snapshot.head_rotation.x, to_snapshot.head_rotation.x, t),
		lerp_angle(from_snapshot.head_rotation.y, to_snapshot.head_rotation.y, t),
		lerp_angle(from_snapshot.head_rotation.z, to_snapshot.head_rotation.z, t)
	)
