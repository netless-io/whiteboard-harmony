# Whiteboard 鸿蒙开发

## 静态共享包 vs 动态共享包

[HAR（Harmony Archive）是静态共享包](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/har-package-V5)
[HSP（Harmony Shared Package）是动态共享包](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/in-app-hsp-V5)

## 依赖Library

1. build ->
2. ohpm install

## ArtTS

先转换成TS, 在更具区别更改成ArtTS
https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/learning-arkts-V5

## [创建自定义组件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-create-custom-components-V5#%E6%88%90%E5%91%98%E5%87%BD%E6%95%B0%E5%8F%98%E9%87%8F)

## WebView 调试

```shell
# 配置 export PATH=$PATH:/Users/flb/Library/OpenHarmony/Sdk/10/toolchains

hdc shell
cat /proc/net/unix | grep devtools
//显示 webview_devtools_remote_3458
exit
hdc fport tcp:9222 localabstract:webview_devtools_remote_3458
hdc fport ls

```

## 任务项目

- [ ] 测试 WindowApp 注册，添加 App
- [x] 添加 WebView 合理配置
- [ ] 文档补全
    - [ ] README
    - [ ] QuickStart
    - [ ] API
    - [ ] Recipes
    - [ ] Common Whiteboard Reference
- [ ] 接口同步
    - [ ] MagixEvent
    - [ ] Page
    - [ ] window apps
    - [ ] Slide
    - [ ] WindowDocsEvent
    - [ ] SDKError

## 发布

前置条件生成

* keygen
* 发布码

[发布共享包](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/ide-har-publish-V13)

命令行工具

* [hvigorw](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/ide-hvigor-commandline-V13)
* [ohpmrc](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/ide-ohpmrc-V13)