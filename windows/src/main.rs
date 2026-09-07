//! MacText for Windows. Same Ink / Black / Paper / Snow chrome as the macOS app.
use eframe::egui::{self, Color32, FontData, FontDefinitions, FontFamily, Key, RichText, Sense, TextEdit, Ui, Vec2};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;

const APP_VERSION: &str = "1.1.7";

fn main() -> eframe::Result<()> {
    let mut viewport = egui::ViewportBuilder::default()
        .with_title("MacText")
        .with_inner_size([1180.0, 760.0])
        .with_min_inner_size([860.0, 520.0]);
    if let Some(session) = Session::load() {
        if let Some([x, y, w, h]) = session.frame {
            if w > 400.0 && h > 300.0 {
                viewport = viewport.with_inner_size([w, h]).with_position([x, y]);
            }
        }
    }
    eframe::run_native(
        "MacText",
        eframe::NativeOptions {
            viewport,
            ..Default::default()
        },
        Box::new(|cc| Ok(Box::new(App::new(cc)))),
    )
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum ThemeName {
    Ink,
    Black,
    Paper,
    Snow,
}

impl ThemeName {
    fn label(self) -> &'static str {
        match self {
            Self::Ink => "Ink",
            Self::Black => "Black",
            Self::Paper => "Paper",
            Self::Snow => "Snow",
        }
    }
    fn all() -> [Self; 4] {
        [Self::Ink, Self::Black, Self::Paper, Self::Snow]
    }
}

struct Palette {
    dark: bool,
    bg: Color32,
    fg: Color32,
    caret: Color32,
    selection: Color32,
    line_number: Color32,
    gutter: Color32,
    keyword: Color32,
    string: Color32,
    comment: Color32,
    number: Color32,
    type_name: Color32,
    function: Color32,
    sidebar: Color32,
    chrome: Color32,
    tab_active: Color32,
    tab_inactive: Color32,
    accent: Color32,
    accent2: Color32,
    status: Color32,
    find: Color32,
    divider: Color32,
}

impl Palette {
    fn of(name: ThemeName) -> Self {
        match name {
            ThemeName::Ink => Self {
                dark: true,
                bg: c(0.153, 0.157, 0.133),
                fg: c(0.973, 0.973, 0.949),
                caret: c(0.973, 0.973, 0.941),
                selection: c(0.286, 0.282, 0.243),
                line_number: c(0.459, 0.443, 0.369),
                gutter: c(0.133, 0.137, 0.118),
                keyword: c(0.976, 0.149, 0.447),
                string: c(0.902, 0.859, 0.455),
                comment: c(0.459, 0.443, 0.369),
                number: c(0.682, 0.506, 1.0),
                type_name: c(0.400, 0.851, 0.937),
                function: c(0.651, 0.886, 0.180),
                sidebar: c(0.122, 0.125, 0.110),
                chrome: c(0.165, 0.169, 0.145),
                tab_active: c(0.153, 0.157, 0.133),
                tab_inactive: c(0.133, 0.137, 0.118),
                accent: c(0.651, 0.886, 0.180),
                accent2: c(0.992, 0.592, 0.122),
                status: c(0.110, 0.114, 0.098),
                find: c(0.180, 0.184, 0.157),
                divider: Color32::from_white_alpha(20),
            },
            ThemeName::Black => Self {
                dark: true,
                bg: Color32::BLACK,
                fg: c(0.973, 0.973, 0.949),
                caret: c(0.973, 0.973, 0.941),
                selection: c(0.220, 0.220, 0.200),
                line_number: c(0.459, 0.443, 0.369),
                gutter: Color32::BLACK,
                keyword: c(0.976, 0.149, 0.447),
                string: c(0.902, 0.859, 0.455),
                comment: c(0.459, 0.443, 0.369),
                number: c(0.682, 0.506, 1.0),
                type_name: c(0.400, 0.851, 0.937),
                function: c(0.651, 0.886, 0.180),
                sidebar: Color32::BLACK,
                chrome: c(0.04, 0.04, 0.04),
                tab_active: Color32::BLACK,
                tab_inactive: c(0.06, 0.06, 0.06),
                accent: c(0.651, 0.886, 0.180),
                accent2: c(0.992, 0.592, 0.122),
                status: Color32::BLACK,
                find: c(0.08, 0.08, 0.08),
                divider: Color32::from_white_alpha(26),
            },
            ThemeName::Paper => Self {
                dark: false,
                bg: c(0.980, 0.973, 0.957),
                fg: c(0.145, 0.157, 0.133),
                caret: c(0.145, 0.157, 0.133),
                selection: c(0.820, 0.880, 0.760),
                line_number: c(0.560, 0.545, 0.490),
                gutter: c(0.955, 0.948, 0.930),
                keyword: c(0.780, 0.080, 0.320),
                string: c(0.620, 0.480, 0.050),
                comment: c(0.520, 0.500, 0.420),
                number: c(0.420, 0.240, 0.700),
                type_name: c(0.050, 0.450, 0.580),
                function: c(0.320, 0.520, 0.080),
                sidebar: c(0.940, 0.932, 0.910),
                chrome: c(0.960, 0.952, 0.935),
                tab_active: c(0.980, 0.973, 0.957),
                tab_inactive: c(0.930, 0.922, 0.900),
                accent: c(0.400, 0.620, 0.120),
                accent2: c(0.850, 0.450, 0.050),
                status: c(0.920, 0.912, 0.890),
                find: c(0.945, 0.938, 0.920),
                divider: Color32::from_black_alpha(20),
            },
            ThemeName::Snow => Self {
                dark: false,
                bg: Color32::WHITE,
                fg: c(0.160, 0.180, 0.210),
                caret: c(0.160, 0.180, 0.210),
                selection: c(0.780, 0.880, 0.980),
                line_number: c(0.600, 0.640, 0.700),
                gutter: c(0.970, 0.975, 0.982),
                keyword: c(0.780, 0.080, 0.320),
                string: c(0.620, 0.220, 0.120),
                comment: c(0.520, 0.560, 0.600),
                number: c(0.420, 0.240, 0.700),
                type_name: c(0.050, 0.450, 0.620),
                function: c(0.220, 0.480, 0.120),
                sidebar: c(0.955, 0.960, 0.970),
                chrome: c(0.975, 0.978, 0.985),
                tab_active: Color32::WHITE,
                tab_inactive: c(0.945, 0.950, 0.960),
                accent: c(0.160, 0.480, 0.860),
                accent2: c(0.780, 0.080, 0.320),
                status: c(0.935, 0.942, 0.955),
                find: c(0.960, 0.965, 0.975),
                divider: Color32::from_black_alpha(20),
            },
        }
    }
}

