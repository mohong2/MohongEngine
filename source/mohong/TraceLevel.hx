package mohong;

/**
 * Trace 级别枚举。
 * 顺序意义（低→高）：DEBUG < INFO < WARN < ERROR；
 * 控制台过滤规则：级别 >= consoleLevel 才输出。
 */
enum TraceLevel
{
	DEBUG;
	INFO;
	WARN;
	ERROR;
}
