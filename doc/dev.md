# Whiteboard 鸿蒙开发

## 本地 Demo 与动态配置

首次构建 Demo 前，将 `entry/src/main/ets/common/demo.local.example.ets` 复制为
`demo.local.ets`，填写测试 AppIdentifier 与 RoomToken；该文件已被 Git 忽略。
房间 UUID 在 `common/constant.ets` 中，必须与 Token 对应。

`common/DynamicConfig.ets` 导出 `dynamicConfig`，单窗口与教具插件 Demo 都将其传给
`WhiteboardOptions.dynamicConfig`。值为 region → Harmony 平台 `latest.json` 的公开 URL，
由入房的 `region` 选择；可仅填写使用的区域。未配置、区域未匹配、平台不匹配或下载失败时，
动态配置不生效，继续使用宿主参数和 SDK 默认值；下载默认超时为 5 秒。
宿主显式参数优先于动态配置，未传的可选参数保持未传，不会转换成 `false`。

教具插件 Demo 与 Android/iOS 测试配置对齐，默认只读，`useWorker` 未显式指定，
由动态配置及运行时能力决定。真机验证需有效调试签名和 HDC 授权。

## 静态共享包 vs 动态共享包

[HAR（Harmony Archive）是静态共享包](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/har-package-V5)
[HSP（Harmony Shared Package）是动态共享包](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/in-app-hsp-V5)

## 依赖Library

1. build ->
2. ohpm install
   a. ohpm install @shengwang/whiteboard@0.2.1
   b. ohpm install ../library


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
- [x] 添加 WebView 合理配置
- [ ] 文档补全
    - [X] README
    - [ ] QuickStart
    - [ ] API
    - [ ] Recipes
    - [ ] Common Whiteboard Reference
- [ ] 接口同步
    - [ ] MagixEvent
    - [X] Page
    - [x] WindowApp
    - [ ] ~~WindowApp 注册~~
    - [X] Slide Listeners（WhiteboardCallbacks / setSlideListener，含错误、资源重试耗尽、链接与异步 URL 拦截）
    - [ ] WindowDocsEvent
    - [ ] SDKError
    - [ ] CameraBounds

## 发布

前置条件生成

* keygen (需要配置 passphrase)
* 发布码

[发布共享包](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/ide-har-publish-V13)

命令行工具

* [hvigorw](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/ide-hvigor-commandline-V13)
* [ohpmrc](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/ide-ohpmrc-V13)
