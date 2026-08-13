package mohong;

/** One log entry, stored in the ring buffer. */
typedef TraceEntry = {
	timestamp:Float,
	level:TraceLevel,
	message:String,
	rawMessage:String,
	fileName:String,
	lineNumber:Int,
	moduleName:String
}