fn c(r: f32, g: f32, b: f32) -> Color32 {
    Color32::from_rgb((r * 255.0) as u8, (g * 255.0) as u8, (b * 255.0) as u8)
}

#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
enum LangKind {
    Plain,
    Swift,
    Python,
    JavaScript,
    TypeScript,
    Json,
    Markdown,
}

impl LangKind {
    fn label(self, zh: bool) -> &'static str {
        match self {
            Self::Plain => if zh { "纯文本" } else { "Plain" },
            Self::Swift => "Swift",
            Self::Python => "Python",
            Self::JavaScript => "JavaScript",
            Self::TypeScript => "TypeScript",
            Self::Json => "JSON",
            Self::Markdown => "Markdown",
        }
    }
    fn from_path(path: &Path) -> Self {
        match path.extension().and_then(|e| e.to_str()).unwrap_or("").to_ascii_lowercase().as_str() {
            "swift" => Self::Swift,
            "py" => Self::Python,
            "js" | "mjs" | "cjs" => Self::JavaScript,
            "ts" | "tsx" => Self::TypeScript,
            "json" => Self::Json,
            "md" | "markdown" => Self::Markdown,
            _ => Self::Plain,
        }
    }
}

struct Tab {
    title: String,
    path: Option<PathBuf>,
    text: String,
    dirty: bool,
    lang: LangKind,
}

impl Tab {
    fn untitled(n: u32, zh: bool) -> Self {
        Self {
            title: if zh { format!("未命名 {n}") } else { format!("Untitled {n}") },
            path: None,
            text: String::new(),
            dirty: false,
            lang: LangKind::Plain,
        }
    }
    fn display(&self) -> String {
        if self.dirty { format!("• {}", self.title) } else { self.title.clone() }
    }
}

#[derive(Serialize, Deserialize)]
struct SavedTab {
    title: String,
    path: Option<String>,
    text: String,
    dirty: bool,
}

#[derive(Serialize, Deserialize)]
struct Session {
    theme: String,
    zh: bool,
    sidebar: bool,
    font: f32,
    folder: Option<String>,
    active: usize,
    tabs: Vec<SavedTab>,
    frame: Option<[f32; 4]>,
}

impl Session {
    fn path() -> PathBuf {
        let base = std::env::var_os("APPDATA")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("."));
        base.join("MacText").join("session.json")
    }
    fn load() -> Option<Self> {
        let raw = fs::read_to_string(Self::path()).ok()?;
        serde_json::from_str(&raw).ok()
    }
    fn save(&self) {
        let path = Self::path();
        if let Some(dir) = path.parent() {
            let _ = fs::create_dir_all(dir);
        }
        if let Ok(raw) = serde_json::to_string_pretty(self) {
            let _ = fs::write(path, raw);
        }
    }
}

