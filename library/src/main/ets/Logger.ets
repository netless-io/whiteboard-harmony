export class Logger {
  static info(message: string): void {
    console.log("[Whiteboard]", message);
  }

  static error(message: string, error?: object): void {
    console.error("[Whiteboard]", message, error);
  }
}