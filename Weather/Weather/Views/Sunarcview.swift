import SwiftUI

/// Draws an arc from sunrise to sunset with a sun marker positioned according to the current time.
struct SunArcView: View {
    let sunrise: Date
    let sunset: Date

    private var progress: Double {
        let now = Date()
        let total = sunset.timeIntervalSince(sunrise)
        guard total > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(sunrise)
        return min(max(elapsed / total, 0), 1)
    }

    private var isBeforeSunrise: Bool { Date() < sunrise }
    private var isAfterSunset: Bool { Date() > sunset }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sunrise & Sunset")
                .font(.headline)
                .foregroundStyle(.white)

            GeometryReader { geo in
                let width = geo.size.width
                let height: CGFloat = 90

                ZStack {
                    // Arc path
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addQuadCurve(
                            to: CGPoint(x: width, y: height),
                            control: CGPoint(x: width / 2, y: -height * 0.35)
                        )
                    }
                    .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))

                    // Progress portion of the arc (only meaningful between sunrise/sunset)
                    if !isBeforeSunrise {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height))
                            path.addQuadCurve(
                                to: CGPoint(x: width, y: height),
                                control: CGPoint(x: width / 2, y: -height * 0.35)
                            )
                        }
                        .trim(from: 0, to: isAfterSunset ? 1 : progress)
                        .stroke(Color.yellow.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    // Sun marker
                    if !isBeforeSunrise && !isAfterSunset {
                        let point = pointOnQuad(t: progress, width: width, height: height)
                        Image(systemName: "sun.max.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 20))
                            .position(point)
                    }

                    // Horizon line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: width, y: height))
                    }
                    .stroke(.white.opacity(0.2), lineWidth: 1)
                }
            }
            .frame(height: 90)

            HStack {
                Label(timeString(sunrise), systemImage: "sunrise.fill")
                Spacer()
                Label(timeString(sunset), systemImage: "sunset.fill")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding()
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func pointOnQuad(t rawT: Double, width: CGFloat, height: CGFloat) -> CGPoint {
        // Quadratic Bezier: P(t) = (1-t)^2 * P0 + 2(1-t)t * C + t^2 * P1
        let t = CGFloat(rawT)
        let p0 = CGPoint(x: 0, y: height)
        let c = CGPoint(x: width / 2, y: -height * 0.35)
        let p1 = CGPoint(x: width, y: height)
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * p0.x + 2 * oneMinusT * t * c.x + t * t * p1.x
        let y = oneMinusT * oneMinusT * p0.y + 2 * oneMinusT * t * c.y + t * t * p1.y
        return CGPoint(x: x, y: y)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