struct App {
    tabs: Vec<Tab>,
    active: usize,
    next_id: u32,
    theme: ThemeName,
    zh: bool,
    sidebar: bool,
    folder: Option<PathBuf>,
    font: f32,
    find_open: bool,
    replace_open: bool,
    find: String,
    replace: String,
    palette_open: bool,
    palette_query: String,
    goto_open: bool,
    goto_line: String,
    status: String,
    focus_editor: bool,
    focus_find: bool,
    focus_palette: bool,
}

impl App {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        install_fonts(&cc.egui_ctx);
        let mut app = Self {
            tabs: vec![Tab::untitled(1, true)],
            active: 0,
            next_id: 2,
            theme: ThemeName::Ink,
            zh: true,
            sidebar: true,
            folder: None,
            font: 15.0,
            find_open: false,
            replace_open: false,
            find: String::new(),
            replace: String::new(),
            palette_open: false,
            palette_query: String::new(),
            goto_open: false,
            goto_line: String::new(),
            status: String::new(),
            focus_editor: true,
            focus_find: false,
            focus_palette: false,
        };
        if let Some(session) = Session::load() {
            app.theme = match session.theme.as_str() {
                "Black" => ThemeName::Black,
                "Paper" => ThemeName::Paper,
                "Snow" => ThemeName::Snow,
                _ => ThemeName::Ink,
            };
            app.zh = session.zh;
            app.sidebar = session.sidebar;
            app.font = session.font.clamp(11.0, 28.0);
            app.folder = session.folder.map(PathBuf::from);
            app.tabs = session
                .tabs
                .into_iter()
                .map(|t| {
                    let path = t.path.map(PathBuf::from);
                    let lang = path.as_ref().map(|p| LangKind::from_path(p)).unwrap_or(LangKind::Plain);
                    Tab {
                        title: t.title,
                        path,
                        text: t.text,
                        dirty: t.dirty,
                        lang,
                    }
                })
                .collect();
            if app.tabs.is_empty() {
                app.tabs.push(Tab::untitled(1, app.zh));
            }
            app.active = session.active.min(app.tabs.len() - 1);
            app.next_id = app.tabs.len() as u32 + 1;
        }
        app.apply_style(&cc.egui_ctx);
        app
    }

    fn t(&self, zh: &str, en: &str) -> String {
        if self.zh { zh.to_string() } else { en.to_string() }
    }

    fn pal(&self) -> Palette {
        Palette::of(self.theme)
    }

    fn apply_style(&self, ctx: &egui::Context) {
        let p = self.pal();
        let mut visuals = if p.dark { egui::Visuals::dark() } else { egui::Visuals::light() };
        visuals.window_fill = p.chrome;
        visuals.panel_fill = p.chrome;
        visuals.extreme_bg_color = p.bg;
        visuals.faint_bg_color = p.tab_inactive;
        visuals.code_bg_color = p.bg;
        visuals.widgets.noninteractive.fg_stroke.color = p.fg;
        visuals.widgets.inactive.fg_stroke.color = p.fg;
        visuals.widgets.hovered.fg_stroke.color = p.fg;
        visuals.widgets.active.fg_stroke.color = p.fg;
        visuals.widgets.inactive.bg_fill = p.tab_inactive;
        visuals.widgets.hovered.bg_fill = p.find;
        visuals.widgets.active.bg_fill = p.selection;
        visuals.selection.bg_fill = p.selection;
        visuals.selection.stroke.color = p.accent;
        visuals.hyperlink_color = p.accent;
        visuals.window_stroke.color = p.divider;
        ctx.set_visuals(visuals);
    }

    fn tab(&self) -> &Tab {
        &self.tabs[self.active]
    }
    fn tab_mut(&mut self) -> &mut Tab {
        &mut self.tabs[self.active]
    }

    fn new_tab(&mut self) {
        let tab = Tab::untitled(self.next_id, self.zh);
        self.next_id += 1;
        self.tabs.push(tab);
        self.active = self.tabs.len() - 1;
        self.focus_editor = true;
    }

    fn close_tab(&mut self, idx: usize) {
        if self.tabs.len() == 1 {
            self.tabs[0] = Tab::untitled(self.next_id, self.zh);
            self.next_id += 1;
            return;
        }
        self.tabs.remove(idx);
        if self.active >= self.tabs.len() {
            self.active = self.tabs.len() - 1;
        } else if idx < self.active {
            self.active -= 1;
        }
    }

    fn open_files(&mut self, paths: Vec<PathBuf>) {
        if paths.is_empty() {
            return;
        }
        for path in paths {
            if let Some(i) = self.tabs.iter().position(|t| t.path.as_ref() == Some(&path)) {
                self.active = i;
                continue;
            }
            match fs::read_to_string(&path) {
                Ok(text) => {
                    let title = path.file_name().and_then(|s| s.to_str()).unwrap_or("file").to_string();
                    let lang = LangKind::from_path(&path);
                    if self.tabs.len() == 1 && self.tabs[0].path.is_none() && self.tabs[0].text.is_empty() && !self.tabs[0].dirty {
                        self.tabs[0] = Tab { title, path: Some(path), text, dirty: false, lang };
                        self.active = 0;
                    } else {
                        self.tabs.push(Tab { title, path: Some(path), text, dirty: false, lang });
                        self.active = self.tabs.len() - 1;
                    }
                }
                Err(err) => self.status = err.to_string(),
            }
        }
        self.focus_editor = true;
    }

    fn open_dialog(&mut self) {
        let mut dlg = rfd::FileDialog::new();
        if let Some(folder) = &self.folder {
            dlg = dlg.set_directory(folder);
        }
        if let Some(paths) = dlg.pick_files() {
            self.open_files(paths);
        }
    }

    fn open_folder(&mut self) {
        if let Some(dir) = rfd::FileDialog::new().pick_folder() {
            self.folder = Some(dir);
            self.sidebar = true;
        }
    }

    fn save_current(&mut self) -> bool {
        if self.tab().path.is_none() {
            return self.save_as();
        }
        let path = self.tab().path.clone().unwrap();
        match fs::write(&path, &self.tab().text) {
            Ok(()) => {
                self.tab_mut().dirty = false;
                self.status = self.t("已保存", "Saved");
                true
            }
            Err(err) => {
                self.status = err.to_string();
                false
            }
        }
    }

    fn save_as(&mut self) -> bool {
        let mut dlg = rfd::FileDialog::new().set_file_name(&self.tab().title);
        if let Some(folder) = &self.folder {
            dlg = dlg.set_directory(folder);
        }
        if let Some(path) = dlg.save_file() {
            match fs::write(&path, &self.tab().text) {
                Ok(()) => {
                    let title = path.file_name().and_then(|s| s.to_str()).unwrap_or("file").to_string();
                    let lang = LangKind::from_path(&path);
                    let tab = self.tab_mut();
                    tab.path = Some(path);
                    tab.title = title;
                    tab.lang = lang;
                    tab.dirty = false;
                    self.status = self.t("已保存", "Saved");
                    true
                }
                Err(err) => {
                    self.status = err.to_string();
                    false
                }
            }
        } else {
            false
        }
    }

    fn persist(&self) {
        Session {
            theme: self.theme.label().to_string(),
            zh: self.zh,
            sidebar: self.sidebar,
            font: self.font,
            folder: self.folder.as_ref().map(|p| p.display().to_string()),
            active: self.active,
            tabs: self
                .tabs
                .iter()
                .map(|t| SavedTab {
                    title: t.title.clone(),
                    path: t.path.as_ref().map(|p| p.display().to_string()),
                    text: t.text.clone(),
                    dirty: t.dirty,
                })
                .collect(),
            frame: None,
        }
        .save();
    }

    fn find_next(&mut self, reverse: bool) {
        if self.find.is_empty() {
            return;
        }
        let text = self.tab().text.clone();
        let needle = self.find.clone();
        let lower = text.to_lowercase();
        let nlower = needle.to_lowercase();
        let hits: Vec<usize> = lower.match_indices(&nlower).map(|(i, _)| i).collect();
        if hits.is_empty() {
            self.status = self.t("无匹配", "No matches");
            return;
        }
        let cursor = 0usize;
        let pick = if reverse {
            hits.iter().rev().find(|i| **i < cursor).copied().unwrap_or(*hits.last().unwrap())
        } else {
            hits.iter().find(|i| **i >= cursor).copied().unwrap_or(hits[0])
        };
        self.status = if self.zh {
            format!("匹配 {} 处", hits.len())
        } else {
            format!("{} matches", hits.len())
        };
        let _ = pick;
    }

    fn replace_all(&mut self) {
        if self.find.is_empty() {
            return;
        }
        let text = self.tab().text.clone();
        let next = replace_ignore_case(&text, &self.find, &self.replace);
        if next != text {
            self.tab_mut().text = next;
            self.tab_mut().dirty = true;
            self.status = self.t("已全部替换", "Replaced all");
        }
    }

    fn goto(&mut self) {
        let line: usize = self.goto_line.trim().parse().unwrap_or(0);
        if line == 0 {
            return;
        }
        let text = &self.tab().text;
        let mut at = 0usize;
        for (i, line_text) in text.split('\n').enumerate() {
            if i + 1 == line {
                let _ = at;
                self.status = if self.zh { format!("第 {line} 行") } else { format!("Line {line}") };
                break;
            }
            at += line_text.len() + 1;
        }
        self.goto_open = false;
    }

    fn toggle_comment(&mut self) {
        let text = self.tab().text.clone();
        let prefix = match self.tab().lang {
            LangKind::Python => "# ",
            LangKind::Markdown | LangKind::Plain => "# ",
            _ => "// ",
        };
        let next = if text.lines().all(|l| l.trim_start().starts_with(prefix.trim()) || l.trim().is_empty()) {
            text.lines()
                .map(|l| l.strip_prefix(prefix).or_else(|| l.strip_prefix(prefix.trim())).unwrap_or(l))
                .collect::<Vec<_>>()
                .join("\n")
        } else {
            text.lines().map(|l| if l.trim().is_empty() { l.to_string() } else { format!("{prefix}{l}") }).collect::<Vec<_>>().join("\n")
        };
        self.tab_mut().text = next;
        self.tab_mut().dirty = true;
    }

    fn duplicate_line(&mut self) {
        let text = self.tab().text.clone();
        let next = text.lines().map(|l| format!("{l}\n{l}")).collect::<Vec<_>>().join("\n");
        if !text.is_empty() {
            self.tab_mut().text = next;
            self.tab_mut().dirty = true;
        }
    }

    fn indent(&mut self, out: bool) {
        let text = self.tab().text.clone();
        let next = text
            .lines()
            .map(|l| {
                if out {
                    l.strip_prefix("    ").or_else(|| l.strip_prefix("\t")).unwrap_or(l).to_string()
                } else {
                    format!("    {l}")
                }
            })
            .collect::<Vec<_>>()
            .join("\n");
        self.tab_mut().text = next;
        self.tab_mut().dirty = true;
    }

    fn run_palette(&mut self, id: &str) {
        match id {
            "new" => self.new_tab(),
            "open" => self.open_dialog(),
            "folder" => self.open_folder(),
            "save" => { self.save_current(); }
            "saveas" => { self.save_as(); }
            "find" => { self.find_open = true; self.focus_find = true; }
            "replace" => { self.find_open = true; self.replace_open = true; self.focus_find = true; }
            "sidebar" => self.sidebar = !self.sidebar,
            "zh" => self.zh = true,
            "en" => self.zh = false,
            "goto" => self.goto_open = true,
            "comment" => self.toggle_comment(),
            "bigger" => self.font = (self.font + 1.0).min(28.0),
            "smaller" => self.font = (self.font - 1.0).max(11.0),
            "ink" => self.theme = ThemeName::Ink,
            "black" => self.theme = ThemeName::Black,
            "paper" => self.theme = ThemeName::Paper,
            "snow" => self.theme = ThemeName::Snow,
            _ => {}
        }
        self.palette_open = false;
        self.palette_query.clear();
    }
}

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.apply_style(ctx);
        let p = self.pal();
        self.handle_keys(ctx);

        egui::TopBottomPanel::top("chrome")
            .exact_height(46.0)
            .frame(egui::Frame::new().fill(p.chrome).inner_margin(egui::Margin::symmetric(14, 8)))
            .show(ctx, |ui| self.chrome_bar(ui, &p));

        egui::TopBottomPanel::bottom("status")
            .exact_height(28.0)
            .frame(egui::Frame::new().fill(p.status).inner_margin(egui::Margin::symmetric(12, 4)))
            .show(ctx, |ui| self.status_bar(ui, &p));

        if self.sidebar {
            egui::SidePanel::left("sidebar")
                .exact_width(228.0)
                .frame(egui::Frame::new().fill(p.sidebar).inner_margin(egui::Margin::symmetric(10, 10)))
                .show(ctx, |ui| self.sidebar_ui(ui, &p));
        }

        egui::CentralPanel::default()
            .frame(egui::Frame::new().fill(p.bg))
            .show(ctx, |ui| self.editor_ui(ui, &p));

        if self.palette_open {
            self.palette_ui(ctx, &p);
        }
        if self.goto_open {
            self.goto_ui(ctx, &p);
        }
    }

    fn save(&mut self, _storage: &mut dyn eframe::Storage) {
        self.persist();
    }
}

