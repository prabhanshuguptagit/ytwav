import SwiftUI
import AppKit

@main
struct YtWavApp: App {
    @StateObject private var model = Model()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(model)
        } label: {
            Image(nsImage: .ytIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PanelView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("YouTube URL", text: $model.url)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.download() }
                .disabled(model.busy)

            HStack(spacing: 6) {
                Text("Save to:")
                    .foregroundStyle(.secondary)
                Button {
                    model.chooseFolder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(model.displayPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Choose download folder")
                Spacer()
                Text("⇧⌘Y")
                    .foregroundStyle(.tertiary)
                    .help("⇧⌘Y opens this panel from anywhere")
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            if model.busy {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if let progress = model.progress {
                            ProgressView(value: progress, total: 100)
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                        }
                        Button("Cancel") { model.cancel() }
                            .controlSize(.small)
                    }
                    Text(model.phaseLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else {
                Button {
                    model.download()
                } label: {
                    Label("Download WAV", systemImage: "arrow.down.to.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.85, green: 0.1, blue: 0.1))
                .controlSize(.large)
                .disabled(model.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !model.status.isEmpty {
                Label(model.status, systemImage: model.failed ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(model.failed ? Color.red : Color.green)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            // Drag this into Finder, Ableton, UVR, etc.
            if let file = model.lastFile, !model.busy {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "waveform")
                    Text(file.lastPathComponent)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([file])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Show in Finder")
                }
                .font(.caption)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .onDrag {
                    NSItemProvider(contentsOf: file) ?? NSItemProvider()
                }
                .help("Drag into Finder, Ableton, UVR…")
            }

            if !model.log.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(model.log)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(height: 140)
                    .background(Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: model.log) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 360)
    }
}

final class Model: ObservableObject {
    @Published var url = ""
    @Published var status = ""
    @Published var log = ""
    @Published var busy = false
    @Published var failed = false
    @Published var progress: Double?   // 0-100 while downloading, nil when unknown
    @Published var converting = false
    @Published var lastFile: URL?

    private var proc: Process?
    private var cancelled = false
    private let hotKey = GlobalHotKey() // ⇧⌘Y opens the panel from anywhere

    /// Full path with home shown as ~, e.g. "~/music/samples".
    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = outDir.path
        return path.hasPrefix(home)
            ? "~" + path.dropFirst(home.count)
            : path
    }

    var phaseLabel: String {
        if converting { return "Converting to WAV…" }
        if let p = progress { return "Downloading… \(Int(p))%" }
        return "Starting…"
    }

    @Published var outDir: URL {
        didSet { UserDefaults.standard.set(outDir.path, forKey: "outDir") }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "outDir"),
           FileManager.default.fileExists(atPath: saved) {
            outDir = URL(fileURLWithPath: saved)
        } else {
            outDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads")
        }
        hotKey.onPress = { Self.togglePanel() }
    }

    /// Open/close the MenuBarExtra panel by clicking its status item.
    /// (No public API for this yet — the status item lives on a private
    /// NSStatusBarWindow, reached via KVC. Standard workaround.)
    static func togglePanel() {
        for window in NSApp.windows
        where String(describing: type(of: window)).contains("NSStatusBarWindow") {
            guard let item = window.value(forKey: "statusItem") as? NSStatusItem else { continue }
            NSApp.activate(ignoringOtherApps: true)
            item.button?.performClick(nil)
            return
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = outDir
        panel.prompt = "Save Here"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            outDir = url
        }
    }

    func cancel() {
        cancelled = true
        proc?.terminate()
    }

    func download() {
        let link = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty, !busy else { return }
        guard let bin = Self.findYtDlp() else {
            failed = true
            status = "yt-dlp not found. See README: put yt-dlp_macos in ~/.local/bin."
            return
        }
        busy = true
        failed = false
        cancelled = false
        progress = nil
        converting = false
        status = ""
        log = "$ \(bin) \(link)\n"

        // yt-dlp writes the final wav path here (keeps logs and the path separate).
        let pathFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ytwav-\(UUID().uuidString).txt")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let p = Process()
            self.proc = p
            p.executableURL = URL(fileURLWithPath: bin)
            p.arguments = [
                "-x", "--audio-format", "wav",
                "--no-playlist",
                "--newline",
                "-P", self.outDir.path,
                "-o", "%(title)s.%(ext)s",
                "--print-to-file", "after_move:filepath", pathFile.path,
                link,
            ]
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err

            // Stream both stdout and stderr into the log view as lines arrive.
            let append: (FileHandle) -> Void = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async { self?.appendLog(text) }
            }
            out.fileHandleForReading.readabilityHandler = append
            err.fileHandleForReading.readabilityHandler = append

            do {
                try p.run()
                p.waitUntilExit()
            } catch {
                self.finish(error: "Failed to launch yt-dlp: \(error.localizedDescription)")
                return
            }

            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            self.proc = nil

            let path = (try? String(contentsOf: pathFile, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            try? FileManager.default.removeItem(at: pathFile)

            if self.cancelled {
                self.finish(error: "Cancelled.")
                return
            }
            guard p.terminationStatus == 0,
                  let path, FileManager.default.fileExists(atPath: path)
            else {
                self.finish(error: "Failed — see log.")
                return
            }

            DispatchQueue.main.async {
                let fileURL = URL(fileURLWithPath: path)
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([fileURL as NSURL])
                self.busy = false
                self.lastFile = fileURL
                self.status = "Saved \(fileURL.lastPathComponent) — copied to clipboard"
                self.url = ""
            }
        }
    }

    private func appendLog(_ text: String) {
        log += text
        // Keep the log from growing unbounded.
        if log.count > 20_000 {
            log = String(log.suffix(10_000))
        }
        // Parse progress: "[download]  42.3% of ..."
        for line in text.split(separator: "\n") {
            if line.hasPrefix("[ExtractAudio]") {
                converting = true
                progress = nil
            } else if let range = line.range(of: #"\[download\]\s+([\d.]+)%"#, options: .regularExpression) {
                let pct = line[range].split(separator: " ").last?.dropLast()
                if let pct, let value = Double(pct) {
                    converting = false
                    progress = value
                }
            }
        }
    }

    private func finish(error message: String) {
        DispatchQueue.main.async {
            self.busy = false
            self.failed = true
            self.status = message
        }
    }

    static func findYtDlp() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/yt-dlp_macos",
            "/usr/local/bin/yt-dlp_macos",
            "/opt/homebrew/bin/yt-dlp_macos",
            "\(home)/bin/yt-dlp_macos",
            "\(home)/Downloads/yt-dlp_macos",
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

extension NSImage {
    /// YouTube-style icon: rounded rectangle with a play-triangle cutout.
    /// Template image, so it adapts to menu bar light/dark appearance.
    static let ytIcon: NSImage = {
        let size = NSSize(width: 18, height: 13)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: 3.5, yRadius: 3.5)
            let tri = NSBezierPath()
            tri.move(to: NSPoint(x: 7.2, y: 3.6))
            tri.line(to: NSPoint(x: 12.4, y: 6.5))
            tri.line(to: NSPoint(x: 7.2, y: 9.4))
            tri.close()
            path.append(tri)
            path.windingRule = .evenOdd
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
