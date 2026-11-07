# GPToggle

桌面悬浮按钮，一键开关 GlobalProtect。

## 使用

| 操作 | 效果 |
| --- | --- |
| 单击 | 运行中 → 关闭；已关闭 → 开启 |
| 拖动 | 移动按钮（位置会记住） |
| 右键 / Control+单击 | 菜单：开关、登录时自动显示、查看日志、退出 |

颜色：绿色 = 运行中，灰色 = 已关闭，橙色转圈 = 处理中。

## 原理

GlobalProtect 以两个 LaunchAgent 运行在当前用户的图形会话里，界面进程带 `KeepAlive`，
所以强制退出后会被 launchd 立刻拉起。按钮做的是：

- 关闭：`launchctl bootout gui/<uid>/com.paloaltonetworks.gp.pangpa`（界面）和 `…pangps`（PanGPS 服务）
- 开启：`launchctl bootstrap gui/<uid> /Library/LaunchAgents/com.paloaltonetworks.gp.pangp{s,a}.plist`

不需要管理员密码，也不修改 GlobalProtect 的任何文件。关闭只对本次登录有效，
重启或重新登录后 GlobalProtect 会照常自动启动。

日志：`~/Library/Logs/GPToggle.log`

## 构建

需要 Xcode 命令行工具。

```bash
./build.sh           # 构建到 build/GPToggle.app
./build.sh install   # 构建并安装到 ~/Applications，然后启动
```

## 卸载

右键按钮 → 取消"登录时自动显示悬浮按钮" → 退出，然后删除 `~/Applications/GPToggle.app`。

## 环境

macOS 13+，Apple Silicon（`build.sh` 以 `arm64-apple-macos13.0` 为目标；Intel Mac 把 `-target` 改成 `x86_64-apple-macos13.0`）。

## 声明

与 Palo Alto Networks 无关。GlobalProtect 是 Palo Alto Networks 的商标。若你的组织要求始终保持 VPN 连接，请遵守组织规定。

*A floating desktop button that toggles the GlobalProtect VPN client on macOS via `launchctl`. Not affiliated with Palo Alto Networks.*

## License

MIT — see [LICENSE](LICENSE).
