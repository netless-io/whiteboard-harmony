# 发布 @shengwang/whiteboard

项目发布入口是 `scripts/publish-package.sh`。HAR 是对外 SDK 包；Demo HAP、tag 或上传命令
成功都不能单独证明版本已经可安装。发布前按工作区 Harmony 门禁审核真实 JSON、产物和设备证据。

## 源码与两份提交

先对比上一个实际发布 tag，明确允许的 SDK/API、Bridge marker/13项资源、依赖、测试及共享 Demo
差异。共享 Demo 不保留测试凭据或本机签名；私有配置留在 ignored local 文件或应用 sandbox。

1. 功能提交 `feat(harmony): ...` 或 `fix(harmony): ...`：本次 SDK、Bridge 资源、相关测试/文档和
   所有可共享 Demo 改动。包版本保持上一发布版本。
2. 版本提交 `chore: release <version>`：仅 `library/oh-package.json5`、`library/Index.ets` 的
   VERSION 行、新版 `library/CHANGELOG.md` 条目，以及版本变化实际影响的 lock 引用。

显式按路径/patch stage 并检查 staged diff，特别是 `Index.ets` 同时有新导出与 VERSION 时要分开。
新 changelog 条目必须在旧版本前**新增**，保留旧版本标题。当前 `prepare-version` 会改第一条
`## [version]` 标题；必须先加入正确的新标题，不能让它覆盖旧版记录。不要 squash 功能/版本提交。

## 干净 release HAR

使用只含已审核变更的干净发布目录；不得包含本地签名、Demo token、探针脚本或临时 rawfile。
`scripts/hvigor-release.sh` 给 Hvigor 强制增加 `buildMode=release`，作为项目发布脚本的 wrapper：

```bash
export WHITEBOARD_HVIGORW_BIN=<installed-hvigorw-executable>
export HVIGORW="$PWD/scripts/hvigor-release.sh"
export OHPM=<installed-ohpm-executable>
export DEVECO_SDK_HOME=<installed-Harmony-SDK>
scripts/publish-package.sh build
```

先解包 `library/build/default/outputs/default/library.har`，核对包名、版本、`metadata.debug=false`、
Bridge marker、全部资源 hash、声明和实际 payload；扫描排除的诊断字符串/本机材料。
保留 SHA-256、大小、源提交与构建日志。unsigned Debug 测试 HAP 和 debug=true 静态 HAR 不能用作正式包。

基础准备推荐 `prepareCompletion(timeoutMs = 15000): Promise<void>`，诊断单独使用
`getPreparationInfo()`；旧 `prepare(): Promise<PreparationInfo>` 仅保留兼容。两者共用同一批准备，
不等待可选预热，不新建 Bridge 方法，timeoutMs 不进入 SDK 构造 JSON。发布时必须核对生成声明与实际调用。

至少完成一次当前产物设备/模拟器探针，按共用验收标准检查初始化、同 View prepareCompletion→join、
完成回调、绘画双端同步、退出重入与课件导航。快速输入允许过滤，但双端最终 page/render/index/position
必须稳定一致，稳定后独立前/后翻均可继续。静态编译不能代替设备证据。

## 发布与回读

完成上述门禁后，在同一个干净发布目录使用同一 wrapper：

```bash
scripts/publish-package.sh publish <version>
```

发布前后确认源码没有变化；tag 指向对应 release commit，或 SDK/source/resource tree 相同的合并提交。
OHPM 如返回待审核，状态是 `uploaded-pending-review`；registry 暴露目标版本后，下载对应 HAR，
核对 `dist.integrity` 和本地 SHA-256，才可宣告可安装。不要为修复 Git 记录而重复上传同版。

在工作区 `docs/releases/` 与 `ai/records/` 记录基线、allowlist、两份提交、tag/merge、HAR hash、
真实 JSON/设备探针及 registry 结果。任何运行探针失败或未执行，都不能记录为“已验证”。
