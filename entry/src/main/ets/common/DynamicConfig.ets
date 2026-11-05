import { DynamicConfigOptions } from '@shengwang/whiteboard';

/** Each platform uses its own OSS directory. Unmapped regions retain local SDK configuration. */
export const dynamicConfig: DynamicConfigOptions = {
  "cn-hz": "https://fastboard-demo-config.oss-cn-hangzhou.aliyuncs.com/whiteboard-config-service/fastboard-demo/harmony/latest.json",
  "sg": "https://fastboard-demo-config-sg.oss-ap-southeast-1.aliyuncs.com/whiteboard-config-service/fastboard-demo/harmony/latest.json",
  "us-sv": "https://fastboard-demo-config-sg.oss-ap-southeast-1.aliyuncs.com/whiteboard-config-service/fastboard-demo/harmony/latest.json",
  "eu": "https://fastboard-demo-config-sg.oss-ap-southeast-1.aliyuncs.com/whiteboard-config-service/fastboard-demo/harmony/latest.json",
  "in-mum": "https://fastboard-demo-config-sg.oss-ap-southeast-1.aliyuncs.com/whiteboard-config-service/fastboard-demo/harmony/latest.json",
};