impl App {
    fn handle_keys(&mut self, ctx: &egui::Context) {
        let cmd = ctx.input(|i| i.modifiers.command);
        let shift = ctx.input(|i| i.modifiers.shift);
        if ctx.input(|i| i.key_pressed(Key::Escape)) {
            self.find_open = false;
            self.palette_open = false;
            self.goto_open = false;
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::N)) {
            self.new_tab();
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::O)) && !shift {
            self.open_dialog();
        }
        if cmd && shift && ctx.input(|i| i.key_pressed(Key::O)) {
            self.open_folder();
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::S)) && !shift {
            self.save_current();
        }
        if cmd && shift && ctx.input(|i| i.key_pressed(Key::S)) {
            self.save_as();
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::W)) {
            self.close_tab(self.active);
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::F)) {
            self.find_open = true;
            self.focus_find = true;
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::H)) {
            self.find_open = true;
            self.replace_open = true;
            self.focus_find = true;
        }
        if cmd && shift && ctx.input(|i| i.key_pressed(Key::P)) {
            self.palette_open = true;
            self.focus_palette = true;
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::B)) {
            self.sidebar = !self.sidebar;
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::G)) {
            self.goto_open = true;
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::Slash)) {
            self.toggle_comment();
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::D)) {
            self.duplicate_line();
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::CloseBracket)) {
            self.indent(false);
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::OpenBracket)) {
            self.indent(true);
        }
        if cmd && (ctx.input(|i| i.key_pressed(Key::Equals)) || ctx.input(|i| i.key_pressed(Key::Plus))) {
            self.font = (self.font + 1.0).min(28.0);
        }
        if cmd && ctx.input(|i| i.key_pressed(Key::Minus)) {
            self.font = (self.font - 1.0).max(11.0);
        }
        if self.find_open && ctx.input(|i| i.key_pressed(Key::Enter)) && !self.palette_open {
            self.find_next(shift);
        }
    }

    fn chrome_bar(&mut self, ui: &mut Ui, p: &Palette) {
        ui.horizontal_centered(|ui| {
            ui.label(RichText::new("Mac").color(p.fg).size(16.0).strong());
            ui.label(RichText::new("Text").color(p.accent).size(16.0).strong());
            ui.add_space(10.0);
            ui.label(RichText::new(format!("v{APP_VERSION}")).color(p.line_number).size(11.0));
            ui.add_space(16.0);
            if ui.button(self.t("新建", "New")).clicked() { self.new_tab(); }
            if ui.button(self.t("打开", "Open")).clicked() { self.open_dialog(); }
            if ui.button(self.t("保存", "Save")).clicked() { self.save_current(); }
            if ui.button(self.t("查找", "Find")).clicked() { self.find_open = true; self.focus_find = true; }
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                let lang = if self.zh { "中文" } else { "EN" };
                if ui.selectable_label(false, lang).clicked() {
                    self.zh = !self.zh;
                }
                ui.label(RichText::new(self.theme.label()).color(p.accent2).size(12.0));
                ui.label(RichText::new("Windows").color(p.line_number).size(11.0));
            });
        });
    }

    fn status_bar(&mut self, ui: &mut Ui, p: &Palette) {
        let lang = self.tab().lang.label(self.zh);
        let lines = self.tab().text.lines().count().max(1);
        let chars = self.tab().text.chars().count();
        ui.horizontal_centered(|ui| {
            ui.label(RichText::new(lang).color(p.accent).size(12.0));
            ui.label(RichText::new("·").color(p.line_number));
            ui.label(RichText::new(if self.zh { format!("{lines} 行 · {chars} 字") } else { format!("{lines} lines · {chars} chars") }).color(p.fg).size(12.0));
            if !self.status.is_empty() {
                ui.label(RichText::new("·").color(p.line_number));
                ui.label(RichText::new(&self.status).color(p.accent2).size(12.0));
            }
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                ui.label(RichText::new("UTF-8").color(p.line_number).size(11.0));
                ui.label(RichText::new("·").color(p.line_number));
                ui.label(RichText::new("Ctrl+Shift+P").color(p.line_number).size(11.0));
            });
        });
    }

    fn sidebar_ui(&mut self, ui: &mut Ui, p: &Palette) {
        ui.label(RichText::new(self.t("文件夹", "Folder")).color(p.line_number).size(11.0));
        ui.add_space(4.0);
        if let Some(folder) = self.folder.clone() {
            ui.label(RichText::new(folder.file_name().and_then(|s| s.to_str()).unwrap_or("")).color(p.fg).strong());
            ui.add_space(8.0);
            egui::ScrollArea::vertical().show(ui, |ui| {
                let entries = list_dir(&folder);
                for (path, is_dir) in entries {
                    let name = path.file_name().and_then(|s| s.to_str()).unwrap_or("").to_string();
                    let label = if is_dir { format!("▸ {name}") } else { format!("  {name}") };
                    let color = if is_dir { p.accent2 } else { p.fg };
                    if ui.add(egui::Label::new(RichText::new(label).color(color).size(13.0)).sense(Sense::click())).clicked() && !is_dir {
                        self.open_files(vec![path]);
                    }
                }
            });
        } else {
            ui.label(RichText::new(self.t("尚未打开文件夹", "No folder open")).color(p.line_number).size(12.0));
            ui.add_space(8.0);
            if ui.button(self.t("打开文件夹", "Open Folder")).clicked() {
                self.open_folder();
            }
        }
    }

    fn editor_ui(&mut self, ui: &mut Ui, p: &Palette) {
        ui.horizontal(|ui| {
            ui.spacing_mut().item_spacing.x = 0.0;
            let mut close = None;
            for (i, tab) in self.tabs.iter().enumerate() {
                let on = i == self.active;
                let fill = if on { p.tab_active } else { p.tab_inactive };
                let fg = if on { p.fg } else { p.line_number };
                let bar = if on { p.accent } else { Color32::TRANSPARENT };
                let resp = ui.allocate_ui_with_layout(Vec2::new(148.0, 32.0), egui::Layout::left_to_right(egui::Align::Center), |ui| {
                    ui.painter().rect_filled(ui.max_rect(), 0.0, fill);
                    ui.painter().rect_filled(egui::Rect::from_min_size(ui.max_rect().min, Vec2::new(ui.max_rect().width(), 2.0)), 0.0, bar);
                    ui.add_space(10.0);
                    let name = tab.display();
                    let short = if name.chars().count() > 16 {
                        format!("{}…", name.chars().take(15).collect::<String>())
                    } else {
                        name
                    };
                    ui.label(RichText::new(short).color(fg).size(12.5));
                    if ui.add(egui::Label::new(RichText::new("×").color(p.line_number).size(13.0)).sense(Sense::click())).clicked() {
                        close = Some(i);
                    }
                });
                if resp.response.clicked() {
                    self.active = i;
                    self.focus_editor = true;
                }
            }
            if let Some(i) = close {
                self.close_tab(i);
            }
        });
        ui.painter().hline(ui.max_rect().x_range(), ui.cursor().top(), egui::Stroke::new(1.0_f32, p.divider));

        if self.find_open {
            let find_hint = self.t("查找", "Find");
            let next_l = self.t("下一个", "Next");
            let prev_l = self.t("上一个", "Prev");
            let repl_l = self.t("替换", "Replace");
            let repl_hint = self.t("替换为", "Replace");
            let all_l = self.t("全部替换", "Replace all");
            ui.horizontal(|ui| {
                ui.add_space(8.0);
                let find = TextEdit::singleline(&mut self.find)
                    .hint_text(find_hint)
                    .desired_width(220.0);
                let r = ui.add(find);
                if self.focus_find {
                    r.request_focus();
                    self.focus_find = false;
                }
                if ui.button(next_l).clicked() { self.find_next(false); }
                if ui.button(prev_l).clicked() { self.find_next(true); }
                if ui.button(repl_l).clicked() { self.replace_open = true; }
                if self.replace_open {
                    ui.add(TextEdit::singleline(&mut self.replace).hint_text(repl_hint).desired_width(180.0));
                    if ui.button(all_l).clicked() { self.replace_all(); }
                }
                if ui.button("Esc").clicked() { self.find_open = false; }
            });
            ui.add_space(4.0);
        }

        let font = egui::FontId::new(self.font, FontFamily::Monospace);
        let text = self.tab().text.clone();
        let gutter_w = 52.0;
        egui::ScrollArea::both().auto_shrink([false, false]).show(ui, |ui| {
            ui.horizontal_top(|ui| {
                let lines = text.lines().count().max(1);
                let gutter = (1..=lines).map(|i| format!("{i:>4}")).collect::<Vec<_>>().join("\n");
                ui.add(
                    egui::Label::new(RichText::new(gutter).font(egui::FontId::new(self.font, FontFamily::Monospace)).color(p.line_number))
                        .wrap_mode(egui::TextWrapMode::Extend),
                );
                ui.add_space(8.0);
                let _ = gutter_w;
                let mut editor = self.tab().text.clone();
                let resp = ui.add(
                    TextEdit::multiline(&mut editor)
                        .font(font.clone())
                        .desired_width(f32::INFINITY)
                        .desired_rows((lines + 8).min(80))
                        .frame(false)
                        .code_editor()
                        .lock_focus(true),
                );
                if self.focus_editor {
                    resp.request_focus();
                    self.focus_editor = false;
                }
                if resp.changed() {
                    self.tab_mut().text = editor;
                    self.tab_mut().dirty = true;
                    if self.tab().lang == LangKind::Plain && self.tab().path.is_none() {
                        self.tab_mut().lang = infer_lang(&self.tab().text);
                    }
                }
            });
        });
    }

    fn palette_ui(&mut self, ctx: &egui::Context, p: &Palette) {
        let mut open = self.palette_open;
        egui::Window::new(self.t("命令面板", "Command Palette"))
            .collapsible(false)
            .resizable(false)
            .anchor(egui::Align2::CENTER_TOP, [0.0, 72.0])
            .open(&mut open)
            .show(ctx, |ui| {
                ui.set_min_width(420.0);
                let hint = self.t("输入命令", "Type a command");
                let edit = ui.add(TextEdit::singleline(&mut self.palette_query).hint_text(hint).desired_width(400.0));
                if self.focus_palette {
                    edit.request_focus();
                    self.focus_palette = false;
                }
                ui.add_space(6.0);
                let q = self.palette_query.to_lowercase();
                let cmds = commands(self.zh);
                for (id, label) in cmds {
                    if !q.is_empty() && !label.to_lowercase().contains(&q) && !id.contains(&q) {
                        continue;
                    }
                    if ui.add(egui::Button::new(RichText::new(label).color(p.fg)).fill(p.find).min_size(Vec2::new(400.0, 28.0))).clicked() {
                        self.run_palette(id);
                    }
                }
            });
        self.palette_open = open;
    }

    fn goto_ui(&mut self, ctx: &egui::Context, _p: &Palette) {
        let mut open = self.goto_open;
        egui::Window::new(self.t("跳转到行", "Go to Line"))
            .collapsible(false)
            .resizable(false)
            .anchor(egui::Align2::CENTER_TOP, [0.0, 88.0])
            .open(&mut open)
            .show(ctx, |ui| {
                ui.add(TextEdit::singleline(&mut self.goto_line).hint_text("1").desired_width(160.0));
                if ui.button(self.t("跳转", "Go")).clicked() || ui.input(|i| i.key_pressed(Key::Enter)) {
                    self.goto();
                }
            });
        self.goto_open = open;
    }
}

