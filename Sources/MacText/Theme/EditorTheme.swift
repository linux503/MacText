import AppKit

struct EditorTheme: Equatable {
    var name: String
    var isDark: Bool
    var background: NSColor
    var foreground: NSColor
    var caret: NSColor
    var selection: NSColor
    var lineNumber: NSColor
    var lineNumberBackground: NSColor
    var gutterBorder: NSColor
    var keyword: NSColor
    var string: NSColor
    var comment: NSColor
    var number: NSColor
    var typeName: NSColor
    var function: NSColor
    var operatorColor: NSColor
    var sidebarBackground: NSColor
    var editorChrome: NSColor
    var tabActive: NSColor
    var tabInactive: NSColor
    var accent: NSColor
    var accentSecondary: NSColor
    var statusBar: NSColor
    var findBarBackground: NSColor
    var divider: NSColor
    var currentLine: NSColor

    var appearanceName: NSAppearance.Name {
        isDark ? .darkAqua : .aqua
    }

    /// Dark — charcoal + lime + amber (matches app icon).
    static let ink = EditorTheme(
        name: "Ink",
        isDark: true,
        background: NSColor(srgbRed: 0.102, green: 0.106, blue: 0.094, alpha: 1),
        foreground: NSColor(srgbRed: 0.973, green: 0.973, blue: 0.949, alpha: 1),
        caret: NSColor(srgbRed: 0.992, green: 0.592, blue: 0.122, alpha: 1),
        selection: NSColor(srgbRed: 0.220, green: 0.255, blue: 0.165, alpha: 1),
        lineNumber: NSColor(srgbRed: 0.420, green: 0.435, blue: 0.380, alpha: 1),
        lineNumberBackground: NSColor(srgbRed: 0.086, green: 0.090, blue: 0.078, alpha: 1),
        gutterBorder: NSColor(srgbRed: 0.160, green: 0.168, blue: 0.145, alpha: 1),
        keyword: NSColor(srgbRed: 0.992, green: 0.592, blue: 0.122, alpha: 1),
        string: NSColor(srgbRed: 0.902, green: 0.859, blue: 0.455, alpha: 1),
        comment: NSColor(srgbRed: 0.420, green: 0.435, blue: 0.380, alpha: 1),
        number: NSColor(srgbRed: 0.686, green: 0.780, blue: 0.910, alpha: 1),
        typeName: NSColor(srgbRed: 0.420, green: 0.820, blue: 0.890, alpha: 1),
        function: NSColor(srgbRed: 0.651, green: 0.886, blue: 0.180, alpha: 1),
        operatorColor: NSColor(srgbRed: 0.910, green: 0.450, blue: 0.520, alpha: 1),
        sidebarBackground: NSColor(srgbRed: 0.078, green: 0.082, blue: 0.071, alpha: 1),
        editorChrome: NSColor(srgbRed: 0.118, green: 0.122, blue: 0.110, alpha: 1),
        tabActive: NSColor(srgbRed: 0.102, green: 0.106, blue: 0.094, alpha: 1),
        tabInactive: NSColor(srgbRed: 0.090, green: 0.094, blue: 0.082, alpha: 1),
        accent: NSColor(srgbRed: 0.651, green: 0.886, blue: 0.180, alpha: 1),
        accentSecondary: NSColor(srgbRed: 0.992, green: 0.592, blue: 0.122, alpha: 1),
        statusBar: NSColor(srgbRed: 0.065, green: 0.069, blue: 0.059, alpha: 1),
        findBarBackground: NSColor(srgbRed: 0.130, green: 0.136, blue: 0.120, alpha: 1),
        divider: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.07),
        currentLine: NSColor(srgbRed: 0.130, green: 0.138, blue: 0.118, alpha: 1)
    )

    /// Dark — pure black OLED-style with high-contrast syntax colors.
    static let black = EditorTheme(
        name: "Black",
        isDark: true,
        background: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        foreground: NSColor(srgbRed: 0.92, green: 0.92, blue: 0.92, alpha: 1),
        caret: NSColor(srgbRed: 1.0, green: 0.72, blue: 0.20, alpha: 1),
        selection: NSColor(srgbRed: 0.18, green: 0.18, blue: 0.22, alpha: 1),
        lineNumber: NSColor(srgbRed: 0.38, green: 0.38, blue: 0.40, alpha: 1),
        lineNumberBackground: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        gutterBorder: NSColor(srgbRed: 0.14, green: 0.14, blue: 0.14, alpha: 1),
        keyword: NSColor(srgbRed: 1.0, green: 0.45, blue: 0.65, alpha: 1),
        string: NSColor(srgbRed: 0.90, green: 0.82, blue: 0.40, alpha: 1),
        comment: NSColor(srgbRed: 0.42, green: 0.45, blue: 0.48, alpha: 1),
        number: NSColor(srgbRed: 0.72, green: 0.62, blue: 1.0, alpha: 1),
        typeName: NSColor(srgbRed: 0.40, green: 0.85, blue: 0.95, alpha: 1),
        function: NSColor(srgbRed: 0.55, green: 0.92, blue: 0.45, alpha: 1),
        operatorColor: NSColor(srgbRed: 1.0, green: 0.55, blue: 0.45, alpha: 1),
        sidebarBackground: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        editorChrome: NSColor(srgbRed: 0.05, green: 0.05, blue: 0.05, alpha: 1),
        tabActive: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        tabInactive: NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1),
        accent: NSColor(srgbRed: 0.55, green: 0.92, blue: 0.45, alpha: 1),
        accentSecondary: NSColor(srgbRed: 1.0, green: 0.45, blue: 0.65, alpha: 1),
        statusBar: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        findBarBackground: NSColor(srgbRed: 0.08, green: 0.08, blue: 0.08, alpha: 1),
        divider: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10),
        currentLine: NSColor(srgbRed: 0.09, green: 0.09, blue: 0.09, alpha: 1)
    )

    /// Light — crisp paper white with forest green accent.
    static let paper = EditorTheme(
        name: "Paper",
        isDark: false,
        background: NSColor(srgbRed: 0.980, green: 0.982, blue: 0.975, alpha: 1),
        foreground: NSColor(srgbRed: 0.145, green: 0.160, blue: 0.150, alpha: 1),
        caret: NSColor(srgbRed: 0.180, green: 0.520, blue: 0.320, alpha: 1),
        selection: NSColor(srgbRed: 0.820, green: 0.920, blue: 0.840, alpha: 1),
        lineNumber: NSColor(srgbRed: 0.620, green: 0.650, blue: 0.620, alpha: 1),
        lineNumberBackground: NSColor(srgbRed: 0.955, green: 0.960, blue: 0.950, alpha: 1),
        gutterBorder: NSColor(srgbRed: 0.880, green: 0.890, blue: 0.870, alpha: 1),
        keyword: NSColor(srgbRed: 0.150, green: 0.430, blue: 0.360, alpha: 1),
        string: NSColor(srgbRed: 0.620, green: 0.320, blue: 0.120, alpha: 1),
        comment: NSColor(srgbRed: 0.560, green: 0.590, blue: 0.560, alpha: 1),
        number: NSColor(srgbRed: 0.180, green: 0.360, blue: 0.620, alpha: 1),
        typeName: NSColor(srgbRed: 0.200, green: 0.420, blue: 0.560, alpha: 1),
        function: NSColor(srgbRed: 0.280, green: 0.420, blue: 0.180, alpha: 1),
        operatorColor: NSColor(srgbRed: 0.620, green: 0.220, blue: 0.280, alpha: 1),
        sidebarBackground: NSColor(srgbRed: 0.940, green: 0.945, blue: 0.935, alpha: 1),
        editorChrome: NSColor(srgbRed: 0.960, green: 0.964, blue: 0.955, alpha: 1),
        tabActive: NSColor(srgbRed: 0.980, green: 0.982, blue: 0.975, alpha: 1),
        tabInactive: NSColor(srgbRed: 0.930, green: 0.935, blue: 0.925, alpha: 1),
        accent: NSColor(srgbRed: 0.220, green: 0.560, blue: 0.340, alpha: 1),
        accentSecondary: NSColor(srgbRed: 0.180, green: 0.420, blue: 0.360, alpha: 1),
        statusBar: NSColor(srgbRed: 0.920, green: 0.928, blue: 0.915, alpha: 1),
        findBarBackground: NSColor(srgbRed: 0.945, green: 0.950, blue: 0.940, alpha: 1),
        divider: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        currentLine: NSColor(srgbRed: 0.945, green: 0.960, blue: 0.940, alpha: 1)
    )

    /// Light — bright snow with sky-blue accents.
    static let snow = EditorTheme(
        name: "Snow",
        isDark: false,
        background: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        foreground: NSColor(srgbRed: 0.160, green: 0.180, blue: 0.210, alpha: 1),
        caret: NSColor(srgbRed: 0.120, green: 0.420, blue: 0.820, alpha: 1),
        selection: NSColor(srgbRed: 0.820, green: 0.900, blue: 0.980, alpha: 1),
        lineNumber: NSColor(srgbRed: 0.640, green: 0.670, blue: 0.710, alpha: 1),
        lineNumberBackground: NSColor(srgbRed: 0.970, green: 0.975, blue: 0.982, alpha: 1),
        gutterBorder: NSColor(srgbRed: 0.900, green: 0.910, blue: 0.925, alpha: 1),
        keyword: NSColor(srgbRed: 0.180, green: 0.320, blue: 0.720, alpha: 1),
        string: NSColor(srgbRed: 0.620, green: 0.220, blue: 0.180, alpha: 1),
        comment: NSColor(srgbRed: 0.560, green: 0.600, blue: 0.650, alpha: 1),
        number: NSColor(srgbRed: 0.520, green: 0.280, blue: 0.640, alpha: 1),
        typeName: NSColor(srgbRed: 0.120, green: 0.480, blue: 0.620, alpha: 1),
        function: NSColor(srgbRed: 0.220, green: 0.420, blue: 0.560, alpha: 1),
        operatorColor: NSColor(srgbRed: 0.700, green: 0.250, blue: 0.360, alpha: 1),
        sidebarBackground: NSColor(srgbRed: 0.955, green: 0.960, blue: 0.970, alpha: 1),
        editorChrome: NSColor(srgbRed: 0.975, green: 0.978, blue: 0.985, alpha: 1),
        tabActive: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        tabInactive: NSColor(srgbRed: 0.945, green: 0.950, blue: 0.960, alpha: 1),
        accent: NSColor(srgbRed: 0.160, green: 0.480, blue: 0.860, alpha: 1),
        accentSecondary: NSColor(srgbRed: 0.220, green: 0.420, blue: 0.720, alpha: 1),
        statusBar: NSColor(srgbRed: 0.935, green: 0.942, blue: 0.955, alpha: 1),
        findBarBackground: NSColor(srgbRed: 0.960, green: 0.965, blue: 0.975, alpha: 1),
        divider: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        currentLine: NSColor(srgbRed: 0.945, green: 0.960, blue: 0.985, alpha: 1)
    )

    static let all: [EditorTheme] = [.ink, .black, .paper, .snow]
    static let darkThemes: [EditorTheme] = [.ink, .black]
    static let lightThemes: [EditorTheme] = [.paper, .snow]

    static func named(_ name: String) -> EditorTheme? {
        all.first { $0.name == name }
    }
}
