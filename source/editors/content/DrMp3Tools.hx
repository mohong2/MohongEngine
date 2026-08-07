package editors.content;

#if cpp
import sys.io.File;
import sys.FileSystem;

/**
 * MP3 -> 16-bit PCM WAV conversion using the native dr_mp3 decoder
 * (see DrMp3.hx). Used wherever lime's own audio pipeline cannot decode MP3
 * (Windows & Android builds).
 */
class DrMp3Tools
{
	static var _tmpCounter:Int = 0;

	/** Decodes an MP3 file to 16-bit PCM WAV bytes. Null on failure. */
	public static function decodeFileToWav(mp3Path:String):haxe.io.Bytes
	{
		try
		{
			if (mp3Path == null || !FileSystem.exists(mp3Path)) return null;
			var format = parseMp3Format(File.getBytes(mp3Path));
			var channels:Int = format.channels;
			var sampleRate:Int = format.sampleRate;

			var totalFrames:DrMp3.DrMP3UInt64 = 0;
			var pcmPtr:cpp.RawPointer<cpp.Int16> = DrMp3.openAndReadAll(cpp.ConstCharStar.fromString(mp3Path), null, cpp.RawPointer.addressOf(totalFrames), null);
			if (pcmPtr == null) return null;

			var frames:Int = Std.int(totalFrames);
			if (frames <= 0)
			{
				DrMp3.free(pcmPtr, null);
				return null;
			}

			var samples:Int = frames * channels;
			var dataSize:Int = samples * 2;
			var pcm:haxe.io.Bytes = haxe.io.Bytes.alloc(dataSize);
			for (i in 0...samples)
				pcm.setUInt16(i * 2, pcmPtr[i] & 0xFFFF);
			DrMp3.free(pcmPtr, null);

			var out:haxe.io.BytesBuffer = new haxe.io.BytesBuffer();
			out.addString('RIFF');
			writeLE32(out, 36 + dataSize);
			out.addString('WAVE');
			out.addString('fmt ');
			writeLE32(out, 16);
			writeLE16(out, 1); // PCM
			writeLE16(out, channels);
			writeLE32(out, sampleRate);
			writeLE32(out, sampleRate * channels * 2);
			writeLE16(out, channels * 2);
			writeLE16(out, 16);
			out.addString('data');
			writeLE32(out, dataSize);
			out.addBytes(pcm, 0, dataSize);
			return out.getBytes();
		}
		catch (e:Dynamic) return null;
	}

	/**
	 * Reads the sample rate and channel count straight from the first MP3
	 * frame header (dr_mp3 0.6.38 outputs PCM at the source format).
	 */
	static function parseMp3Format(bytes:haxe.io.Bytes):{sampleRate:Int, channels:Int}
	{
		var i:Int = 0;
		if (bytes.length >= 10 && bytes.get(0) == 0x49 && bytes.get(1) == 0x44 && bytes.get(2) == 0x33) // "ID3"
		{
			var tagSize:Int = ((bytes.get(6) & 0x7F) << 21) | ((bytes.get(7) & 0x7F) << 14) | ((bytes.get(8) & 0x7F) << 7) | (bytes.get(9) & 0x7F);
			i = 10 + tagSize;
		}

		while (i + 4 < bytes.length)
		{
			if (bytes.get(i) == 0xFF && (bytes.get(i + 1) & 0xE0) == 0xE0)
			{
				var versionBits:Int = (bytes.get(i + 1) >> 3) & 0x03;
				var layerBits:Int = (bytes.get(i + 1) >> 1) & 0x03;
				if (versionBits != 1 && layerBits == 1) // valid MPEG + Layer III
				{
					var sampleRateIndex:Int = (bytes.get(i + 2) >> 2) & 0x03;
					var channelMode:Int = (bytes.get(i + 3) >> 6) & 0x03;
					var rate:Int = 0;
					switch (versionBits)
					{
						case 3: rate = [44100, 48000, 32000][sampleRateIndex];
						case 2: rate = [22050, 24000, 16000][sampleRateIndex];
						case 0: rate = [11025, 12000, 8000][sampleRateIndex];
						default:
					}
					if (rate > 0)
						return {sampleRate: rate, channels: (channelMode == 3) ? 1 : 2};
				}
			}
			i++;
		}
		return {sampleRate: 44100, channels: 2};
	}

	/** Decodes MP3 bytes to 16-bit PCM WAV bytes (via a temp file). */
	public static function decodeBytesToWav(mp3Bytes:haxe.io.Bytes):haxe.io.Bytes
	{
		try
		{
			if (mp3Bytes == null || mp3Bytes.length == 0) return null;
			_tmpCounter++;
			var tmpPath:String = tempFilePath('seiun_mp3_' + Std.int(Date.now().getTime()) + '_' + _tmpCounter + '.mp3');
			File.saveBytes(tmpPath, mp3Bytes);
			var wav:haxe.io.Bytes = decodeFileToWav(tmpPath);
			if (FileSystem.exists(tmpPath)) FileSystem.deleteFile(tmpPath);
			return wav;
		}
		catch (e:Dynamic) return null;
	}

	/** Writable scratch location that exists on both Windows and Android. */
	public static function tempFilePath(name:String):String
	{
		var dir:String = Sys.getEnv('TEMP');
		if (dir == null || dir.length == 0) dir = Sys.getCwd();
		return dir + '/' + name;
	}

	static function writeLE16(buf:haxe.io.BytesBuffer, v:Int):Void
	{
		buf.addByte(v & 0xFF);
		buf.addByte((v >> 8) & 0xFF);
	}

	static function writeLE32(buf:haxe.io.BytesBuffer, v:Int):Void
	{
		buf.addByte(v & 0xFF);
		buf.addByte((v >> 8) & 0xFF);
		buf.addByte((v >> 16) & 0xFF);
		buf.addByte((v >>> 24) & 0xFF);
	}
}
#end
