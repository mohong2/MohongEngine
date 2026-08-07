package editors.content;

#if cpp
import sys.io.File;
import sys.FileSystem;

/**
 * Cross-platform MP3 decoding via dr_mp3 (hxcpp native bindings).
 *
 * lime 8.0.1's Windows/Android audio pipeline cannot decode MP3 (only ogg/wav),
 * so any MP3 audio gets decoded to 16-bit PCM WAV here before being handed to
 * lime / written next to exported charts. Works on Windows AND Android (both
 * hxcpp cpp targets; dr_mp3 is a portable pure-C decoder).
 */
@:include("dr_mp3.h")
// Make the C++ compiler find the vendored header. The path is relative to the
// hxcpp obj dir, whose depth differs per platform:
//   Android/mac  : export/<config>/<platform>/obj          -> 4 levels up
//   iOS(sim/dev) : export/<config>/ios/obj/<config-name>/  -> 5+ levels up
// Nonexistent -I dirs are ignored by the compiler, so listing several depths
// is harmless and keeps every target working.
@:buildXml('
<files id="haxe">
	<compilerflag value="-I../../../../source/editors/content" unless="web" />
	<compilerflag value="-I../../../../../source/editors/content" unless="web" />
	<compilerflag value="-I../../../../../../source/editors/content" unless="web" />
	<compilerflag value="-I../../../../../../../source/editors/content" unless="web" />
</files>
')
extern class DrMp3
{
	/** Opens an MP3 file and decodes ALL frames to a native Int16 buffer. */
	@:native('drmp3_open_file_and_read_pcm_frames_s16')
	public static function openAndReadAll(fileName:cpp.ConstCharStar, config:cpp.RawPointer<DrMP3Config>, totalFrameCount:cpp.RawPointer<DrMP3UInt64>, allocationCallbacks:cpp.RawPointer<DrMP3AllocationCallbacks>):cpp.RawPointer<cpp.Int16>;

	/** Frees a buffer returned by openAndReadAll. */
	@:native('drmp3_free')
	public static function free(data:cpp.RawPointer<cpp.Int16>, allocationCallbacks:cpp.RawPointer<DrMP3AllocationCallbacks>):Void;
}

@:native('drmp3_config')
extern class DrMP3Config {}

@:native('drmp3_allocation_callbacks')
extern class DrMP3AllocationCallbacks {}

// drmp3_uint64 is `unsigned long long`; hxcpp's cpp.UInt64 is `unsigned long`
// on Android, so use the exact native typedef to keep the pointer types matching.
@:native("drmp3_uint64")
@:scalar @:coreType @:notNull
extern abstract DrMP3UInt64 from Int to Int {}
#end
