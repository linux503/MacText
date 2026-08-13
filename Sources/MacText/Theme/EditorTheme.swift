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

    /// Sublime Text classic **Monokai** (kept name "Ink" for session compatibility).
    static let ink = EditorTheme(
        name: "Ink",
        isDark: true,
        background: NSColor(srgbRed: 0.153, green: 0.157, blue: 0.133, alpha: 1),       // #272822
        foreground: NSColor(srgbRed: 0.973, green: 0.973, blue: 0.949, alpha: 1),       // #F8F8F2
        caret: NSColor(srgbRed: 0.973, green: 0.973, blue: 0.941, alpha: 1),            // #F8F8F0
        selection: NSColor(srgbRed: 0.286, green: 0.282, blue: 0.243, alpha: 1),         // #49483E
        lineNumber: NSColor(srgbRed: 0.459, green: 0.443, blue: 0.369, alpha: 1),       // #75715E
        lineNumberBackground: NSColor(srgbRed: 0.133, green: 0.137, blue: 0.118, alpha: 1),
        gutterBorder: NSColor(srgbRed: 0.220, green: 0.224, blue: 0.196, alpha: 1),
        keyword: NSColor(srgbRed: 0.976, green: 0.149, blue: 0.447, alpha: 1),          // #F92672
        string: NSColor(srgbRed: 0.902, green: 0.859, blue: 0.455, alpha: 1),            // #E6DB74
        comment: NSColor(srgbRed: 0.459, green: 0.443, blue: 0.369, alpha: 1),           // #75715E
        number: NSColor(srgbRed: 0.682, green: 0.506, blue: 1.000, alpha: 1),            // #AE81FF
        typeName: NSColor(srgbRed: 0.400, green: 0.851, blue: 0.937, alpha: 1),          // #66D9EF
        function: NSColor(srgbRed: 0.651, green: 0.886, blue: 0.180, alpha: 1),           // #A6E22E
        operatorColor: NSColor(srgbRed: 0.976, green: 0.149, blue: 0.447, alpha: 1),     // #F92672
        sidebarBackground: NSColor(srgbRed: 0.122, green: 0.125, blue: 0.110, alpha: 1),
        editorChrome: NSColor(srgbRed: 0.165, green: 0.169, blue: 0.145, alpha: 1),
        tabActive: NSColor(srgbRed: 0.153, green: 0.157, blue: 0.133, alpha: 1),
        tabInactive: NSColor(srgbRed: 0.133, green: 0.137, blue: 0.118, alpha: 1),
        accent: NSColor(srgbRed: 0.651, green: 0.886, blue: 0.180, alpha: 1),            // #A6E22E
        accentSecondary: NSColor(srgbRed: 0.992, green: 0.592, blue: 0.122, alpha: 1),   // #FD971F
        statusBar: NSColor(srgbRed: 0.110, green: 0.114, blue: 0.098, alpha: 1),
        findBarBackground: NSColor(srgbRed: 0.180, green: 0.184, blue: 0.157, alpha: 1),
        divider: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08),
        currentLine: NSColor(srgbRed: 0.243, green: 0.239, blue: 0.196, alpha: 1)        // #3E3D32
    )

    /// Sublime-like pure black / high-contrast Monokai on OLED.
    static let black = EditorTheme(
        name: "Black",
        isDark: true,
        background: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        foreground: NSColor(srgbRed: 0.973, green: 0.973, blue: 0.949, alpha: 1),
        caret: NSColor(srgbRed: 0.973, green: 0.973, blue: 0.941, alpha: 1),
        selection: NSColor(srgbRed: 0.220, green: 0.220, blue: 0.200, alpha: 1),
        lineNumber: NSColor(srgbRed: 0.459, green: 0.443, blue: 0.369, alpha: 1),
        lineNumberBackground: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        gutterBorder: NSColor(srgbRed: 0.140, green: 0.140, blue: 0.130, alpha: 1),
        keyword: NSColor(srgbRed: 0.976, green: 0.149, blue: 0.447, alpha: 1),
        string: NSColor(srgbRed: 0.902, green: 0.859, blue: 0.455, alpha: 1),
        comment: NSColor(srgbRed: 0.459, green: 0.443, blue: 0.369, alpha: 1),
        number: NSColor(srgbRed: 0.682, green: 0.506, blue: 1.000, alpha: 1),
        typeName: NSColor(srgbRed: 0.400, green: 0.851, blue: 0.937, alpha: 1),
        function: NSColor(srgbRed: 0.651, green: 0.886, blue: 0.180, alpha: 1),
        operatorColor: NSColor(srgbRed: 0.976, green: 0.149, blue: 0.447, alpha: 1),
        sidebarBackground: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        editorChrome: NSColor(srgbRed: 0.04, green: 0.04, blue: 0.04, alpha: 1),
        tabActive: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        tabInactive: NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1),
        accent: NSColor(srgbRed: 0.651, green: 0.886, blue: 0.180, alpha: 1),
        accentSecondary: NSColor(srgbRed: 0.992, green: 0.592, blue: 0.122, alpha: 1),
        statusBar: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
        findBarBackground: NSColor(srgbRed: 0.08, green: 0.08, blue: 0.08, alpha: 1),
        divider: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10),
        currentLine: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.11, alpha: 1)
    )

    /// Light — close to Sublime’s bright schemes (warm paper).
    static let paper = EditorTheme(
        name: "Paper",
        isDark: false,
        background: NSColor(srgbRed: 0.980, green: 0.973, blue: 0.957, alpha: 1),
        foreground: NSColor(srgbRed: 0.145, green: 0.157, blue: 0.133, alpha: 1),
        caret: NSColor(srgbRed: 0.145, green: 0.157, blue: 0.133, alpha: 1),
        selection: NSColor(srgbRed: 0.820, green: 0.880, blue: 0.760, alpha: 1),
        lineNumber: NSColor(srgbRed: 0.560, green: 0.545, blue: 0.490, alpha: 1),
        lineNumberBackground: NSColor(srgbRed: 0.955, green: 0.948, blue: 0.930, alpha: 1),
        gutterBorder: NSColor(srgbRed: 0.880, green: 0.870, blue: 0.840, alpha: 1),
        keyword: NSColor(srgbRed: 0.780, green: 0.080, blue: 0.320, alpha: 1),
        string: NSColor(srgbRed: 0.620, green: 0.480, blue: 0.050, alpha: 1),
        comment: NSColor(srgbRed: 0.520, green: 0.500, blue: 0.420, alpha: 1),
        number: NSColor(srgbRed: 0.420, green: 0.240, blue: 0.700, alpha: 1),
        typeName: NSColor(srgbRed: 0.050, green: 0.450, blue: 0.580, alpha: 1),
        function: NSColor(srgbRed: 0.320, green: 0.520, blue: 0.080, alpha: 1),
        operatorColor: NSColor(srgbRed: 0.780, green: 0.080, blue: 0.320, alpha: 1),
        sidebarBackground: NSColor(srgbRed: 0.940, green: 0.932, blue: 0.910, alpha: 1),
        editorChrome: NSColor(srgbRed: 0.960, green: 0.952, blue: 0.935, alpha: 1),
        tabActive: NSColor(srgbRed: 0.980, green: 0.973, blue: 0.957, alpha: 1),
        tabInactive: NSColor(srgbRed: 0.930, green: 0.922, blue: 0.900, alpha: 1),
        accent: NSColor(srgbRed: 0.400, green: 0.620, blue: 0.120, alpha: 1),
        accentSecondary: NSColor(srgbRed: 0.850, green: 0.450, blue: 0.050, alpha: 1),
        statusBar: NSColor(srgbRed: 0.920, green: 0.912, blue: 0.890, alpha: 1),
        findBarBackground: NSColor(srgbRed: 0.945, green: 0.938, blue: 0.920, alpha: 1),
        divider: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        currentLine: NSColor(srgbRed: 0.940, green: 0.950, blue: 0.900, alpha: 1)
    )

    /// Light — cool white (Sublime-ish daylight).
    static let snow = EditorTheme(
        name: "Snow",
        isDark: false,
        background: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        foreground: NSColor(srgbRed: 0.160, green: 0.180, blue: 0.210, alpha: 1),
        caret: NSColor(srgbRed: 0.160, green: 0.180, blue: 0.210, alpha: 1),
        selection: NSColor(srgbRed: 0.780, green: 0.880, blue: 0.980, alpha: 1),
        lineNumber: NSColor(srgbRed: 0.600, green: 0.640, blue: 0.700, alpha: 1),
        lineNumberBackground: NSColor(srgbRed: 0.970, green: 0.975, blue: 0.982, alpha: 1),
        gutterBorder: NSColor(srgbRed: 0.900, green: 0.910, blue: 0.925, alpha: 1),
        keyword: NSColor(srgbRed: 0.780, green: 0.080, blue: 0.320, alpha: 1),
        string: NSColor(srgbRed: 0.620, green: 0.220, blue: 0.120, alpha: 1),
        comment: NSColor(srgbRed: 0.520, green: 0.560, blue: 0.600, alpha: 1),
        number: NSColor(srgbRed: 0.420, green: 0.240, blue: 0.700, alpha: 1),
        typeName: NSColor(srgbRed: 0.050, green: 0.450, blue: 0.620, alpha: 1),
        function: NSColor(srgbRed: 0.220, green: 0.480, blue: 0.120, alpha: 1),
        operatorColor: NSColor(srgbRed: 0.780, green: 0.080, blue: 0.320, alpha: 1),
        sidebarBackground: NSColor(srgbRed: 0.955, green: 0.960, blue: 0.970, alpha: 1),
        editorChrome: NSColor(srgbRed: 0.975, green: 0.978, blue: 0.985, alpha: 1),
        tabActive: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        tabInactive: NSColor(srgbRed: 0.945, green: 0.950, blue: 0.960, alpha: 1),
        accent: NSColor(srgbRed: 0.160, green: 0.480, blue: 0.860, alpha: 1),
        accentSecondary: NSColor(srgbRed: 0.780, green: 0.080, blue: 0.320, alpha: 1),
        statusBar: NSColor(srgbRed: 0.935, green: 0.942, blue: 0.955, alpha: 1),
        findBarBackground: NSColor(srgbRed: 0.960, green: 0.965, blue: 0.975, alpha: 1),
        divider: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        currentLine: NSColor(srgbRed: 0.945, green: 0.960, blue: 0.985, alpha: 1)
    )

    static let all: [EditorTheme] = [.ink, .black, .paper, .snow]
    static let darkThemes: [EditorTheme] = [.ink, .black]
    static let lightThemes: [EditorTheme] = [.paper, .snow]

    static func named(_ name: String) -> EditorTheme? {
        if name == "Monokai" || name == "Midnight" { return .ink }
        if name == "Graphite" { return .black }
        return all.first { $0.name == name }
    }
}
