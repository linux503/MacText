# MacText

原生 macOS 文本编辑器（AppKit），覆盖 Sublime Text 核心能力：多标签、侧边栏、行号、查找替换、命令面板、基础语法高亮。

**下载：** [MacText 1.0.3 DMG](https://github.com/linux503/MacText/releases/tag/v1.0.3) · [Releases](https://github.com/linux503/MacText/releases)

## 要求

- macOS 14+
- Swift 5.9+ / Command Line Tools 或 Xcode（当前工程可用 CLT 直接 `swift build`）

## 构建 / 发布

```bash
# 完整发布：图标 + Universal App + DMG
chmod +x Scripts/*.sh
./Scripts/release.sh
```

产物：
- `dist/MacText.app` — Universal（arm64 + x86_64）
- `dist/MacText-1.0.3.dmg` — 安装包（拖到 Applications）

单独步骤：

```bash
./Scripts/make_icon.sh   # 生成 AppIcon.icns
./Scripts/build_app.sh   # 编译 .app
./Scripts/make_dmg.sh    # 打包 .dmg
```

开发调试也可：

```bash
swift run
```

## 快捷键

| 动作 | 快捷键 |
|------|--------|
| 新建 | ⌘N |
| 打开文件 | ⌘O |
| 打开文件夹 | ⌘⇧O |
| 保存 | ⌘S |
| 另存为 | ⌘⇧S |
| 关闭标签 | ⌘W |
| 查找 | ⌘F |
| 替换 | ⌘⌥F |
| 查找下一个 | ⌘G |
| 命令面板 | ⌘⇧P |
| 跳转行 | ⌘⌥G |
| 切换侧边栏 | ⌘B |

## 会话恢复

关闭应用后，下次打开会自动恢复：

- 已打开的标签页与文本内容（含未保存修改）
- 当前选中标签、光标位置
- 打开的文件夹侧边栏
- 主题、软换行、窗口位置

会话保存在 `~/Library/Application Support/MacText/session.json`。

## 主题

共 4 套：

| 类型 | 主题 |
|------|------|
| 深色 | **Ink**（默认）、**Black**（纯黑） |
| 浅色 | **Paper**、**Snow** |

切换入口：Settings（⌘,）、View → Theme、状态栏 Theme、⌘⌥T。

## 语法高亮

支持：Swift、Python、JavaScript/TypeScript、JSON、Markdown。
