##Copyright (c) 2024 Fritz Menzer
##
## Permission is hereby granted, free of charge, to any
## person obtaining a copy of this software and associated
## documentation files (the "Software"), to deal in the
## Software without restriction, including without
## limitation the rights to use, copy, modify, merge,
## publish, distribute, sublicense, and/or sell copies of
## the Software, and to permit persons to whom the Software
## is furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice
## shall be included in all copies or substantial portions
## of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
## ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
## TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
## PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
## SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
## ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
## ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
## OR OTHER DEALINGS IN THE SOFTWARE.


extends Node

# Export the NodePath for the Horizon Center node
export(NodePath) var horizon_center: NodePath

# Export the NodePath for the Room Floor node
export(NodePath) var room_floor: NodePath

export var floor_corner_0: Vector3 = Vector3()
export var floor_corner_1: Vector3 = Vector3()
export var floor_corner_2: Vector3 = Vector3()
export var floor_corner_3: Vector3 = Vector3()

export var listener_height: float = 1.7
export var angle_offset:    float = 0.0

# horizon:
var yh: float             # y coordinate of horizon
var xc: float             # x coordinate of center (used for scaling)
# edge definitions:
var a = [0.0, 0.0, 0.0, 0.0]
var b = [0.0, 0.0, 0.0, 0.0]
var c = [1.0, 1.0, 1.0, 1.0]
var xp: Array
var yp: Array
# room
var room						# room Node
var bgh						# background height
# player
var player					# player Node
# network
var udp = PacketPeerUDP.new()	# UDP connection to renderer


func _ready():
	# set up communication link via UDP
	udp.set_dest_address("127.0.0.1", 53914)
	var rf: Polygon2D         # room floor
	# get room (cannot get player here as it's not instantiated yet)
	room = get_parent() as Node
	# get background
	var background = room.get_node("Background") 
	assert(background != null, "Background not found or assigned correctly.")
	# Get the height of the background image
	bgh = background.texture.get_height() as float
	assert(bgh > 0, "Room must have a background (with nonzero height)")

	# Fetch the horizon center node from the exported NodePath
	var hc
	if horizon_center:
		hc = get_node(horizon_center) as Position2D
	
	# make sure room floor is a polygon with 4 corners
	assert(hc != null && hc is Position2D, "Horizon Center must be a Position2D.")
	
	# Fetch the room floor node from the exported NodePath
	if room_floor:
		rf = get_node(room_floor) as Polygon2D
	
	# make sure room floor is a polygon with 4 corners
	assert(rf != null && rf is Polygon2D && rf.polygon.size() == 4, "Room Floor must be a Polygon2D with four corners.")
	
	# go through all corners of the room floor and scale them
	var points = rf.polygon
	yh = hc.position.y
	xc = hc.position.x
	print(hc.position)
	for point in points:
		var x = point.x as float
		var y = point.y as float
		var s = (bgh-yh)/(y-yh)
		var ys = s*(y-bgh);
		var xs = (x-xc)*s + xc;
		xp.append(xs)
		yp.append(ys)
		print("(",x,",",y,") => (",xs,",",ys,")")
	
	# create line definitions
	for i in range(4):
		var i2 = (i + 1) % 4
		var denom = xp[i2] * yp[i] - xp[i] * yp[i2]
		if abs(denom)>0.0000001: # roughly "epsilon" for float32
			a[i] = (yp[i] - yp[i2]) / denom
			b[i] = (xp[i2] - xp[i]) / denom
		else:
			c[i] = 0
			var x_
			var y_
			if max(abs(xp[i]), abs(yp[i])) > max(abs(xp[i2]), abs(yp[i2])):
				x_ = xp[i]
				y_ = yp[i]
			else:
				x_ = xp[i2]
				y_ = yp[i2]

			if abs(x_) > abs(y_):
				a[i] = -y_ / x_
				b[i] = 1
			else:
				a[i] = 1
				b[i] = -x_ / y_
				
	print("a: ", a)
	print("b: ", b)
	print("c: ", c)
	print("xp: ", xp)
	print("yp: ", yp)

