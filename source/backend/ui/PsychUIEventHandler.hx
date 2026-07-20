package backend.ui;

import flixel.FlxObject;

class PsychUIEventHandler
{
	public static function event(id:String, sender:Dynamic)
	{
		var state:Dynamic = cast FlxG.state;
		if(state == null) return;

		while(state.subState != null)
			state = cast state.subState;

		if(state != null && state.UIEvent != null)
			state.UIEvent(id, sender);
	}
	public static function overlaps(obj:FlxObject, camera:FlxCamera):Bool
	{
		if (obj == null) return false;
		final cam = (camera != null) ? camera : FlxG.camera;
		final screenPos = obj.getScreenPosition(null, cam);
		final mousePos = FlxG.mouse.getPositionInCameraView(cam);
		return mousePos.x >= screenPos.x
			&& mousePos.x <= screenPos.x + obj.width
			&& mousePos.y >= screenPos.y
			&& mousePos.y <= screenPos.y + obj.height;
	}

}

interface PsychUIEvent {
	public function UIEvent(id:String, sender:Dynamic):Void;
}