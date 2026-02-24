//
//  SharedComponents.swift
//  Spheres - Smart Life Manager
//
//  Theme, button styles, icon library, and shared helpers.
//

import SwiftUI

// MARK: - Theme
struct SpheresTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let surface = Color.white.opacity(0.05)
    static let surfaceHover = Color.white.opacity(0.08)
    static let surfaceElevated = Color.white.opacity(0.07)
    static let border = Color.white.opacity(0.1)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.4)
    static let textMuted = Color.white.opacity(0.25)
    static let accent = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let accentGlow = Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.3)
}

// MARK: - Icon Library with Styles
struct IconLibrary {
    enum IconStyle: String, CaseIterable {
        case filled = "Filled"
        case outline = "Outline"
        case bold = "Bold"
        case whimsical = "Whimsical"
        case minimal = "Minimal"

        var description: String {
            switch self {
            case .filled: return "Classic filled icons"
            case .outline: return "Light outlined icons"
            case .bold: return "Heavy, bold icons"
            case .whimsical: return "Playful, fun icons"
            case .minimal: return "Simple, clean icons"
            }
        }
    }

    static let baseIcons: [(String, [String])] = [
        ("Life", ["heart", "star", "sparkles", "leaf", "sun.max", "moon", "cloud", "bolt"]),
        ("People", ["person", "person.2", "figure.2.and.child.holdinghands", "figure.walk", "figure.run", "hand.raised", "brain.head.profile", "face.smiling"]),
        ("Work", ["briefcase", "doc", "folder", "tray", "envelope", "phone", "desktopcomputer", "laptopcomputer"]),
        ("Learning", ["book", "graduationcap", "lightbulb", "pencil", "bookmark", "newspaper", "text.book.closed", "menucard"]),
        ("Health", ["heart.circle", "cross", "pills", "bandage", "stethoscope", "lungs", "figure.mind.and.body", "bed.double"]),
        ("Creative", ["paintbrush", "pencil.tip", "camera", "music.note", "guitars", "theatermasks", "film", "photo"]),
        ("Finance", ["dollarsign.circle", "creditcard", "banknote", "chart.line.uptrend.xyaxis", "building.columns", "house", "car", "airplane"]),
        ("Spiritual", ["hands.sparkles", "book.closed", "flame", "water.waves", "globe.americas", "peacesign", "infinity", "waveform.path"]),
    ]

    static let whimsicalIcons: [(String, [String])] = [
        ("Life", ["heart.fill", "star.circle.fill", "sparkles", "leaf.arrow.triangle.circlepath", "sun.max.trianglebadge.exclamationmark", "moon.stars.fill", "cloud.sun.fill", "bolt.heart.fill"]),
        ("People", ["person.crop.circle.fill", "person.2.circle.fill", "figure.2.and.child.holdinghands", "figure.dance", "figure.wave", "hand.wave.fill", "brain", "face.smiling.inverse"]),
        ("Work", ["bag.fill", "doc.richtext.fill", "folder.badge.gearshape", "tray.2.fill", "envelope.open.fill", "phone.bubble.fill", "display", "laptopcomputer.and.iphone"]),
        ("Learning", ["books.vertical.fill", "graduationcap.fill", "lightbulb.max.fill", "pencil.and.scribble", "bookmark.square.fill", "newspaper.circle.fill", "character.book.closed.fill", "list.bullet.clipboard.fill"]),
        ("Health", ["heart.text.square.fill", "cross.circle.fill", "pills.circle.fill", "bandage.fill", "staroflife.fill", "lungs.fill", "figure.yoga", "bed.double.circle.fill"]),
        ("Creative", ["paintpalette.fill", "pencil.tip.crop.circle.badge.plus", "camera.aperture", "music.quarternote.3", "pianokeys.inverse", "theatermask.and.paintbrush.fill", "film.stack.fill", "photo.stack.fill"]),
        ("Finance", ["dollarsign.arrow.circlepath", "creditcard.trianglebadge.exclamationmark", "banknote.fill", "chart.line.uptrend.xyaxis.circle.fill", "building.columns.circle.fill", "house.lodge.fill", "car.front.waves.up.fill", "airplane.departure"]),
        ("Spiritual", ["hands.and.sparkles.fill", "text.book.closed.fill", "flame.circle.fill", "drop.triangle.fill", "globe.central.south.asia.fill", "peacesign", "infinity.circle.fill", "waveform.circle.fill"]),
    ]

    static func icons(for style: IconStyle) -> [(String, [String])] {
        switch style {
        case .filled:
            return baseIcons.map { ($0.0, $0.1.map { iconName in
                if iconName.contains(".") && !iconName.hasSuffix(".fill") && !["desktopcomputer", "laptopcomputer", "stethoscope", "peacesign", "infinity"].contains(iconName) {
                    return iconName + ".fill"
                } else if !iconName.contains(".") && !["desktopcomputer", "laptopcomputer", "stethoscope", "peacesign", "infinity", "pencil"].contains(iconName) {
                    return iconName + ".fill"
                }
                return iconName
            })}
        case .outline:
            return baseIcons
        case .bold:
            return baseIcons.map { ($0.0, $0.1.map { iconName in
                if !iconName.contains(".") {
                    return iconName + ".circle.fill"
                }
                return iconName + ".fill"
            })}
        case .whimsical:
            return whimsicalIcons
        case .minimal:
            return baseIcons
        }
    }

    static var allIcons: [String] {
        baseIcons.flatMap { $0.1 }
    }
}

// MARK: - Button Styles

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.accent))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(SpheresTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).stroke(SpheresTheme.border))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct SmallAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(SpheresTheme.accent))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SmallGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(SpheresTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).stroke(SpheresTheme.border))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(SpheresTheme.textSecondary)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(SpheresTheme.surface))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct TinyIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(SpheresTheme.textSecondary)
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(SpheresTheme.surface))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Progress Components

struct SimpleProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(SpheresTheme.border)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * progress)
            }
        }
    }
}

struct FilledProgressPie: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(SpheresTheme.border, lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))")
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(SpheresTheme.textTertiary)
        }
    }
}

struct MiniProgressPie: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(SpheresTheme.border, lineWidth: 1.5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Safe Array Subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
