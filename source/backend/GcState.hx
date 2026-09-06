package backend;


class GcState
{
	public static var disabled(default, null):Bool = false;

	public static function setDisabled(v:Bool):Void
	{
		#if cpp
		cpp.vm.Gc.enable(!v);
		#end
		disabled = v;
	}
}
