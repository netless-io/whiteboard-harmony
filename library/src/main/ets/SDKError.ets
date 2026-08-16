export interface SDKErrorPayload {
  message: string;
  jsStack?: string;
}

class JsResponse {
  __error?: SDKErrorPayload
}

export class SDKError extends Error {
  readonly jsStack: string;

  constructor(message: string, jsStack: string = "Native Error") {
    super(message);
    this.jsStack = jsStack;
    this.name = "SDKError";
  }

  static parseError(object: SDKErrorPayload): SDKError {
    try {
      const msg = object.message;
      const jsStack = object.jsStack;
      return new SDKError(msg, jsStack);
    } catch (e) {
      return new SDKError("parseError" + e.message, e.jsStack);
    }
  }

  static promiseError(str: string): SDKError | null {
    try {
      const jsonObject: JsResponse = JSON.parse(str);
      return SDKError.promiseErrorFromJson(jsonObject);
    } catch (e) {
      return null;
    }
  }

  static promiseErrorFromJson(jsonObject: JsResponse): SDKError | null {
    if (jsonObject.__error) {
      const msg = jsonObject.__error.message || "Unknown exception";
      const jsStack = jsonObject.__error.jsStack || "Unknown stack";
      return new SDKError(msg, jsStack);
    }
    return null;
  }

  toString(): string {
    return `${super.toString()} jsStack: ${this.jsStack}`;
  }
}