# function that computes the linear interpolations weights
# (relative to the corners of the Room Floor quadrilateral)
# based on x and y positions on the screen (must be inside
# Room Floor for weights between 0 and 1).
func floor_weights(position):
	var x = position.x
	var y = position.y
#	print("x: ", x, "  y: ", y)
	var s = (bgh-yh)/(y-yh)
	var ys = s*(y-bgh);
	var xs = (x-xc)*s + xc;
#	print("xs: ", xs, "  ys: ", ys)
	# Compute scaling between first and third line
	var K = (c[0] - a[0] * xs - b[0] * ys) / (xs * (a[2] - a[0]) + ys * (b[2] - b[0]) + c[0] - c[2])
	# Compute line going through xs and ys
	var A = a[0] * (1 - K) + a[2] * K
	var B = b[0] * (1 - K) + b[2] * K
	var C = c[0] * (1 - K) + c[2] * K
	# Determine where this line intersects the second line
	var wx
	if abs(xp[2] - xp[1]) > 0:
		var xi = (c[1] * B - C * b[1]) / (a[1] * B - A * b[1])
		wx = (xi - xp[1]) / (xp[2] - xp[1])
	else:
		var yi = (a[1] * C - A * c[1]) / (a[1] * B - A * b[1])
		wx = (yi - yp[1]) / (yp[2] - yp[1])
	# Compute scaling between second and fourth line
	K = (c[1] - a[1] * xs - b[1] * ys) / (xs * (a[3] - a[1]) + ys * (b[3] - b[1]) + c[1] - c[3])
	# Compute line going through xs and ys
	A = a[1] * (1 - K) + a[3] * K
	B = b[1] * (1 - K) + b[3] * K
	C = c[1] * (1 - K) + c[3] * K
	# Determine where this line intersects the first line
	var wy
	if abs(xp[1] - xp[0]) > 0:
		var xi = (c[0] * B - C * b[0]) / (a[0] * B - A * b[0])
		wy = (xi - xp[0]) / (xp[1] - xp[0])
	else:
		var yi = (a[0] * C - A * c[0]) / (a[0] * B - A * b[0])
		wy = (yi - yp[0]) / (yp[1] - yp[0])
	
	return Vector2(wx, wy)

func floor_position(position):
	var w = floor_weights(position)
	var x = (floor_corner_0.x*(1.0-w.y)+floor_corner_1.x*w.y)*(1.0-w.x) + (floor_corner_3.x*(1.0-w.y)+floor_corner_2.x*w.y)*w.x
	var y = (floor_corner_0.y*(1.0-w.y)+floor_corner_1.y*w.y)*(1.0-w.x) + (floor_corner_3.y*(1.0-w.y)+floor_corner_2.y*w.y)*w.x
	var z = (floor_corner_0.z*(1.0-w.y)+floor_corner_1.z*w.y)*(1.0-w.x) + (floor_corner_3.z*(1.0-w.y)+floor_corner_2.z*w.y)*w.x
	return [x, y, z]
	
func character_angle(character):
	# get angle based on animation name
	var aplayer = character.get_animation_player()
	var animation_name = aplayer.get_animation()
	var angle = 180 # by default, character is facing user
	if animation_name.ends_with("up"):
		angle = 0
	elif animation_name.ends_with("upright"):
		angle = 45
	elif animation_name.ends_with("right"):
		angle = 90
	elif animation_name.ends_with("downright"):
		angle = 135
	elif animation_name.ends_with("down"):
		angle = 180
	elif animation_name.ends_with("downleft"):
		angle = 225
	elif animation_name.ends_with("left"):
		angle = 270
	elif animation_name.ends_with("upleft"):
		angle = 315
	# reverse angle if mirrored
	var sprite = character.get_node("AnimatedSprite")
	if sprite.scale.x < 0:
		angle = 360-angle
	return angle

func _physics_process(delta):
	# apparently room.player is not ready when _ready() is called. Let's get the player here (once)
	if !player:
		player = room.player
	if player:
		var pos = floor_position(player.position)
		var azi = fmod(character_angle(player) + angle_offset, 360.0)
		pos[2] += listener_height
		var message = to_json({"lst":{"pos": pos, "azi": azi}})
		print(message)
		udp.put_packet(message.to_utf8())
