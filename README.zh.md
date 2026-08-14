<p align="center">
  <img src="https://linux503.github.io/MacText/assets/icon-256.png?v=115" width="96" height="96" alt="MacText" />
</p>

<h1 align="center">MacText</h1>

<p align="center">
  <strong>原生 macOS 文本编辑器</strong> — Sublime 手感，AppKit 实现，没有 Electron 负担。<br/>
  多标签 · 侧栏 · 查找替换 · 命令面板 · 语法高亮 · 会话恢复
</p>

<p align="center">
  <b>中文</b> · <a href="README.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/linux503/MacText/releases/latest"><img src="https://img.shields.io/github/v/release/linux503/MacText?style=flat-square&label=release&color=a6e22e" alt="Release" /></a>
  <a href="https://github.com/linux503/MacText/releases"><img src="https://img.shields.io/badge/macOS-14%2B-111111?style=flat-square" alt="macOS 14+" /></a>
  <a href="https://github.com/linux503/MacText/releases"><img src="https://img.shields.io/badge/arch-Universal-24292f?style=flat-square" alt="Universal Binary" /></a>
</p>

<p align="center">
  <a href="https://github.com/linux503/MacText/releases/download/v1.1.5/MacText-1.1.5.dmg"><strong>下载 DMG</strong></a>
  ·
  <a href="https://linux503.github.io/MacText/zh/">中文官网</a>
  ·
  <a href="https://linux503.github.io/MacText/">English site</a>
  ·
  <a href="https://github.com/linux503/MacText/releases">全部版本</a>
</p>

---

<p align="center">
  <img src="docs/screenshots/product-hero.png" alt="MacText 产品介绍" width="880" />
</p>

## 为什么是 MacText

| | |
|---|---|
| **原生** | 纯 AppKit，启动快、内存低，没有 Electron |
| **熟悉** | Sublime 风格快捷键、标签、侧栏、命令面板 |
| **持久** | 退出后仍保留未保存内容、光标、文件夹、主题 |
| **双语** | 默认中文界面，设置里随时切换英文 |
| **Universal** | 一份 DMG 同时支持 Apple Silicon 与 Intel |

## 功能

| 区域 | 说明 |
|------|------|
| **编辑** | 多标签打开 / 保存 / 另存 / 关闭 · 未保存提示 · 行号 · 多行缩进 |
| **Sublime 键位** | 复制 / 移动 / 删除 / 合并行 · 注释 · 匹配括号 · 自动缩进 |
| **导航** | 文件夹侧栏（⌘B）· 转到行 · 命令面板（⌘⇧P）· 标签可撕出窗口 |
| **搜索** | 行内查找替换 · 下一个 / 上一个 · Esc 关闭 |
| **外观** | 主题：**Ink** · **Black** · **Paper** · **Snow** · 字号快捷键 |
| **语言** | Swift · Python · JavaScript / TypeScript · JSON · Markdown |
| **会话** | 恢复标签、未保存文本、光标、文件夹、主题、窗口位置 |
| **自动保存** | 会话备份始终开启；已有路径的文件可自动写回磁盘 |
| **更新** | 读取官网 `version.json`，不走 GitHub API 限额 |

## 安装

1. 下载 [MacText-1.1.5.dmg](https://github.com/linux503/MacText/releases/download/v1.1.5/MacText-1.1.5.dmg)
2. 将 **MacText** 拖入「应用程序」
3. 若 Gatekeeper 拦截：系统设置 → 隐私与安全性 → 仍要打开

需要 **macOS 14+**。Universal Binary。

## 快捷键

| 操作 | 快捷键 | 操作 | 快捷键 |
|------|--------|------|--------|
| 新建 | ⌘N | 查找 | ⌘F |
| 打开文件 | ⌘O | 替换 | ⌘⌥F |
| 打开文件夹 | ⌘⇧O | 命令面板 | ⌘⇧P |
| 保存 | ⌘S | 转到行 | ⌘⌥G |
| 关闭标签 | ⌘W | 侧栏 | ⌘B |
| 缩进 | Tab / ⌘] | 取消缩进 | ⇧Tab / ⌘[ |
| 复制行 | ⌘⇧D | 删除行 | ⌃⇧K |
| 选中行 | ⌘L | 合并行 | ⌘J |
| 移动行 | ⌘⌃↑/↓ | 注释 | ⌘/ |
| 匹配括号 | ⌃M | 切换主题 | ⌘⌥T |
| 放大 / 缩小字体 | ⌘+ / ⌘− | 设置 | ⌘, |

界面语言：**设置（⌘,）→ 界面语言**。

## 截图

<p align="center">
  <img src="docs/screenshots/editor-ink.png" alt="编辑器 — Ink 主题" width="880" />
</p>

<p align="center">
  <img src="docs/screenshots/command-palette.png" alt="命令面板" width="430" />
  &nbsp;
  <img src="docs/screenshots/editor-find.png" alt="查找替换" width="430" />
</p>

## 官网

- 中文：https://linux503.github.io/MacText/zh/
- English：https://linux503.github.io/MacText/

## 从源码构建

需要 **macOS 14+** 与 **Swift 5.9+**（Xcode 或 Command Line Tools）。

```bash
chmod +x Scripts/*.sh
./Scripts/release.sh          # 图标 + Universal .app + DMG → dist/
swift run                     # 源码调试运行
```

会话数据：`~/Library/Application Support/MacText/session.json`

## 其它工具

| 应用 | 说明 |
|------|------|
| [Flare Pro](https://github.com/linux503/Flare) | 截图与录屏 |
| [ZipX](https://github.com/linux503/ZipX) | 压缩 / 解压 / 预览 |
| [SupTools](https://github.com/linux503/suptools) | 系统监控、清理、卸载 |
| [FilesDesk](https://github.com/linux503/FilesDesk) | 批量重命名 |
| [MacFan](https://github.com/linux503/MacFan) | 风扇转速 |

## 许可

源码在 GitHub 开放。欢迎使用、Fork 与贡献。
