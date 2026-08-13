package mohong;

/**
 * 单条 Trace 条目（结构体，直接作为环形缓冲的元素类型）。
 */
typedef TraceEntry = {
	/** Unix 秒时间戳。 */
	timestamp:Float,
	/** 级别。 */
	level:TraceLevel,
	/** 展示文本（已翻译、已插值）。 */
	message:String,
	/** 原始文本（未翻译）。 */
	rawMessage:String,
	/** 产生该条目的源文件。 */
	fileName:String,
	/** 源文件行号。 */
	lineNumber:Int,
	/** 模块名（从 fileName 提取）。 */
	moduleName:String
}
