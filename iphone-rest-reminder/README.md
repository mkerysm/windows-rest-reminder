# iPhone Rest Reminder

一个使用 SwiftUI 编写的 iPhone 护眼和身体休息提醒 App。

## 功能

- 每 20 分钟发送一次远眺 20 秒提醒
- 每 45 分钟发送一次休息 5 分钟提醒
- App 内实时显示距离下次提醒的时间
- 提供 20 秒和 5 分钟休息倒计时
- 支持手动重置整个提醒周期
- 后台或锁屏时使用 iOS 本地通知

## 不使用 Mac 安装

本仓库会通过 GitHub Actions 的 macOS 云端环境自动生成未签名 IPA：

1. 打开 GitHub 仓库的 `Actions` 页面。
2. 选择 `Build iPhone App`，打开最新一次成功的构建。
3. 在页面底部下载 `iPhoneRestReminder-unsigned`。
4. 在 Windows 安装 [Sideloadly](https://sideloadly.io/)。
5. 用数据线连接 iPhone，将解压出的 IPA 拖入 Sideloadly。
6. 输入 Apple ID 并安装。
7. 在 iPhone 的“设置 → 通用 → VPN 与设备管理”中信任该开发者。

使用免费 Apple ID 安装的 App 通常需要每 7 天重新签名。Sideloadly 可在
电脑和手机处于同一网络时尝试自动刷新。

## 使用 Mac 安装

1. 在 Mac 上安装 Xcode。
2. 用 Xcode 打开 `iPhoneRestReminder.xcodeproj`。
3. 在项目的 Signing & Capabilities 中选择你的 Apple ID Team。
4. 连接 iPhone，选择该设备后点击运行。
5. 第一次启动时允许通知。

## iOS 限制

iOS 不允许普通 App 在其他 App 上方显示悬浮组件，也不会向普通 App
提供可靠的锁屏与整机使用状态。因此本项目在后台使用系统通知，App 内
倒计时则会根据实际经过时间更新。
