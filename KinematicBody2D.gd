extends KinematicBody2D

var run_speed = 8 # acceleration
var jump_speed = -480
var gravity = 1000
var velocity = Vector2()
var jumping = false # in charge of the jumping ""state"" and animations
var dir = true # in charge of animation direection
var speed_cap = 1200
var gravity_speed = 800
var snap # snap vector
var stoppingRunning = false; # purely in charge of switching to the idle animation sooner - to be ignored
var lastNormal = Vector2.ZERO
var leftFloor = false
var buildUp=0

func get_input(delta):
	var horiz =  Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left") # simplified left-right check
	var jump = Input.is_action_just_pressed('ui_up')
	var jumpnt = Input.is_action_just_released('ui_up') #for variable jump height
	if is_on_floor():
		$CoyoteTimer.start(0.15)
		leftFloor = false
	elif !leftFloor:
		leftFloor = true
		velocity.x = velocity.rotated(rotation).x # jump off at an angle, no matter the rotation
	if jump:
		$JumpBufferTimer.start(0.15)
	if jumpnt && velocity.y < 0:
		velocity.y = velocity.y*0.55 # half-measure for global jump height
	if !jumping and $JumpBufferTimer.time_left > 0 and $CoyoteTimer.time_left > 0: # if we hit jump, aren't off the ground yet and weren't in a jumping state before
		jumping = true
		velocity.y = jump_speed - abs(velocity.rotated(rotation).x/10)

		velocity.y = velocity.rotated(rotation).y
		rotation = 0
	stoppingRunning = (horiz == 0) # if we're not pressing anything, make the idle animation appear sooner
	if Input.is_action_pressed("ui_down"):
		buildUp += delta/2
		buildUp = clamp(buildUp,-1,1)
		horiz = 0
	if Input.is_action_just_released("ui_down"):
		velocity.x=(-1 if $AnimatedSprite.flip_h else 1)*speed_cap*buildUp
		buildUp=0
	if velocity.x!=0: # if we're moving horizontally
		if horiz==0: # but not pressing any direction
			velocity.x = velocity.x*0.975 # apply medium friction value
			if abs(velocity.x)<100 && abs(rotation)<(PI/10): # if we're supposed to be almost still
				velocity.x=velocity.x*0.9 # apply extra friction
				stoppingRunning = false # let the running animation start up quickly again
		elif horiz!=velocity.x/abs(velocity.x): # if we're pressing the opposite direction to the one we're moving at
			velocity.x = velocity.x*0.95 # apply high friction
		else:
			velocity.x = velocity.x*0.99 # apply low friction so the player doesn't rocket off
	velocity.x+=horiz*run_speed
	velocity.x = clamp(velocity.x,-speed_cap,speed_cap)
	print(gravity_off())
	animate()
	
func animate():
	$AnimatedSprite.speed_scale = 1
	if(!jumping):
		if (abs(velocity.x)>20 && !stoppingRunning) || abs(velocity.x)>100 :
			$AnimatedSprite.flip_h = true if velocity.x/abs(velocity.x)==-1 else false # changes direction if we're moving at speeds that go beyond the idle animation
			if abs(velocity.x)<700:
				$AnimatedSprite.animation = "walk"
				$AnimatedSprite.speed_scale = 2*abs(velocity.x)/900 # walk animation goes faster the faster you go until you start running
			elif abs(velocity.x)>1000:
				$AnimatedSprite.animation = "mach"
			else:
				$AnimatedSprite.animation = "run"
		else:
			if (buildUp==0):
				$AnimatedSprite.animation = "idle"
			elif (buildUp<0.5):
				$AnimatedSprite.animation = "walk"
			elif (buildUp<0.8):
				$AnimatedSprite.animation = "run"
			else:
				$AnimatedSprite.animation = "mach"
			
			if (buildUp > 0 && buildUp < 0.5):
				$AnimatedSprite.speed_scale = buildUp*2
			else:
				$AnimatedSprite.speed_scale = 1
	else:
		$AnimatedSprite.animation = "ball" # the ground animations are kept if you run off a slope instead of jumping off it voluntarily

func _physics_process(delta):
	get_input(delta)
	if jumping and is_on_floor() and $JumpBufferTimer.time_left <= 0:
		jumping = false
	if is_on_floor():
		rotation = $FloorCast.get_collision_normal().angle() + PI/2 # align with floor when we're on it
	else:
		rotation = 0 # stay upright when in midair
	snap = global_transform.y * 50 if !jumping else Vector2.ZERO
	velocity.x = velocity.x if abs(velocity.x)>1 else 0 # removes fractional x velocities that just cause the player to slide when idle
	var secondaryGravity = 0 if ((is_on_floor() && try_vel(delta).length()<1)||gravity_off()) else gravity # removes fractional y velocities that just cause the player to slide when idle
	velocity = move_and_slide_with_snap(velocity.rotated(rotation)+Vector2(0,secondaryGravity *delta),snap, -transform.y, true) # adding gravity after rotating velocity in order to make it global and factor it into the speed of uphill movement
	velocity = velocity.rotated(-rotation) # converts velocity back to local after m_a_s_w_s() rotates it
	
func is_on_floor():
	return $FloorCast.is_colliding() # custom is_on_floor() detection cause the official one doesn't work very well here
func gravity_off():
	return abs(velocity.x)>gravity_speed && abs(rotation_degrees)>60 && !jumping
func try_vel(delta):
	var diff = move_and_slide_with_snap(velocity.rotated(rotation)+Vector2(0,gravity *delta),snap, -transform.y, true) # move
	move_and_slide_with_snap(-velocity.rotated(rotation)-Vector2(0,gravity *delta),snap, -transform.y, true) # undo the move in the exact same frame
	return diff # how much did we move?
