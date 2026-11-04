import SwiftUI

struct BearMascotView: View {
    enum Mood {
        case happy
        case listening
    }

    let size: CGFloat
    var mood: Mood?

    private let fur = Color(red: 0x6B / 255, green: 0x42 / 255, blue: 0x26 / 255)
    private let innerEar = Color(red: 0xC6 / 255, green: 0x8B / 255, blue: 0x59 / 255)
    private let muzzle = Color(red: 0xE8 / 255, green: 0xC3 / 255, blue: 0x9E / 255)
    private let dark = Color(red: 0x2B / 255, green: 0x1A / 255, blue: 0x10 / 255)

    var body: some View {
        ZStack {
            ear
                .offset(x: -size * 0.24, y: -size * 0.29)
            ear
                .offset(x: size * 0.24, y: -size * 0.29)

            Circle()
                .fill(fur)
                .frame(width: size * 0.78, height: size * 0.78)

            eye
                .offset(x: -size * 0.145, y: -size * 0.08)
            eye
                .offset(x: size * 0.145, y: -size * 0.08)

            Ellipse()
                .fill(muzzle)
                .frame(width: size * 0.43, height: size * 0.29)
                .offset(y: size * 0.13)

            Ellipse()
                .fill(dark)
                .frame(width: size * 0.12, height: size * 0.085)
                .offset(y: size * 0.075)

            if mood == .happy {
                Smile()
                    .stroke(dark, style: StrokeStyle(lineWidth: size * 0.018, lineCap: .round))
                    .frame(width: size * 0.15, height: size * 0.07)
                    .offset(y: size * 0.205)
            }

            if mood == .listening {
                headphones
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var ear: some View {
        ZStack {
            Circle()
                .fill(fur)
                .frame(width: size * 0.31, height: size * 0.31)
            Circle()
                .fill(innerEar)
                .frame(width: size * 0.15, height: size * 0.15)
                .offset(y: size * 0.025)
        }
    }

    private var eye: some View {
        ZStack {
            Circle()
                .fill(dark)
                .frame(width: size * 0.075, height: size * 0.075)
            Circle()
                .fill(.white)
                .frame(width: size * 0.022, height: size * 0.022)
                .offset(x: -size * 0.014, y: -size * 0.016)
        }
    }

    private var headphones: some View {
        ZStack {
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                .frame(width: size * 0.91, height: size * 0.91)
                .rotationEffect(.degrees(180))
                .offset(y: size * 0.08)
            HStack {
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(Color.accentColor)
                    .frame(width: size * 0.11, height: size * 0.22)
                Spacer()
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(Color.accentColor)
                    .frame(width: size * 0.11, height: size * 0.22)
            }
            .frame(width: size * 0.95)
            .offset(y: -size * 0.015)
        }
    }
}

private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        }
    }
}
