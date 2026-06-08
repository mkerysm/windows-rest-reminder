# iPhone Rest Reminder

一个使用 SwiftUI 编写的 iPhone 护眼和身体休息提醒 App。

## 功能

- 每 20 分钟发送一次远眺 20 秒提醒
- 每 60 分钟发送一次休息 5 分钟提醒
- App 内实时显示距离下次提醒的时间
- 提供 20 秒和 5 分钟休息倒计时
- 支持手动重置整个提醒周期
- 后台或锁屏时使用 iOS 本地通知
- 离开 App 超过 2 分钟后暂停计时，只保留前 2 分钟为正常使用时间
- 离开 App 满 5 分钟后再次打开时，自动重置护眼和身体休息周期

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
提供可靠的锁屏、触摸或整机空闲状态。因此 iPhone 版无法完全复制 Windows
版的全局空闲检测。本项目以 App 离开前台作为兼容判断：超过 2 分钟时暂停
超出阈值的计时，满 5 分钟后于再次打开时重置整个周期；在后台期间仍由
系统通知提醒。