fn commands(zh: bool) -> Vec<(&'static str, String)> {
    let t = |zh_s: &str, en: &str| if zh { zh_s.to_string() } else { en.to_string() };
    vec![
        ("new", t("新建", "New")),
        ("open", t("打开文件", "Open File")),
        ("folder", t("打开文件夹", "Open Folder")),
        ("save", t("保存", "Save")),
        ("saveas", t("另存为", "Save As")),
        ("find", t("查找", "Find")),
        ("replace", t("查找并替换", "Find and Replace")),
        ("goto", t("跳转到行", "Go to Line")),
        ("sidebar", t("显示 / 隐藏侧边栏", "Toggle Sidebar")),
        ("comment", t("注释 / 取消注释", "Toggle Comment")),
        ("bigger", t("增大字体", "Bigger Font")),
        ("smaller", t("减小字体", "Smaller Font")),
        ("ink", "Ink".to_string()),
        ("black", "Black".to_string()),
        ("paper", "Paper".to_string()),
        ("snow", "Snow".to_string()),
        ("zh", "中文".to_string()),
        ("en", "English".to_string()),
    ]
}

fn install_fonts(ctx: &egui::Context) {
    let mut fonts = FontDefinitions::default();
    let pairs = [
        (r"C:\Windows\Fonts\msyh.ttc", "yahei"),
        (r"C:\Windows\Fonts\msyh.ttf", "yahei"),
        (r"C:\Windows\Fonts\consola.ttf", "consolas"),
        (r"C:\Windows\Fonts\CascadiaMono.ttf", "cascadia"),
    ];
    for (path, name) in pairs {
        if let Ok(bytes) = fs::read(path) {
            fonts.font_data.insert(name.to_owned(), Arc::new(FontData::from_owned(bytes)));
        }
    }
    if fonts.font_data.contains_key("yahei") {
        fonts.families.entry(FontFamily::Proportional).or_default().insert(0, "yahei".to_owned());
        fonts.families.entry(FontFamily::Monospace).or_default().push("yahei".to_owned());
    }
    if fonts.font_data.contains_key("consolas") {
        fonts.families.entry(FontFamily::Monospace).or_default().insert(0, "consolas".to_owned());
    } else if fonts.font_data.contains_key("cascadia") {
        fonts.families.entry(FontFamily::Monospace).or_default().insert(0, "cascadia".to_owned());
    }
    ctx.set_fonts(fonts);
}

