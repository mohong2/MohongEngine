package mohong;

/**
 * 单条 Trace 条目
 * A single trace entry
 */
typedef TraceEntry = {
    timestamp:Float,
    level:TraceLevel,
    message:String,
    rawMessage:String,
    fileName:String,
    lineNumber:Int,
    moduleName:String
}
