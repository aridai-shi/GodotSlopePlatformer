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
var leftFloor = false
var secondaryGravity = 0
var angle = 0.0
var oldangle = 0.0
var dangle = 0
var maxdangle = -1;
var leftLen = -1
var rightLen = -1
func get_input(delta):
	if Input.is_action_pressed("ui_down"):
		breakpoint
	leftLen = global_position-$FloorCast1.get_collision_point()
	rightLen =  global_position-$FloorCast2.get_collision_point()
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

func calculate_angle():
	var oldrotation = Vector2(0,1/60)
	angle =  (oldrotation.x - rotation) * 60 #this gives angle in degrees
	oldrotation.x = rotation 
	dangle = abs(oldangle) - abs(angle)
	if (dangle >= 360 || !is_on_floor()):
		dangle = 0
	oldangle = angle
	if (maxdangle < abs(dangle)):
		maxdangle = abs(dangle)

func _physics_process(delta):
	var oldfloorNormal = Vector2(0,0)
	var oldrotation = 0
	calculate_angle()
	get_input(delta)
	secondaryGravity =  gravity 
	var flipped = false
	if gravity_off():
		if !jumping && is_on_floor():
			secondaryGravity = 10
			velocity.y+=40
	if jumping and is_on_floor() and $JumpBufferTimer.time_left <= 0 and $ControlLockTimer.time_left <= 0:
		jumping = false
	var debugString = ""
	debugString+= " delta angle: "+str(dangle) +"\n"
	debugString+= "max delta angle : "+str(maxdangle)
	$CanvasLayer/Label.text = debugString
	if Input.is_action_pressed("ui_down"):
		breakpoint
	if is_on_floor() and !jumping:
		rotation = getShortestFloorCast().get_collision_normal().angle() + PI/2 # align with floor when we're on it
	else:
		delay_rot()
	if Input.is_action_pressed("ui_down"):
		breakpoint
	velocity.x = velocity.x if abs(rotation_degrees)>60 || abs(velocity.x)>3 else 0 # removes fractional x velocities that just cause the player to slide when idle
	snap = global_transform.y * 75 if ((!jumping && -velocity.y<secondaryGravity*delta) || (!jumping && gravity_off()) || ($SnapTimer.time_left<=0)) else Vector2.ZERO
	var tempNewVel = velocity.rotated(rotation)+Vector2(0,secondaryGravity *delta)
	velocity = move_and_slide_with_snap(tempNewVel,snap, -transform.y, true) # adding gravity after rotating velocity in order to make it global and factor it into the speed of uphill movement
	velocity = velocity.rotated(-rotation) # converts velocity back to local after m_a_s_w_s() rotates it
	
func is_on_floor():
	return getShortestFloorCast().is_colliding() # custom is_on_floor() detection cause the official one doesn't work very well here

func gravity_off():
	#
	return abs(velocity.x)>gravity_speed &&  abs(rotation_degrees)>40

func try_vel(delta):
	var diff = move_and_slide_with_snap(velocity.rotated(rotation)+Vector2(0,gravity *delta),snap, -transform.y, true) # move
	move_and_slide_with_snap(-velocity.rotated(rotation)-Vector2(0,gravity *delta),snap, -transform.y) # undo the move in the exact same frame
	return diff # how much did we move?

func getShortestFloorCast():
	if ((global_position-$FloorCast1.get_collision_point()).length()>(global_position-$FloorCast2.get_collision_point()).length()):
		return $FloorCast2
	else:
		return $FloorCast1
func delay_rot():
	if $SnapTimer.time_left>=0:
		$SnapTimer.start(0.15)
	rotation += round(lerp_angle(rotation,0,1/60000)*10)/10
