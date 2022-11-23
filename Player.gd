extends KinematicBody2D

var runSpeed = 9.5 # acceleration
var machSpeed = 0
var speedCap = 1200
var groundFriction = 0.99
var airFriction = 0.995
var frictionMultA = 0.98
var frictionMultB = 0.96
var jumpSpeed = -400
var gravity = 800
var globalVelocity = Vector2()
var localVelocity = Vector2()
var jumpVelocity = Vector2()
var snap = Vector2.ZERO # snap vector
var lastNormal = Vector2.ZERO
var leftFloor = false
var machGravity = 0
var jumpAnim = false
enum states {
	GROUND,
	AIR,
	G_MACH
}
var state : int = states.GROUND


var horiz
var jump
var jumpnt

func get_input():
	horiz =  Input.get_axis("ui_left","ui_right") # simplified left-right check
	jump = Input.is_action_just_pressed('ui_up')
	jumpnt = Input.is_action_just_released('ui_up') #for variable jump height

func state_process():
	match state:
		states.GROUND, states.G_MACH:
			if (jump):
				$JumpBufferTimer.start(0.15)
			if (!is_on_floor()):
				state = states.AIR
			else:
				$CoyoteTimer.start(0.15)
			if $JumpBufferTimer.time_left > 0 and $CoyoteTimer.time_left > 0:
				jumpVelocity = global_transform.y * jumpSpeed
				localVelocity = localVelocity.rotated(rotation)
				jumpAnim = true
				snap = Vector2.ZERO
				state = states.AIR
			horizontal_friction(groundFriction)
			continue;
		states.GROUND:
			if (abs(localVelocity.x)>=machSpeed):
				state = states.G_MACH
		states.G_MACH:
			if (abs(localVelocity.x)<machSpeed):
				state = states.GROUND
		states.AIR:
			if (is_on_floor()):
				state = states.GROUND
				jumpAnim = false
			horizontal_friction(airFriction)
		_:
			pass


func horizontal_friction(friction):
	localVelocity.x = localVelocity.x*friction
	if horiz==0: 
		localVelocity.x = localVelocity.x*frictionMultA 
		if abs(localVelocity.x)<100: 
			localVelocity.x=localVelocity.x*frictionMultB 
	elif horiz!=localVelocity.x/abs(localVelocity.x): 
		localVelocity.x = localVelocity.x*frictionMultB
	localVelocity.x+=horiz*runSpeed
	localVelocity.x = clamp(localVelocity.x,-speedCap,speedCap)

func animate():
	$AnimatedSprite.speed_scale = 1
	if jumpAnim:
		$AnimatedSprite.animation = "ball"
		return
	if (abs(localVelocity.x)>20):
		$AnimatedSprite.flip_h = true if localVelocity.x/abs(localVelocity.x)==-1 else false
	match state:
		states.GROUND:
			if (abs(localVelocity.x)<20):
				$AnimatedSprite.animation = "idle"
			elif abs(localVelocity.x)<(machSpeed-50):
				$AnimatedSprite.animation = "walk"
				$AnimatedSprite.speed_scale = 1.5*abs(localVelocity.x)/(machSpeed-50) # walk animation goes faster the faster you go until you start running
			else:
				$AnimatedSprite.animation = "run"
		states.AIR:
			pass
		states.G_MACH:
			$AnimatedSprite.animation = "mach"
		_:
			pass

func _physics_process(delta):
	get_input()
	state_process()
	localVelocity.x = localVelocity.x if abs(localVelocity.x)>3 else 0
	if state!=states.AIR:
		rotation = getShortestFloorCast().get_collision_normal().angle() + PI/2 # align with floor when we're on it
	else:
		rotation = 0 
	globalVelocity = localVelocity.rotated(rotation)
	if state != states.G_MACH:
		globalVelocity+=Vector2(0,gravity*delta)
	else:
		localVelocity.y+=40
		globalVelocity = localVelocity.rotated(rotation)
	globalVelocity += jumpVelocity
	jumpVelocity = Vector2.ZERO
	globalVelocity = move_and_slide_with_snap(globalVelocity,snap,-global_transform.y)
	snap = global_transform.y * 75 if (-localVelocity.y<gravity*delta || gravity_off()) else Vector2.ZERO
	localVelocity = globalVelocity.rotated(-rotation)
	animate()

func is_on_floor():
	return getShortestFloorCast().is_colliding() # custom is_on_floor() detection cause the official one doesn't work very well here

func gravity_off():
	return abs(localVelocity.x)>machSpeed && abs(rotation_degrees)>60

func getShortestFloorCast():
	if ((global_position-$FloorCast1.get_collision_point()).length()>(global_position-$FloorCast2.get_collision_point()).length()):
		return $FloorCast2
	else:
		return $FloorCast1
