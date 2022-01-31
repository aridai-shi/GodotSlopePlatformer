extends KinematicBody2D

var run_speed = 8.5 # acceleration
var jump_speed = -500
var gravity = 800
var velocity = Vector2.ZERO
var jumping = false # in charge of the jumping ""state"" and animations
var dir = true # in charge of animation direection
var speed_cap = 1200
var gravity_speed = 550
var snap = Vector2.ZERO # snap vector
var stoppingRunning = false; # purely in charge of switching to the idle animation sooner - to be ignored
var lastNormal = Vector2.ZERO
var leftFloor = false
var secondaryGravity = 0

func get_input(delta):
	if Input.is_action_just_pressed("ui_down"):
		Engine.time_scale = 0.017
	var horiz =  Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left") # simplified left-right check
	var jump = Input.is_action_just_pressed('ui_up')
	var jumpnt = Input.is_action_just_released('ui_up') #for variable jump height
	if is_on_floor():
		$CoyoteTimer.start(0.15)
		leftFloor = false
	elif !leftFloor && !jumping:
		leftFloor = true
		velocity.x = velocity.rotated(rotation).x # jump off at an angle, no matter the rotation
	if jump:
		$JumpBufferTimer.start(0.15)
	if jumpnt && velocity.y < 0:
		velocity.y = velocity.y*0.55 # half-measure for global jump height
	if !jumping and $JumpBufferTimer.time_left > 0 and $CoyoteTimer.time_left > 0: # if we hit jump, aren't off the ground yet and weren't in a jumping state before
		snap = Vector2.ZERO
		jumping = true # enable jumping state
		$ControlLockTimer.start(0.15)
		var addForce = Vector2(0,jump_speed) # after we rotate, keep the pre-rotation direction
		var tempVel = velocity+addForce # add force from the jump
		velocity = tempVel.rotated(rotation)
		rotation = 0 # rotate upright
	stoppingRunning = (horiz == 0) # if we're not pressing anything, make the idle animation appear sooner
	if velocity.x!=0: # if we're moving horizontally
		if horiz==0: # but not pressing any direction
			velocity.x = velocity.x*0.975 # apply medium friction value
			if abs(velocity.x)<100 && abs(rotation)<(PI/10): # if we're supposed to be almost still
				velocity.x=velocity.x*0.8 # apply extra friction
				stoppingRunning = false # let the running animation start up quickly again
		elif horiz!=velocity.x/abs(velocity.x): # if we're pressing the opposite direction to the one we're moving at
			velocity.x = velocity.x*0.95 # apply high friction
		else:
			velocity.x = velocity.x*0.99 # apply low friction so the player doesn't rocket off
	if $ControlLockTimer.time_left <= 0:
		velocity.x+=horiz*run_speed
	velocity.x = clamp(velocity.x,-speed_cap,speed_cap)
	animate()
	
func animate():
	$AnimatedSprite.speed_scale = 1
	if(!jumping):
		if (abs(velocity.x)>20 && !stoppingRunning) || abs(velocity.x)>100 :
			$AnimatedSprite.flip_h = true if velocity.x/abs(velocity.x)==-1 else false # changes direction if we're moving at speeds that go beyond the idle animation
			if abs(velocity.x)<(gravity_speed+75):
				$AnimatedSprite.animation = "walk"
				$AnimatedSprite.speed_scale = 1.5*abs(velocity.x)/(gravity_speed+50) # walk animation goes faster the faster you go until you start running
			elif abs(velocity.x)>1000:
				$AnimatedSprite.animation = "mach"
			else:
				$AnimatedSprite.animation = "run"
		else:
			$AnimatedSprite.animation = "idle"
	else:
		$AnimatedSprite.animation = "ball" # the ground animations are kept if you run off a slope instead of jumping off it voluntarily


func _physics_process(delta):
	get_input(delta)
	secondaryGravity =  gravity 
	var flipped = false
	if gravity_off():
		if !jumping:
			secondaryGravity = 10
			velocity.y+=40
	if jumping and is_on_floor() and $JumpBufferTimer.time_left <= 0 and $ControlLockTimer.time_left <= 0:
		jumping = false
	var debugString = ""
	var floorAngle = getShortestFloorCast().get_collision_normal()
	debugString+= "NORMAL: "+ str(Vector2.UP.rotated(rotation)) + "\n"
	debugString+= "WHAT I'M AIMING FOR: "+str(getShortestFloorCast().get_collision_normal())+ "\n"
	debugString+= "DELTA ROTATION: "+str(rad2deg(getShortestFloorCast().get_collision_normal().angle_to_point(Vector2.UP.rotated(rotation))))+ "\n"
	$Line2D.points[1] = (Vector2.UP.rotated(Vector2.UP.angle_to_point(floorAngle))*20).rotated(-rotation)
	$CanvasLayer/Label.text = debugString
	if (true):
		if is_on_floor() and !jumping:
			rotation = getShortestFloorCast().get_collision_normal().angle() + PI/2 # align with floor when we're on it
		else:
			rotation = 0 # stay upright when in midair
	else:
		rotation = 0
		
	velocity.x = velocity.x if abs(rotation_degrees)>60 || abs(velocity.x)>3 else 0 # removes fractional x velocities that just cause the player to slide when idle
	snap = global_transform.y * 75 if ((!jumping && -velocity.y<secondaryGravity*delta) || (!jumping && gravity_off())) else Vector2.ZERO
	var tempNewVel = velocity.rotated(rotation)+Vector2(0,secondaryGravity *delta)
	velocity = move_and_slide_with_snap(tempNewVel,snap, -transform.y, true) # adding gravity after rotating velocity in order to make it global and factor it into the speed of uphill movement
	velocity = velocity.rotated(-rotation) # converts velocity back to local after m_a_s_w_s() rotates it
	
func is_on_floor():
	return getShortestFloorCast().is_colliding() # custom is_on_floor() detection cause the official one doesn't work very well here

func gravity_off():
	#abs(velocity.x)>gravity_speed && 
	return abs(rotation_degrees)>40

func try_vel(delta):
	var diff = move_and_slide_with_snap(velocity.rotated(rotation)+Vector2(0,gravity *delta),snap, -transform.y, true) # move
	move_and_slide_with_snap(-velocity.rotated(rotation)-Vector2(0,gravity *delta),snap, -transform.y) # undo the move in the exact same frame
	return diff # how much did we move?

func getShortestFloorCast():
	if ($FloorCast1.get_collision_point().length()>$FloorCast2.get_collision_point().length()):
		return $FloorCast2
	else:
		return $FloorCast1
