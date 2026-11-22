# 鸿蒙分享（HarmonyShare）

鸿蒙原生的跨设备文件传输应用，局域网内与其他设备互传文件，无需流量、无需账号。

基于 LocalSend 协议核心（Rust 实现），通过 NAPI 桥接运行在 HarmonyOS NEXT 上。

## 功能

- **多类型传输** — 文件、相册图片、剪贴板内容、文本、文件夹发送与接收，传输任意阶段均可取消
- **跨平台互通** — 兼容 LocalSend v2 协议，与 [LocalSend](https://github.com/localsend/localsend)（Android / iOS / Windows / macOS / Linux）等客户端在同一 Wi-Fi 下自动发现、互相传输
- **互传联盟** — 与荣耀分享、小米互传、OPPO 互传、vivo 互传等联盟设备互通，蓝牙发现 + Wi-Fi Direct 直连，无需同一 Wi-Fi
- **链接分享** — 生成二维码链接，对方扫码或浏览器打开即可下载
- **安全传输** — HTTPS 加密传输，SHA-256 校验完整性，基于指纹的身份验证
- **便捷接收** — 接收历史记录、保存到系统相册、可配置自动确认、传输完成自动退出
- **收藏设备** — 收藏常用设备，一键快速发送
- **全场景适配** — 深色模式、手机 / 平板 / 2in1 响应式布局

## 安装

从 [Releases](https://github.com/zhiqiuyan/HandySend/releases) 下载 HAP 包（未签名，需自行签名后安装），或在 DevEco Studio 中打开本工程构建运行。

## 协议

基于 [Apache License 2.0](LICENSE) 开源，Fork 自 [springtwr/HandySend](https://github.com/springtwr/HandySend)。
