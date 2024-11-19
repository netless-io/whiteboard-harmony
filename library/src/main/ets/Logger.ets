type LogLevel = "debug" | "info" | "error" ;

type LogCallback = (level: LogLevel, message: string, error?: object) => void;

export class Logger {
  private static logCallback?: LogCallback;

  /**
   * 打印调试日志。
   * @param message 日志信息。
   */
  static debug(message: string): void {
    Logger.log("debug", message);
  }

  /**
   * 设置日志回调函数。
   * @param callback 回调函数，接收日志级别、消息和可选的错误对象。
   */
  static setLogCallback(callback: LogCallback): void {
    Logger.logCallback = callback;
  }

  /**
   * 打印信息日志。
   * @param message 日志信息。
   */
  static info(message: string): void {
    Logger.log("info", message);
  }

  /**
   * 打印错误日志。
   * @param message 日志信息。
   * @param error 可选的错误对象。
   */
  static error(message: string, error?: object): void {
    Logger.log("error", message, error);
  }

  /**
   * 内部日志处理方法。
   * @param level 日志级别。
   * @param message 日志信息。
   * @param error 可选的错误对象。
   */
  private static log(level: LogLevel, message: string, error?: object): void {
    // 如果设置了回调，调用回调
    if (Logger.logCallback) {
      Logger.logCallback(level, message, error);
    }

    // 默认日志行为
    switch (level) {
      case "info":
        console.log("[Whiteboard][INFO]", message);
        break;
      case "error":
        console.error("[Whiteboard][ERROR]", message, error);
        break;
      case "debug":
        console.debug("[Whiteboard][DEBUG]", message);
        break;
    }
  }
}
