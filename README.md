# Windows Rest Reminder

一个轻量的 Windows 护眼与身体休息提醒器。

## 功能

- 每使用电脑 20 分钟，弹出 20 秒远眺倒计时
- 每使用电脑 60 分钟，弹出 5 分钟休息倒计时
- 桌面小组件实时显示距离下次提醒的时间
- 小组件可选择是否置顶
- 提醒弹窗居中并始终置顶
- 锁屏、睡眠或休眠后自动重置计时
- 登录 Windows 后自动启动
- 不显示 PowerShell 任务栏图标

## 使用

1. 将本仓库下载到 Windows 电脑。
2. 双击 `启动休息提醒.vbs`。
3. 如需开机自动运行，为 `启动休息提醒.vbs` 创建快捷方式并放入 Windows 启动文件夹。

程序使用 Windows PowerShell 5.1 和 WPF，无需安装第三方依赖。

## 文件

- `休息提醒.ps1`：提醒器与桌面小组件
- `启动休息提醒.vbs`：静默启动脚本
- `iphone-rest-reminder`：iPhone SwiftUI 版本，可通过 GitHub 云端构建