fn list_dir(dir: &Path) -> Vec<(PathBuf, bool)> {
    let mut items = Vec::new();
    if let Ok(rd) = fs::read_dir(dir) {
        for entry in rd.flatten() {
            let path = entry.path();
            let name = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
            if name.starts_with('.') {
                continue;
            }
            let is_dir = path.is_dir();
            items.push((path, is_dir));
        }
    }
    items.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.file_name().cmp(&b.0.file_name())));
    items.truncate(400);
    items
}

fn infer_lang(text: &str) -> LangKind {
    let sample = text.chars().take(2000).collect::<String>();
    if sample.contains("func ") || sample.contains("import Foundation") {
        LangKind::Swift
    } else if sample.contains("def ") || sample.contains("print(") {
        LangKind::Python
    } else if sample.contains("interface ") || sample.contains(": string") {
        LangKind::TypeScript
    } else if sample.contains("function ") || sample.contains("const ") || sample.contains("=>") {
        LangKind::JavaScript
    } else if sample.trim_start().starts_with('{') || sample.trim_start().starts_with('[') {
        LangKind::Json
    } else if sample.contains("# ") || sample.contains("```") {
        LangKind::Markdown
    } else {
        LangKind::Plain
    }
}

fn replace_ignore_case(text: &str, find: &str, replace: &str) -> String {
    let lower = text.to_lowercase();
    let needle = find.to_lowercase();
    if needle.is_empty() {
        return text.to_string();
    }
    let mut out = String::new();
    let mut i = 0;
    while let Some(rel) = lower[i..].find(&needle) {
        let at = i + rel;
        out.push_str(&text[i..at]);
        out.push_str(replace);
        i = at + needle.len();
    }
    out.push_str(&text[i..]);
    out
}
