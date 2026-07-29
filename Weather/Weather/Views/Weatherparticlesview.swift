import SwiftUI

/// A lightweight animated overlay that draws falling rain or snow particles.
/// Intentionally uses a small, fixed particle count and a single TimelineView
/// to stay cheap to render on real devices.
struct WeatherParticlesView: View {
    enum Kind {
        case rain
        case snow
    }

    let kind: Kind
    private let particleCount: Int

    init(kind: Kind) {
        self.kind = kind
        self.particleCount = kind == .rain ? 60 : 40
    }

    // Precomputed pseudo-random seeds so particles don't all move identically.
    private let seeds: [Double] = (0..<80).map { _ in Double.random(in: 0...1) }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for i in 0..<particleCount {
                    let seed = seeds[i % seeds.count]
                    let speed = kind == .rain ? 900.0 : 90.0
                    let fallDistance = size.height + 40
                    let progress = ((time * speed * (0.7 + seed * 0.6)) + seed * fallDistance).truncatingRemainder(dividingBy: fallDistance)

                    let x = (seed * size.width + (kind == .snow ? sin(time + seed * 10) * 20 : 0))
                        .truncatingRemainder(dividingBy: size.width)
                    let y = progress - 20

                    switch kind {
                    case .rain:
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x - 2, y: y + 14))
                        context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1.4)
                    case .snow:
                        let radius = 1.5 + seed * 1.5
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.6)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
