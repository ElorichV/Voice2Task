import SwiftUI

struct MascotView: View {
    enum Mood {
        case happy
        case listening
    }

    let size: CGFloat
    var mood: Mood?

    private let amber = Color(red: 245 / 255, green: 165 / 255, blue: 36 / 255)
    private let tuftColor = Color(red: 217 / 255, green: 134 / 255, blue: 26 / 255)
    private let faceColor = Color(red: 255 / 255, green: 231 / 255, blue: 184 / 255)
    private let dark = Color(red: 31 / 255, green: 27 / 255, blue: 58 / 255)
    private let beakColor = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)

    var body: some View {
        ZStack {
            if mood == .listening {
                HeadphoneBand()
                    .stroke(.white, style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                    .frame(width: size * 0.94, height: size * 0.55)
                    .offset(y: -size * 0.2)
            }

            Ellipse()
                .fill(amber)
                .frame(width: size * 0.78, height: size * 0.9)
                .offset(y: size * 0.04)

            OwlTuft()
                .fill(tuftColor)
                .frame(width: size * 0.2, height: size * 0.19)
                .rotationEffect(.degrees(-12))
                .offset(x: -size * 0.22, y: -size * 0.36)
            OwlTuft()
                .fill(tuftColor)
                .frame(width: size * 0.2, height: size * 0.19)
                .rotationEffect(.degrees(12))
                .offset(x: size * 0.22, y: -size * 0.36)

            Circle()
                .fill(faceColor)
                .frame(width: size * 0.46, height: size * 0.46)
                .offset(x: -size * 0.13, y: -size * 0.065)
            Circle()
                .fill(faceColor)
                .frame(width: size * 0.46, height: size * 0.46)
                .offset(x: size * 0.13, y: -size * 0.065)

            if mood == .happy {
                ClosedEye()
                    .stroke(dark, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                    .frame(width: size * 0.18, height: size * 0.1)
                    .offset(x: -size * 0.14, y: -size * 0.06)
                ClosedEye()
                    .stroke(dark, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                    .frame(width: size * 0.18, height: size * 0.1)
                    .offset(x: size * 0.14, y: -size * 0.06)
            } else {
                eye.offset(x: -size * 0.14, y: -size * 0.065)
                eye.offset(x: size * 0.14, y: -size * 0.065)
            }

            RoundedTriangle()
                .fill(beakColor)
                .frame(width: size * 0.15, height: size * 0.14)
                .offset(y: size * 0.075)

            Ellipse()
                .fill(faceColor)
                .frame(width: size * 0.43, height: size * 0.31)
                .offset(y: size * 0.29)

            ForEach(0..<3) { index in
                FeatherChevron()
                    .stroke(tuftColor, style: StrokeStyle(lineWidth: size * 0.014, lineCap: .round))
                    .frame(width: size * 0.13, height: size * 0.045)
                    .offset(y: size * (0.2 + CGFloat(index) * 0.07))
            }

            if mood == .listening {
                headphones
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var eye: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: size * 0.22, height: size * 0.22)
            Circle()
                .fill(dark)
                .frame(width: size * 0.105, height: size * 0.105)
            Circle()
                .fill(.white)
                .frame(width: size * 0.035, height: size * 0.035)
                .offset(x: -size * 0.027, y: -size * 0.032)
        }
    }

    private var headphones: some View {
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
        .offset(y: -size * 0.02)
    }
}

private struct OwlTuft: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

private struct RoundedTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12))
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.82)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.82)
            )
            path.closeSubpath()
        }
    }
}

private struct ClosedEye: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        }
    }
}

private struct HeadphoneBand: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        }
    }
}

private struct FeatherChevron: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY))
        }
    }
}
