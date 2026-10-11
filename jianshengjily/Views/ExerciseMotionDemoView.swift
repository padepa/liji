#if DEBUG
import SwiftUI

enum ExerciseMotionKind: String {
  case benchPress
  case facePull
  case legPress

  init?(exerciseName: String) {
    switch exerciseName {
    case "卧推":
      self = .benchPress
    case "面拉":
      self = .facePull
    case "腿举":
      self = .legPress
    default:
      return nil
    }
  }

  var viewpoint: String {
    switch self {
    case .benchPress, .facePull, .legPress:
      return "侧视动作"
    }
  }
}

struct ExerciseMotionDemoView: View {
  @Environment(\.trainingTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let kind: ExerciseMotionKind

  @State private var isPlaying = true

  private var animationPaused: Bool {
    reduceMotion || !isPlaying
  }

  var body: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .top) {
        motionBackground

        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: animationPaused)) {
          timeline in
          Canvas { context, size in
            ExerciseMotionRenderer(tint: theme.primary).draw(
              kind,
              phase: motionPhase(at: timeline.date),
              in: &context,
              size: size
            )
          }
          .padding(.horizontal, 12)
          .padding(.top, 30)
          .padding(.bottom, 8)
        }

        HStack(spacing: 10) {
          Label("力迹原创动画", systemImage: "scribble.variable")
            .font(.caption.weight(.black))
            .foregroundStyle(theme.primary)

          Spacer()

          Button {
            HapticsService.openPanel()
            isPlaying.toggle()
          } label: {
            Label(
              reduceMotion ? "已减少动态效果" : (isPlaying ? "暂停" : "播放"),
              systemImage: reduceMotion ? "figure.stand" : (isPlaying ? "pause.fill" : "play.fill")
            )
            .labelStyle(.iconOnly)
            .font(.caption.weight(.black))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(.white.opacity(0.09), in: Circle())
          }
          .buttonStyle(.plain)
          .disabled(reduceMotion)
          .accessibilityLabel(
            L10n.string(reduceMotion ? "已减少动态效果" : (isPlaying ? "暂停动画" : "播放动画"))
          )
        }
        .padding(.horizontal, 15)
        .padding(.top, 13)
      }
      .frame(height: 222)

      HStack(spacing: 9) {
        Label("慢速循环 · 起止位置会短暂停留", systemImage: "arrow.triangle.2.circlepath")
          .lineLimit(1)
          .minimumScaleFactor(0.76)

        Spacer(minLength: 8)

        Text(L10n.string(kind.viewpoint))
          .foregroundStyle(theme.primary)
      }
      .font(.caption.weight(.heavy))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 16)
      .padding(.vertical, 13)
      .background(.white.opacity(0.045))
    }
    .background(Color.black.opacity(0.18))
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(theme.primary.opacity(0.24), lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
  }

  private var motionBackground: some View {
    ZStack {
      Color.white.opacity(0.035)

      RadialGradient(
        colors: [theme.primary.opacity(0.16), .clear],
        center: .center,
        startRadius: 6,
        endRadius: 190
      )

      LinearGradient(
        colors: [.white.opacity(0.03), .clear, .black.opacity(0.16)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }

  private func motionPhase(at date: Date) -> CGFloat {
    guard !reduceMotion else {
      return 0.58
    }

    let duration = 4.2
    let raw =
      date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
      / duration

    switch raw {
    case 0..<0.14:
      return 0
    case 0.14..<0.50:
      return smoothStep(CGFloat((raw - 0.14) / 0.36))
    case 0.50..<0.64:
      return 1
    default:
      return 1 - smoothStep(CGFloat((raw - 0.64) / 0.36))
    }
  }

  private func smoothStep(_ value: CGFloat) -> CGFloat {
    let clamped = min(max(value, 0), 1)
    return clamped * clamped * (3 - 2 * clamped)
  }
}

private struct ExerciseMotionRenderer {
  let tint: Color

  private var bodyColor: Color { .white.opacity(0.92) }
  private var equipmentColor: Color { tint.opacity(0.94) }
  private var guideColor: Color { tint.opacity(0.24) }

  func draw(
    _ kind: ExerciseMotionKind,
    phase: CGFloat,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    switch kind {
    case .benchPress:
      benchPress(phase: phase, in: &context, size: size)
    case .facePull:
      facePull(phase: phase, in: &context, size: size)
    case .legPress:
      legPress(phase: phase, in: &context, size: size)
    }
  }

  private func benchPress(phase: CGFloat, in context: inout GraphicsContext, size: CGSize) {
    let barY = mix(0.50, 0.24, phase)

    equipment([(0.16, 0.73), (0.80, 0.73)], width: 0.040, in: &context, size: size)
    equipment([(0.25, 0.73), (0.22, 0.88)], width: 0.022, in: &context, size: size)
    equipment([(0.70, 0.73), (0.73, 0.88)], width: 0.022, in: &context, size: size)
    equipment([(0.18, 0.86), (0.82, 0.86)], width: 0.014, opacity: 0.34, in: &context, size: size)

    motionGuide(from: (0.78, 0.50), to: (0.78, 0.24), progress: phase, in: &context, size: size)

    head((0.25, 0.62), in: &context, size: size)
    body([(0.32, 0.65), (0.63, 0.65)], in: &context, size: size)
    body([(0.63, 0.65), (0.75, 0.72), (0.84, 0.84)], in: &context, size: size)
    body([(0.58, 0.66), (0.52, 0.78), (0.46, 0.84)], opacity: 0.68, in: &context, size: size)

    let nearElbow = mix((0.35, 0.51), (0.42, 0.38), phase)
    let nearHand = mix((0.43, 0.50), (0.47, 0.25), phase)
    let farElbow = mix((0.61, 0.51), (0.57, 0.38), phase)
    let farHand = mix((0.54, 0.50), (0.54, 0.25), phase)
    body([(0.39, 0.63), nearElbow, nearHand], in: &context, size: size)
    body([(0.53, 0.63), farElbow, farHand], opacity: 0.72, in: &context, size: size)

    barbell(y: barY, fromX: 0.27, toX: 0.71, in: &context, size: size)
    joint(nearElbow, in: &context, size: size)
    joint(farElbow, opacity: 0.62, in: &context, size: size)
  }

  private func facePull(phase: CGFloat, in context: inout GraphicsContext, size: CGSize) {
    equipment([(0.10, 0.11), (0.10, 0.88)], width: 0.030, in: &context, size: size)
    equipment([(0.06, 0.88), (0.18, 0.88)], width: 0.044, in: &context, size: size)
    equipmentBlock(center: (0.10, 0.20), in: &context, size: size)
    equipmentBlock(center: (0.10, 0.74), in: &context, size: size)

    motionGuide(from: (0.40, 0.32), to: (0.63, 0.32), progress: phase, in: &context, size: size)

    head((0.72, 0.31), in: &context, size: size)
    body([(0.72, 0.40), (0.74, 0.68)], in: &context, size: size)
    body([(0.74, 0.68), (0.64, 0.86)], in: &context, size: size)
    body([(0.74, 0.68), (0.85, 0.86)], in: &context, size: size)
    equipment([(0.56, 0.88), (0.91, 0.88)], width: 0.014, opacity: 0.34, in: &context, size: size)

    let upperShoulder: (CGFloat, CGFloat) = (0.68, 0.42)
    let lowerShoulder: (CGFloat, CGFloat) = (0.70, 0.46)
    let upperElbow = mix((0.54, 0.40), (0.55, 0.25), phase)
    let lowerElbow = mix((0.55, 0.48), (0.56, 0.40), phase)
    let upperHand = mix((0.41, 0.33), (0.63, 0.28), phase)
    let lowerHand = mix((0.41, 0.37), (0.63, 0.37), phase)
    body([upperShoulder, upperElbow, upperHand], in: &context, size: size)
    body([lowerShoulder, lowerElbow, lowerHand], opacity: 0.75, in: &context, size: size)

    let ropeJunction = mix((0.35, 0.35), (0.54, 0.33), phase)
    equipment([(0.10, 0.23), ropeJunction], width: 0.018, in: &context, size: size)
    equipment([ropeJunction, upperHand], width: 0.025, in: &context, size: size)
    equipment([ropeJunction, lowerHand], width: 0.025, in: &context, size: size)
    joint(upperElbow, in: &context, size: size)
    joint(lowerElbow, opacity: 0.62, in: &context, size: size)
  }

  private func legPress(phase: CGFloat, in context: inout GraphicsContext, size: CGSize) {
    equipment([(0.54, 0.89), (0.88, 0.10)], width: 0.024, in: &context, size: size)
    equipment([(0.65, 0.89), (0.97, 0.18)], width: 0.024, opacity: 0.64, in: &context, size: size)
    equipment([(0.17, 0.78), (0.39, 0.49)], width: 0.074, opacity: 0.76, in: &context, size: size)
    equipment([(0.28, 0.75), (0.52, 0.75)], width: 0.040, in: &context, size: size)

    motionGuide(from: (0.68, 0.48), to: (0.86, 0.23), progress: phase, in: &context, size: size)

    head((0.31, 0.44), in: &context, size: size)
    body([(0.37, 0.51), (0.51, 0.68)], in: &context, size: size)
    body([(0.40, 0.54), (0.30, 0.65)], opacity: 0.72, in: &context, size: size)

    let nearKnee = mix((0.61, 0.64), (0.69, 0.47), phase)
    let nearFoot = mix((0.70, 0.44), (0.84, 0.25), phase)
    let farKnee = mix((0.65, 0.70), (0.72, 0.52), phase)
    let farFoot = mix((0.73, 0.49), (0.87, 0.30), phase)
    body([(0.51, 0.68), nearKnee, nearFoot], in: &context, size: size)
    body([(0.49, 0.66), farKnee, farFoot], opacity: 0.70, in: &context, size: size)

    let platformCenter = mix((0.74, 0.42), (0.88, 0.23), phase)
    equipment(
      [
        (platformCenter.0 - 0.075, platformCenter.1 - 0.055),
        (platformCenter.0 + 0.075, platformCenter.1 + 0.055),
      ],
      width: 0.055,
      in: &context,
      size: size
    )
    equipmentBlock(
      center: (platformCenter.0 + 0.045, platformCenter.1 - 0.075),
      scale: 1.12,
      in: &context,
      size: size
    )
    joint(nearKnee, in: &context, size: size)
    joint(farKnee, opacity: 0.58, in: &context, size: size)
  }

  private func body(
    _ points: [(CGFloat, CGFloat)],
    opacity: Double = 1,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    stroke(
      points,
      color: bodyColor.opacity(opacity),
      width: max(5, min(size.width, size.height) * 0.030),
      in: &context,
      size: size
    )
  }

  private func equipment(
    _ points: [(CGFloat, CGFloat)],
    width: CGFloat,
    opacity: Double = 1,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    stroke(
      points,
      color: equipmentColor.opacity(opacity),
      width: max(2, min(size.width, size.height) * width),
      in: &context,
      size: size
    )
  }

  private func stroke(
    _ points: [(CGFloat, CGFloat)],
    color: Color,
    width: CGFloat,
    dash: [CGFloat] = [],
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    guard let first = points.first else {
      return
    }

    var path = Path()
    path.move(to: point(first, size: size))
    for value in points.dropFirst() {
      path.addLine(to: point(value, size: size))
    }
    context.stroke(
      path,
      with: .color(color),
      style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
    )
  }

  private func head(
    _ center: (CGFloat, CGFloat), in context: inout GraphicsContext, size: CGSize
  ) {
    let diameter = min(size.width, size.height) * 0.090
    let centerPoint = point(center, size: size)
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: centerPoint.x - diameter / 2,
          y: centerPoint.y - diameter / 2,
          width: diameter,
          height: diameter
        )
      ),
      with: .color(bodyColor)
    )
  }

  private func joint(
    _ center: (CGFloat, CGFloat),
    opacity: Double = 1,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    let diameter = min(size.width, size.height) * 0.035
    let centerPoint = point(center, size: size)
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: centerPoint.x - diameter / 2,
          y: centerPoint.y - diameter / 2,
          width: diameter,
          height: diameter
        )
      ),
      with: .color(tint.opacity(0.92 * opacity))
    )
  }

  private func equipmentBlock(
    center: (CGFloat, CGFloat),
    scale: CGFloat = 1,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    let centerPoint = point(center, size: size)
    let blockSize = min(size.width, size.height) * 0.070 * scale
    let rect = CGRect(
      x: centerPoint.x - blockSize * 0.43,
      y: centerPoint.y - blockSize / 2,
      width: blockSize * 0.86,
      height: blockSize
    )
    context.fill(
      RoundedRectangle(cornerRadius: blockSize * 0.18, style: .continuous).path(in: rect),
      with: .color(equipmentColor)
    )
  }

  private func barbell(
    y: CGFloat,
    fromX: CGFloat,
    toX: CGFloat,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    equipment([(fromX, y), (toX, y)], width: 0.020, in: &context, size: size)
    equipment(
      [(fromX + 0.035, y - 0.055), (fromX + 0.035, y + 0.055)], width: 0.032, in: &context,
      size: size)
    equipment(
      [(toX - 0.035, y - 0.055), (toX - 0.035, y + 0.055)], width: 0.032, in: &context, size: size)
  }

  private func motionGuide(
    from: (CGFloat, CGFloat),
    to: (CGFloat, CGFloat),
    progress: CGFloat,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    let dashLength = min(size.width, size.height) * 0.028
    stroke(
      [from, to],
      color: guideColor,
      width: max(1.5, min(size.width, size.height) * 0.010),
      dash: [dashLength, dashLength],
      in: &context,
      size: size
    )

    let marker = mix(from, to, progress)
    let markerPoint = point(marker, size: size)
    let diameter = min(size.width, size.height) * 0.046
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: markerPoint.x - diameter / 2,
          y: markerPoint.y - diameter / 2,
          width: diameter,
          height: diameter
        )
      ),
      with: .color(tint.opacity(0.22))
    )
  }

  private func point(_ value: (CGFloat, CGFloat), size: CGSize) -> CGPoint {
    CGPoint(x: value.0 * size.width, y: value.1 * size.height)
  }

  private func mix(_ start: CGFloat, _ end: CGFloat, _ phase: CGFloat) -> CGFloat {
    start + (end - start) * phase
  }

  private func mix(
    _ start: (CGFloat, CGFloat),
    _ end: (CGFloat, CGFloat),
    _ phase: CGFloat
  ) -> (CGFloat, CGFloat) {
    (mix(start.0, end.0, phase), mix(start.1, end.1, phase))
  }
}
#endif
