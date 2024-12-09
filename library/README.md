## 介绍

`whiteboard-harmony` 是一个适用于 HarmonyOS 的 Whiteboard SDK 包，提供了与 Whiteboard 服务交互的接口。

## 下载安装

```shell
ohpm install @shengwang/whiteboard
```

## 权限设置

```shell
ohos.permission.INTERNET
```

## API

### 加入房间

```shell
@Entry
@Component
struct Demo {
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "APP_IDENTIFIER",
    roomUuid: "ROOM_UUID",
    roomToken: "ROOM_TOKEN",
    region: Region.CN_HZ,
    uid: "CLIENT_UID"
  }
  whiteboardController: WhiteboardController = new WhiteboardController();
  callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()

  build() {
    Stack() {
      Whiteboard({ options: this.whiteboardOptions, controller: this.whiteboardController, callbacks: this.callbacks })
        .width('100%')
        .height('100%')
    }
  }
}
```

## 白板操作

### **更改读写模式**

```
setWritable(writable: boolean): Promise<boolean>
```

### **设置教具**

`setAppliance(appliance: Appliance, shapeType?: ShapeType)`

参数说明

| 参数名         | 类型          | 是否必填 | 描述            |
|-------------|-------------|------|---------------|
| `appliance` | `Appliance` | 是    | 教具名称，用于设置工具类型 |
| `shapeType` | `ShapeType` | 否    | 形状类型，仅对某些教具有效 |

#### 返回值

`void`：无返回值。

#### 示例

```typescript
// 设置为画笔工具
setAppliance(Appliance.PENCIL);

// 设置为特定形状工具
setAppliance(Appliance.SHAPE, ShapeType.RHOMBUS);
```

---

这种方式包括方法签名、参数表格、返回值说明以及代码示例，适合技术文档的风格，清晰易读。

### 视角

#### 切换视角模式

```
setViewMode(viewMode: ViewMode): void
```

> 通常情况下，教师端设置 ViewMode.Broadcaster ，学生端无需无需设置。同时在学生端设置
> WhiteboardController.disableCameraTransform(true) 限制视角操作，能达到学生随时跟随老师的视角

## 多窗口 API

### App

1. `addApp`
2. `closeApp`
3. `focusApp`
4. `queryApp`
5. `queryAllApps`

### Page

1. `addPage`
2. `removePage`
3. `prevPage`
4. `nextPage`

### 其他

更多参考官方文档

## 如何贡献

如果您在使用过程中发现任何问题，可以向我们提交 issue 或 PR。

## 许可

该仓库使用 [MIT](./LICENSE) 许可协议。