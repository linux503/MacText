import Foundation

enum AppLanguage: String, CaseIterable {
    case zh
    case en

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        }
    }

    static var `default`: AppLanguage { .zh }
}

enum L10n {
    private static let defaultsKey = "mactext.uiLanguage"

    static var language: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: defaultsKey),
               let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return .default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: .macTextLanguageChanged, object: nil)
        }
    }

    static var isChinese: Bool { language == .zh }

    static func t(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }

    // MARK: - Common strings

    static var settings: String { t("设置…", "Settings…") }
    static var about: String { t("关于 MacText", "About MacText") }
    static var quit: String { t("退出 MacText", "Quit MacText") }

    static var fileMenu: String { t("文件", "File") }
    static var editMenu: String { t("编辑", "Edit") }
    static var findMenu: String { t("查找", "Find") }
    static var viewMenu: String { t("显示", "View") }

    static var newFile: String { t("新建文件", "New File") }
    static var openFile: String { t("打开文件…", "Open File…") }
    static var openFolder: String { t("打开文件夹…", "Open Folder…") }
    static var save: String { t("保存", "Save") }
    static var saveAs: String { t("另存为…", "Save As…") }
    static var closeTab: String { t("关闭标签", "Close Tab") }
    static var close: String { t("关闭", "Close") }
    static var closeOthers: String { t("关闭其他", "Close Others") }

    static var undo: String { t("撤销", "Undo") }
    static var redo: String { t("重做", "Redo") }
    static var cut: String { t("剪切", "Cut") }
    static var copy: String { t("复制", "Copy") }
    static var paste: String { t("粘贴", "Paste") }
    static var selectAll: String { t("全选", "Select All") }
    static var indent: String { t("缩进", "Indent") }
    static var unindent: String { t("取消缩进", "Unindent") }

    static var find: String { t("查找…", "Find…") }
    static var replace: String { t("替换…", "Replace…") }
    static var findNext: String { t("查找下一个", "Find Next") }
    static var findPrevious: String { t("查找上一个", "Find Previous") }

    static var toggleSidebar: String { t("切换侧边栏", "Toggle Sidebar") }
    static var hideSidebar: String { t("隐藏侧边栏", "Hide Sidebar") }
    static var showSidebar: String { t("显示侧边栏", "Show Sidebar") }
    static var softWrap: String { t("自动换行", "Soft Wrap") }
    static var biggerFont: String { t("增大字体", "Bigger") }
    static var smallerFont: String { t("减小字体", "Smaller") }
    static var resetFont: String { t("重置字体大小", "Reset Font Size") }
    static var theme: String { t("主题", "Theme") }
    static var dark: String { t("深色", "Dark") }
    static var light: String { t("浅色", "Light") }
    static var autoSave: String { t("自动保存到磁盘", "Auto-Save to Disk") }
    static var autoSaveHint: String {
        t(
            "已打开的文件会在后台自动写入；所有标签内容也会写入会话备份。",
            "Files with a path are written automatically; all tab buffers are also kept in the session backup."
        )
    }

    static var duplicateLine: String { t("复制行", "Duplicate Line") }
    static var deleteLine: String { t("删除行", "Delete Line") }
    static var selectLine: String { t("选择行", "Select Line") }
    static var joinLines: String { t("合并行", "Join Lines") }
    static var moveLineUp: String { t("上移行", "Move Line Up") }
    static var moveLineDown: String { t("下移行", "Move Line Down") }
    static var toggleComment: String { t("切换注释", "Toggle Comment") }
    static var matchingBracket: String { t("匹配括号", "Jump to Matching Bracket") }

    static var appearance: String { t("外观", "Appearance") }
    static var colorTheme: String { t("颜色主题", "Color Theme") }
    static var fontSize: String { t("字体大小", "Font Size") }
    static var languageLabel: String { t("界面语言", "Language") }
    static var settingsTitle: String { t("MacText 设置", "MacText Settings") }
    static var settingsHint: String {
        t(
            "字体也可：显示 → 增大/减小（⌘+ / ⌘−）。主题：显示 → 主题或状态栏。",
            "Font size also: View → Bigger/Smaller (⌘+ / ⌘−). Themes: View → Theme or status bar."
        )
    }

    static var goToLine: String { t("跳转到行", "Go to Line") }
    static var goToLineHint: String { t("输入行号", "Enter a line number") }
    static var go: String { t("跳转", "Go") }
    static var cancel: String { t("取消", "Cancel") }
    static var saveChangesTitle: String { t("是否保存对“%@”的更改？", "Do you want to save the changes you made to “%@”?") }
    static var saveChangesBody: String {
        t("如果不保存，更改将丢失。", "Your changes will be lost if you don’t save them.")
    }
    static var dontSave: String { t("不保存", "Don’t Save") }
    static var commandPalette: String { t("命令面板", "Command Palette") }
    static var preferences: String { t("设置…", "Settings…") }
    static var cycleTheme: String { t("切换颜色主题", "Cycle Color Theme") }
    static var biggerFontCmd: String { t("增大字体", "Bigger Font") }
    static var smallerFontCmd: String { t("减小字体", "Smaller Font") }
}

extension Notification.Name {
    static let macTextLanguageChanged = Notification.Name("MacTextLanguageChanged")
}
