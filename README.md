# Idle

极简 macOS 菜单栏防休眠工具。

- 左键点击：开启 / 关闭防休眠（月亮 ⇄ 橙色太阳）
- 右键（或 Control+点击）：退出

等价于 `caffeinate -di`：阻止屏幕休眠和系统空闲休眠。

## 构建
推送到 GitHub 后，Actions 自动编译。
打 tag 会自动发布 Release：

    git tag v1.0 && git push origin v1.0

## 首次打开
仅支持 Apple Silicon (arm64)，macOS 11+。

应用未经 Apple 公证，下载后若提示“已损坏/无法验证”，执行：

    xattr -cr /Applications/Idle.app
