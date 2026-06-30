extends Node


func is_left_click(event:InputEvent):
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	
func is_left_click_press(event: InputEvent):
	return is_left_click(event) and event.pressed
	
func is_left_click_blur(event: InputEvent):
	return is_left_click(event) and not event.pressed

func is_motion(event: InputEvent):
	return  event is InputEventMouseMotion
