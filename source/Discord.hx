package;

#if flash
import Sys.sleep;
import discord_rpc.DiscordRpc;
#end

#if LUA_ALLOWED
import llua.Lua;
import llua.State;
#end

using StringTools;

class DiscordClient
{
	public static var isInitialized:Bool = false;
	public static var clientID:String = "863222024192262205";
	public static var _defaultID:String = clientID;
	public function new()
	{
	  #if flash
		CoolUtil.traceMsg('trace.discordStart', 'Discord Client starting...');
		DiscordRpc.start({
			clientID: clientID,
			onReady: onReady,
			onError: onError,
			onDisconnected: onDisconnected
		});
		CoolUtil.traceMsg('trace.discordStarted', 'Discord Client started.');

		while (true)
		{
			DiscordRpc.process();
			sleep(2);
			//trace("Discord Client Update");
		}

		DiscordRpc.shutdown();
		#end
	}
	
	public static function shutdown()
	{
	  #if flash
		DiscordRpc.shutdown();
		#end
	}
	
	static function onReady()
	{
	  #if flash
		// Read mod config for Discord overrides on initial presence
		#if MODS_ALLOWED
		var logoKey:String = 'icon';
		var logoText:String = "Psych Engine";
		if (states.MainMenuState.selectedModFolder != null && states.MainMenuState.selectedModFolder.length > 0) {
			var cfg = backend.ModConfig.load(states.MainMenuState.selectedModFolder);
			if (cfg.discordLogoKey.length > 0) logoKey = cfg.discordLogoKey;
			if (cfg.discordLogoText.length > 0) logoText = cfg.discordLogoText;
		}
		#else
		var logoKey:String = 'icon';
		var logoText:String = "Psych Engine";
		#end

		DiscordRpc.presence({
			details: "In the Menus",
			state: null,
			largeImageKey: logoKey,
			largeImageText: logoText
		});
		#end
	}

	static function onError(_code:Int, _message:String)
	{
		CoolUtil.traceMsg('trace.discordError', 'Error! {} : {}', [_code, _message]);
	}

	static function onDisconnected(_code:Int, _message:String)
	{
		CoolUtil.traceMsg('trace.discordDisconnected', 'Disconnected! {} : {}', [_code, _message]);
	}

	public static function initialize()
	{
	  #if flash
		var DiscordDaemon = sys.thread.Thread.create(() ->
		{
			new DiscordClient();
		});
		CoolUtil.traceMsg('trace.discordInit', 'Discord Client initialized');
		isInitialized = true;
		#end
	}

	public static function changePresence(details:String, state:Null<String>, ?smallImageKey : String, ?hasStartTimestamp : Bool, ?endTimestamp: Float)
	{
	  #if flash
		var startTimestamp:Float = if(hasStartTimestamp) Date.now().getTime() else 0;

		if (endTimestamp > 0)
		{
			endTimestamp = startTimestamp + endTimestamp;
		}

		// Read mod config for Discord overrides (logoKey / logoText)
		#if MODS_ALLOWED
		var logoKey:String = 'icon';
		var logoText:String = "Engine Version: " + MainMenuState.psychEngineVersion;
		if (states.MainMenuState.selectedModFolder != null && states.MainMenuState.selectedModFolder.length > 0) {
			var cfg = backend.ModConfig.load(states.MainMenuState.selectedModFolder);
			if (cfg.discordLogoKey.length > 0) logoKey = cfg.discordLogoKey;
			if (cfg.discordLogoText.length > 0) logoText = cfg.discordLogoText;
		}
		#else
		var logoKey:String = 'icon';
		var logoText:String = "Engine Version: " + MainMenuState.psychEngineVersion;
		#end

		DiscordRpc.presence({
			details: details,
			state: state,
			largeImageKey: logoKey,
			largeImageText: logoText,
			smallImageKey : smallImageKey,
			// Obtained times are in milliseconds so they are divided so Discord can use it
			startTimestamp : Std.int(startTimestamp / 1000),
            endTimestamp : Std.int(endTimestamp / 1000)
		});
		#end

		//trace('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp');
	}

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State) {
	  #if flash
		Lua_helper.add_callback(lua, "changePresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
			changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
		});
		#end
	}
	#end
}