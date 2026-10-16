import AppKit
import SwiftUI

struct MatrizSettingsPanel: View {
    @ObservedObject private var preferences = MatrizPreferences.shared
    @ObservedObject private var live = MatrizLiveState.shared
    @State private var confirmReset = false
    var done: (() -> Void)?

    private func binding<T>(_ key: WritableKeyPath<MatrizSettings, T>) -> Binding<T> {
        Binding(get: { preferences.settings[keyPath: key] }, set: { value in
            var settings = preferences.settings
            settings[keyPath: key] = value
            preferences.update(settings)
        })
    }
    private func caption(_ key: String) -> some View {
        Text(L(key)).font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func label(_ key: String, _ icon: String) -> some View {
        Label(L(key), systemImage: icon).font(.body.weight(.medium))
    }
    private func percent(_ key: KeyPath<MatrizSettings, Double>) -> String {
        preferences.settings[keyPath: key].formatted(.percent.precision(.fractionLength(0)))
    }
    private func slider(_ title: String, _ icon: String, _ key: WritableKeyPath<MatrizSettings, Double>,
                        _ range: ClosedRange<Double>, value: String? = nil, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                label(title, icon)
                Spacer(minLength: 12)
                Text(value ?? percent(key)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: binding(key), in: range).labelsHidden()
                .accessibilityLabel(L(title)).accessibilityValue(value ?? percent(key)).accessibilityHint(L(detail))
            if key == \.hue {
                Capsule().fill(LinearGradient(colors: (0...12).map { Color(hue: Double($0) / 12, saturation: 1, brightness: 1) },
                    startPoint: .leading, endPoint: .trailing)).frame(height: 3).padding(.horizontal, 8).accessibilityHidden(true)
            }
            caption(detail)
        }.padding(.vertical, 4)
    }
    private func group<Content: View>(_ title: String, _ icon: String, _ detail: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        Section {
            content()
        } header: {
            Label(L(title), systemImage: icon)
        } footer: {
            caption(detail)
        }
    }
    private func toggle(_ title: String, _ icon: String, _ key: WritableKeyPath<MatrizSettings, Bool>, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: binding(key)) { label(title, icon) }
            caption(detail)
        }.padding(.vertical, 4)
    }
    private func color(_ key: WritableKeyPath<MatrizSettings, SIMD3<Double>>) -> Binding<Color> {
        Binding(get: {
            let c = preferences.settings[keyPath: key]
            return Color(.sRGB, red: c.x, green: c.y, blue: c.z)
        }, set: { color in
            guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
            var settings = preferences.settings
            settings[keyPath: key] = SIMD3(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
            preferences.update(settings)
        })
    }
    private var appearance: some View {
        group("Composition", "rectangle.3.group", "Every composition keeps soft, moving edges.") {
            VStack(alignment: .leading, spacing: 7) {
                Picker(selection: binding(\.backgroundStyle)) {
                    Label(L("Full screen"), systemImage: "rectangle.fill").tag(0)
                    Label(L("Lower wave"), systemImage: "rectangle.bottomhalf.filled").tag(1)
                    Label(L("Upper wave"), systemImage: "rectangle.tophalf.filled").tag(2)
                    Label(L("Central wave"), systemImage: "water.waves").tag(3)
                    Label(L("Orb"), systemImage: "circle.fill").tag(4)
                    Label(L("Inverted orb"), systemImage: "circle").tag(5)
                } label: { label("Composition", "rectangle.3.group") }
            }
            if preferences.settings.backgroundStyle >= 1 && preferences.settings.backgroundStyle <= 3 {
                slider("Wave position", "arrow.up.and.down", \.wavePosition, -0.35...0.35,
                       detail: "Move the wave boundary up or down in the lower, upper and central compositions.")
            }
            if preferences.settings.backgroundStyle >= 4 {
                slider("Orb size", "arrow.up.left.and.arrow.down.right", \.orbSize, 0.2...6,
                       detail: "Enlarge the orb or its central opening, even beyond the screen.")
                slider("Orb center X", "arrow.left.and.right", \.orbX, -0.5...0.5,
                       detail: "Move the orb away from the center of the screen.")
                slider("Orb center Y", "arrow.up.and.down", \.orbY, -0.5...0.5,
                       detail: "Move the orb away from the center of the screen.")
            }
        }
    }
    private var colors: some View {
        group("Colors", "paintpalette", "Choose the colors, composition and texture of your background.") {
            VStack(alignment: .leading, spacing: 7) {
                Picker(selection: binding(\.palette)) {
                    Label(L("Deep blue"), systemImage: "drop.fill").tag(0)
                    Label(L("Violet night"), systemImage: "moon.stars.fill").tag(1)
                    Label(L("Lagoon"), systemImage: "water.waves").tag(2)
                    Label(L("Aurora"), systemImage: "leaf.fill").tag(3)
                    Label(L("Sunset"), systemImage: "sunset.fill").tag(4)
                    Label(L("Rose"), systemImage: "heart.fill").tag(5)
                    Label(L("Amber"), systemImage: "flame.fill").tag(6)
                    Label(L("Graphite"), systemImage: "circle.lefthalf.filled").tag(7)
                    Label(L("Custom"), systemImage: "slider.horizontal.3").tag(8)
                } label: { label(preferences.settings.artworkEnabled ? "Fallback palette" : "Palette", "paintpalette") }
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    let colors = activePalette(at: ProcessInfo.processInfo.systemUptime)
                    Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .frame(height: 3).accessibilityLabel(L("Active palette"))
                }
                caption("Used when album colors are off or no artwork is available.")
            }
            if preferences.settings.palette == 8 {
                ColorPicker(selection: color(\.customLight), supportsOpacity: false) { label("Primary color", "1.circle") }
                ColorPicker(selection: color(\.customDeep), supportsOpacity: false) { label("Second color", "2.circle") }
                ColorPicker(selection: color(\.customSoft), supportsOpacity: false) { label("Third color", "3.circle") }
                ColorPicker(selection: color(\.customAccent), supportsOpacity: false) { label("Accent color", "4.circle") }
                caption("These four colors blend through the waves.")
            }
            slider("Color variety", "swatchpalette", \.paletteRichness, 0...1, detail: "Blend one main tone or the full palette.")
            slider("Color noise blur", "camera.filters", \.colorBlur, 0...1,
                   detail: "Soften noise and blend colors along the waves.")
            slider("Hue", "dial.medium", \.hue, 0...360, value: preferences.settings.hue.formatted(.number.precision(.fractionLength(0))) + "°",
                   detail: "Shift your palette without changing the original album colors.")
            slider("Brightness", "sun.max", \.brightness, 0...2, detail: "Lighten or darken the whole background.")
            slider("Saturation", "drop.halffull", \.saturation, 0...2, detail: "Move from grayscale to vivid color, including album palettes.")
            slider("Color contrast", "circle.lefthalf.filled", \.colorContrast, 0.5...2, detail: "Make the final highlights and shadows more distinct.")
        }
    }
    private var particles: some View {
        group("Particles", "sparkles", "Choose the shapes that form the texture.") {
            VStack(alignment: .leading, spacing: 7) {
                Picker(selection: binding(\.sparkleShape)) {
                    Label(L("Sparkles"), systemImage: "sparkle").tag(0)
                    Label(L("Circles"), systemImage: "circle.fill").tag(1)
                    Label(L("Squares"), systemImage: "square.fill").tag(2)
                } label: { label("Particle shape", "square.on.circle") }
            }
            slider("Spacing", "square.grid.3x3", \.spacing, 6...16,
                   value: preferences.settings.spacing.formatted(.number.precision(.fractionLength(1))) + " px", detail: "Smaller gaps create more particles.")
            slider("Particle size", "arrow.up.left.and.arrow.down.right", \.size, 0.6...1.4, detail: "Set the base size of each particle.")
            slider("Wave opacity", "water.waves", \.waveOpacity, 0...1, detail: "Fade the colored waves independently of the particles.")
            slider("Particle opacity", "sparkles", \.sparkleOpacity, 0...1, detail: "Fade the texture independently of the waves.")
        }
    }
    private var motion: some View {
        group("Motion", "water.waves", "Give the waves a calm or more lively rhythm.") {
            slider("Pace", "speedometer", \.speed, 0.25...2,
                   value: preferences.settings.speed.formatted(.number.precision(.fractionLength(2))) + "×", detail: "Slow drifting or a faster flow.")
            slider("Wave size", "arrow.up.left.and.arrow.down.right", \.volumeScale, 0.6...1.8,
                   detail: "Enlarge or shrink the moving volumes of color.")
            slider("Particle drift", "waveform.path", \.deformation, 0...4,
                   detail: "Move particles with the waves. Above 100% uses more graphics power.")
        }
    }
    private var behavior: some View {
        group("Behavior", "slider.horizontal.3", "Decide how depth changes the particles.") {
            slider("Shadow light", "sun.min", \.shadowLight, 0...0.8,
                   detail: "Lift dark areas without changing the palette.")
            slider("Depth", "square.3.layers.3d", \.contrast, 0.5...1.5, detail: "Emphasize the shared relief of waves and particles.")
            slider("Size follows depth", "arrow.up.and.down", \.waveSizeInfluence, 0...3,
                   detail: "At zero, size stays constant. Increase it for larger particles in bright areas.")
            if preferences.settings.sparkleShape == 0 {
                slider("Base concavity", "sparkle", \.concavity, 0...0.85,
                       value: (preferences.settings.concavity / 0.85).formatted(.percent.precision(.fractionLength(0))),
                       detail: "From diamonds to stars with deeper curves.")
                slider("Shape follows size", "square.on.circle", \.depthConcavity, 0...1,
                       detail: "Smaller particles have deeper curves.")
            }
            caption("Matriz pauses with your Mac and respects Reduce Motion. The interface follows your preferred system language.")
        }
    }
    private var music: some View {
        group("Music", "waveform", "Let music shape the light and bring in album colors.") {
            if live.desktopAvailable {
                toggle("React to Mac audio", "waveform", \.audioEnabled, detail: "Analyze system sound locally, without using the microphone.")
                    .disabled(!MatrizLiveState.audioSupported)
                if !MatrizLiveState.audioSupported { caption("Requires macOS 14.2 or later.") }
                if preferences.settings.audioEnabled {
                    Text(live.audioStatus).font(.callout).foregroundStyle(.secondary).accessibilityLabel(L("Audio status") + ": " + live.audioStatus)
                    Button { live.requestAudio?() } label: { label("Activate or retry audio", "play.circle") }.disabled(live.audioBusy)
                    slider("Sensitivity", "ear", \.audioSensitivity, -12...18,
                           value: preferences.settings.audioSensitivity.formatted(.number.precision(.fractionLength(0))) + " dB",
                           detail: "Make quiet music more responsive without changing its volume.")
                    slider("Intensity", "waveform.path", \.audioIntensity, 0...1, detail: "Bass expands waves and orbs; treble adds contour and particle detail.")
                    slider("Smoothing", "water.waves", \.audioResponse, 0...1, detail: "Let each sound fade more gradually.")
                }
                caption("Audio is never recorded or sent anywhere. Analysis stops while paused, asleep, locked or using Reduce Motion.")
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Label(L("Album artwork"), systemImage: "photo").font(.headline)
                    caption("Automatically follows Music or Spotify while playing.")
                }.padding(.vertical, 4)
                toggle("Use album colors", "photo", \.artworkEnabled, detail: "Replace the palette with colors taken from the current artwork.")
                if preferences.settings.artworkEnabled {
                    Text(live.artworkStatus).font(.callout).foregroundStyle(.secondary).accessibilityLabel(L("Artwork status") + ": " + live.artworkStatus)
                    Button { live.requestArtwork?() } label: { label("Authorize open players", "link") }.disabled(live.artworkBusy)
                    caption("Players stay closed until you open them. This button may request Automation permission. Spotify artwork downloads over HTTPS.")
                    VStack(alignment: .leading, spacing: 7) {
                        Stepper(value: binding(\.artworkColors), in: 1...4) {
                            HStack { label("Artwork colors", "square.stack.3d.up"); Spacer(); Text(preferences.settings.artworkColors.formatted()).monospacedDigit().foregroundStyle(.secondary) }
                        }.accessibilityLabel(L("Artwork colors"))
                        caption("Extract between one and four dominant colors.")
                    }
                    slider("Artwork saturation", "paintpalette", \.artworkIntensity, 0...2,
                           detail: "100% preserves the extracted colors; zero makes them grayscale.")
                    slider("Color transition", "timer", \.artworkTransition, 1...8,
                           value: preferences.settings.artworkTransition.formatted(.number.precision(.fractionLength(1))) + " s",
                           detail: "Time to blend into a new album or return to your palette.")
                }
            } else { caption("Music features are available in the desktop app.") }
        }
    }
    @ViewBuilder private var agents: some View {
        group("AI agents", "terminal", "Local events change the palette without reading your chats.") {
            if live.desktopAvailable {
                toggle("Use agent colors", "cpu", \.agentEnabled, detail: "Agent colors take priority over album colors.")
                Picker(selection: binding(\.agentSource)) {
                    Text(L("All agents")).tag("all")
                    ForEach(MatrizAgentBridge.agents, id: \.self) { agent in Text(MatrizAgentBridge.name(agent)).tag(agent) }
                } label: { label("Source", "point.3.connected.trianglepath.dotted") }
                if let event = live.agent {
                    LabeledContent(L("Latest state"), value: MatrizAgentBridge.name(event.agent) + " · " + event.state.title)
                } else { caption("Waiting for agent events.") }
                HStack {
                    Button {
                        do { NSWorkspace.shared.activateFileViewerSelecting([try MatrizAgentBridge.exportIntegrations()]) }
                        catch { NSAlert(error: error).runModal() }
                    } label: { label("Open setup files", "folder") }
                    Button {
                        guard let executable = MatrizI18n.bundle.executableURL else { return }
                        let command = "'" + executable.path.replacingOccurrences(of: "'", with: "'\\''") + "' --agent-event generic running main"
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                    } label: { label("Copy event command", "doc.on.doc") }
                }
                caption("Connect each agent using the supplied hooks or API adapter.")
            } else { caption("Agent colors are available in the desktop app.") }
        }
        group("State colors", "paintpalette", "Priority: permission, input, error, running, completed, idle.") {
            ForEach(MatrizAgentState.allCases, id: \.self) { state in
                let c = state.color
                HStack {
                    Circle().fill(Color(.sRGB, red: Double(c.x), green: Double(c.y), blue: Double(c.z))).frame(width: 10, height: 10).accessibilityHidden(true)
                    Text(state.title)
                }
            }
        }
    }
    private var lockScreen: some View {
        group("Lock Screen", "lock", "Keep your Mac protected while the screensaver is running.") {
            caption("Wallpaper extension: desktop and lock screen.")
            caption("Private API: macOS updates may affect it.")
            caption("macOS manages the password screen and sign-in separately from the animated screensaver.")
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app")) } label: {
                label("Open System Settings", "gearshape")
            }
        }
    }
    private var screenSaver: some View {
        group("Screen Saver", "display", "Use the same visual style when your Mac is idle.") {
            caption("Choose Matriz in Wallpaper settings.")
            caption("Music and artwork are available only in the desktop app; the screensaver keeps your chosen palette.")
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane")) } label: {
                label("Open Wallpaper settings", "display")
            }
        }
    }
    private var performance: some View {
        group("Performance", "battery.100percent", "Balance smoothness, sharpness and energy use.") {
            Picker(selection: binding(\.quality)) {
                Label(L("Save energy"), systemImage: "leaf.fill").tag(0)
                Label(L("Balanced"), systemImage: "circle.lefthalf.filled").tag(1)
                Label(L("Maximum sharpness"), systemImage: "sparkles").tag(2)
            } label: { label("Graphics quality", "battery.100percent") }
            caption("Energy saving runs at 30 FPS. The other modes run at 60 FPS with different resolutions.")
            caption("Low Power Mode automatically saves energy. Reduce Motion keeps the background still.")
        }
    }
    private var about: some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                if let url = MatrizI18n.bundle.url(forResource: "Author", withExtension: "jpg"), let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(Circle()).accessibilityHidden(true)
                } else { Image(systemName: "person.crop.circle.fill").font(.system(size: 48)).foregroundStyle(.secondary).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Jesús Jódar Piernas").font(.headline)
                    Text("@jesusjodar").font(.callout).foregroundStyle(.secondary)
                    caption("3D artist, developer and technology enthusiast.")
                    Link(destination: URL(string: "https://github.com/jesusjodar")!) { label("GitHub profile", "person.crop.circle") }
                        .buttonStyle(.bordered).padding(.top, 5)
                }
            }.padding(.vertical, 8)
            HStack(spacing: 10) {
                Link(destination: URL(string: "https://jesusjodar.github.io")!) { label("Portfolio", "safari") }
                Link(destination: URL(string: "https://linkedin.com/in/jesujopi/")!) { Label("LinkedIn", systemImage: "person.2") }
                Link(destination: URL(string: "https://x.com/jesujopi3D")!) { Label("X", systemImage: "bubble.left.and.bubble.right") }
                Link(destination: URL(string: "mailto:jesusjodarpiernas@gmail.com")!) { label("Email", "envelope") }
            }.buttonStyle(.bordered)
            Link(destination: URL(string: "https://github.com/jesusjodar/Matriz")!) { label("Source code on GitHub", "curlybraces") }.buttonStyle(.bordered)
            VStack(spacing: 8) {
                Text("Matriz · " + (MatrizI18n.bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""))
                    .font(.caption).foregroundStyle(.secondary)
                Text(L("Made with ❤️ in Spain 🇪🇸")).font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.vertical, 12)
        } header: { Label(L("About"), systemImage: "info.circle").font(.headline).textCase(nil) }
    }
    private func activePalette(at now: Double) -> [Color] {
        var palette = MatrizUniforms(settings: preferences.settings)
        if live.desktopAvailable {
            palette.replacePalette(live.artwork(at: now))
            palette.replacePalette(live.agentPalette(at: now))
        }
        return [palette.color0, palette.color1, palette.color2, palette.color3].map {
            Color(.sRGBLinear, red: Double($0.x), green: Double($0.y), blue: Double($0.z))
        }
    }
    private func settingsForm<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Form { content() }.formStyle(.grouped).scrollContentBackground(.hidden).background(Color.black)
    }
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                settingsForm { appearance; colors }
                    .tabItem { Label(L("Appearance"), systemImage: "paintpalette") }
                settingsForm { particles; behavior }
                    .tabItem { Label(L("Particles"), systemImage: "sparkles") }
                settingsForm { motion }
                    .tabItem { Label(L("Motion"), systemImage: "water.waves") }
                settingsForm { music }
                    .tabItem { Label(L("Music"), systemImage: "waveform") }
                settingsForm { agents }
                    .tabItem { Label(L("AI agents"), systemImage: "terminal") }
                settingsForm { performance; screenSaver; lockScreen; about }
                    .tabItem { Label(L("General"), systemImage: "gearshape") }
            }.tabViewStyle(.automatic)
            Divider()
            HStack {
                Button { confirmReset = true } label: { label("Reset…", "arrow.counterclockwise") }
                Spacer()
                if let done { Button(action: done) { label("Done", "checkmark") }.keyboardShortcut(.defaultAction) }
            }.padding(.horizontal, 20).padding(.vertical, 12)
        }.background(Color.black).preferredColorScheme(.dark)
            .frame(minWidth: 680, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
            .environment(\.layoutDirection, MatrizI18n.isRightToLeft ? .rightToLeft : .leftToRight)
            .alert(L("Reset all settings?"), isPresented: $confirmReset) {
                Button(L("Cancel"), role: .cancel) {}
                Button(L("Reset"), role: .destructive) { preferences.update(MatrizSettings()) }
            } message: { Text(L("This restores the original appearance, motion and music settings.")) }
    }
}
