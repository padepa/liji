import SwiftUI

struct ExerciseGlyphView: View {
  @Environment(\.trainingTheme) private var theme

  var exerciseName: String?
  var size: CGFloat = 32

  private var profile: ExerciseGlyphProfile {
    ExerciseGlyphProfile(name: exerciseName)
  }

  var body: some View {
    Canvas { context, canvasSize in
      ExerciseGlyphRenderer(tint: theme.primary).draw(
        profile, in: &context, canvasSize: canvasSize)
    }
    .frame(width: size * 0.90, height: size * 0.90)
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

#if DEBUG
  struct ExerciseGlyphCatalogView: View {
    static let canvasSize = CGSize(width: 1100, height: 2800)

    let exerciseNames: [String]

    private let columnCount = 5
    private let cellWidth: CGFloat = 190
    private let cellHeight: CGFloat = 120

    private var rowCount: Int {
      (exerciseNames.count + columnCount - 1) / columnCount
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 8) {
          Text("力迹 · 官方动作图标总览")
            .font(.system(size: 38, weight: .black, design: .rounded))
            .foregroundStyle(.white)

          Text("共 \(exerciseNames.count) 个动作 · 图标下方为对应名称 · 可直接回复编号或动作名")
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.bottom, 8)

        ForEach(0..<rowCount, id: \.self) { row in
          HStack(spacing: 14) {
            ForEach(0..<columnCount, id: \.self) { column in
              let index = row * columnCount + column
              if index < exerciseNames.count {
                catalogCell(name: exerciseNames[index], index: index)
              } else {
                Color.clear
                  .frame(width: cellWidth, height: cellHeight)
              }
            }
          }
        }
      }
      .padding(36)
      .frame(
        width: Self.canvasSize.width,
        height: Self.canvasSize.height,
        alignment: .topLeading
      )
      .background(
        LinearGradient(
          colors: [
            Color(red: 0.035, green: 0.029, blue: 0.055),
            Color(red: 0.012, green: 0.012, blue: 0.020),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }

    private func catalogCell(name: String, index: Int) -> some View {
      VStack(spacing: 5) {
        ExerciseGlyphView(exerciseName: name, size: 72)

        Text(String(format: "%02d  %@", index + 1, name))
          .font(.system(size: 17, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
      .padding(.horizontal, 8)
      .frame(width: cellWidth, height: cellHeight)
      .background(
        Color.white.opacity(0.055),
        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(.white.opacity(0.08), lineWidth: 1)
      }
    }
  }

  @MainActor
  enum ExerciseGlyphCatalogExporter {
    static let launchArgument = "--export-exercise-glyph-catalog"
    static let fileName = "exercise-icon-catalog.png"

    static var shouldExport: Bool {
      ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static func export() {
      let catalog = ExerciseGlyphCatalogView(exerciseNames: WorkoutService.defaultExercises)
        .environment(\.trainingTheme, TrainingTheme.violet)
        .preferredColorScheme(.dark)
      let renderer = ImageRenderer(content: catalog)
      renderer.proposedSize = ProposedViewSize(
        width: ExerciseGlyphCatalogView.canvasSize.width,
        height: ExerciseGlyphCatalogView.canvasSize.height
      )
      renderer.scale = 2
      renderer.isOpaque = true

      guard let image = renderer.uiImage,
        let data = image.pngData(),
        let documentsURL = FileManager.default.urls(
          for: .documentDirectory,
          in: .userDomainMask
        ).first
      else {
        print("Exercise glyph catalog export failed")
        return
      }

      let outputURL = documentsURL.appendingPathComponent(fileName)
      do {
        try data.write(to: outputURL, options: .atomic)
        print("Exercise glyph catalog exported: \(outputURL.path)")
      } catch {
        print("Exercise glyph catalog export failed: \(error)")
      }
    }
  }
#endif

private struct ExerciseGlyphProfile {
  let kind: ExerciseGlyphKind
  let equipment: ExerciseGlyphEquipment
  let variant: ExerciseGlyphVariant

  init(
    kind: ExerciseGlyphKind,
    equipment: ExerciseGlyphEquipment = .none,
    variant: ExerciseGlyphVariant = .standard
  ) {
    self.kind = kind
    self.equipment = equipment
    self.variant = variant
  }

  init(name rawName: String?) {
    let name = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    switch name {
    case "卧推":
      self.init(kind: .benchPress, equipment: .barbell)
    case "上斜卧推":
      self.init(kind: .benchPress, equipment: .barbell, variant: .incline)
    case "下斜卧推":
      self.init(kind: .benchPress, equipment: .barbell, variant: .decline)
    case "窄握卧推":
      self.init(kind: .benchPress, equipment: .barbell, variant: .closeGrip)
    case "史密斯卧推":
      self.init(kind: .benchPress, equipment: .machine)
    case "哑铃卧推":
      self.init(kind: .benchPress, equipment: .dumbbell)
    case "上斜哑铃卧推":
      self.init(kind: .benchPress, equipment: .dumbbell, variant: .incline)
    case "下斜哑铃卧推":
      self.init(kind: .benchPress, equipment: .dumbbell, variant: .decline)
    case "器械推胸":
      self.init(kind: .benchPress, equipment: .machine, variant: .seatedMachine)
    case "俯卧撑":
      self.init(kind: .pushUp, equipment: .bodyweight)
    case "窄距俯卧撑":
      self.init(kind: .pushUp, equipment: .bodyweight, variant: .closeGrip)
    case "双杠臂屈伸":
      self.init(kind: .dip, equipment: .bodyweight)
    case "哑铃飞鸟":
      self.init(kind: .chestFly, equipment: .dumbbell)
    case "绳索夹胸":
      self.init(kind: .chestFly, equipment: .cable)
    case "低位绳索夹胸":
      self.init(kind: .chestFly, equipment: .cable, variant: .low)
    case "蝴蝶机夹胸":
      self.init(kind: .chestFly, equipment: .machine)

    case "深蹲":
      self.init(kind: .squat, equipment: .barbell)
    case "前蹲":
      self.init(kind: .squat, equipment: .barbell, variant: .frontLoaded)
    case "高脚杯深蹲":
      self.init(kind: .squat, equipment: .dumbbell, variant: .goblet)
    case "箱式深蹲":
      self.init(kind: .squat, equipment: .barbell, variant: .box)
    case "史密斯深蹲":
      self.init(kind: .squat, equipment: .machine)
    case "哈克深蹲":
      self.init(kind: .squat, equipment: .machine, variant: .hack)
    case "保加利亚分腿蹲":
      self.init(kind: .lunge, equipment: .bodyweight, variant: .bulgarian)
    case "弓步蹲":
      self.init(kind: .lunge, equipment: .bodyweight)
    case "反向箭步蹲":
      self.init(kind: .lunge, equipment: .bodyweight, variant: .reverse)
    case "台阶上步":
      self.init(kind: .lunge, equipment: .bodyweight, variant: .stepUp)
    case "硬拉":
      self.init(kind: .hipHinge, equipment: .barbell)
    case "相扑硬拉":
      self.init(kind: .hipHinge, equipment: .barbell, variant: .sumo)
    case "罗马尼亚硬拉":
      self.init(kind: .hipHinge, equipment: .barbell, variant: .romanian)
    case "臀推":
      self.init(kind: .hipThrust, equipment: .barbell)
    case "臀桥":
      self.init(kind: .hipThrust, equipment: .bodyweight)
    case "髋外展":
      self.init(kind: .hipAbduction, equipment: .machine)

    case "引体向上":
      self.init(kind: .pullUp, equipment: .bodyweight)
    case "中立握引体向上":
      self.init(kind: .pullUp, equipment: .bodyweight, variant: .neutralGrip)
    case "反手引体向上":
      self.init(kind: .pullUp, equipment: .bodyweight, variant: .reverseGrip)
    case "反向划船":
      self.init(kind: .row, equipment: .bodyweight)
    case "高位下拉":
      self.init(kind: .pulldown, equipment: .cable)
    case "反握高位下拉":
      self.init(kind: .pulldown, equipment: .cable, variant: .reverseGrip)
    case "窄握下拉":
      self.init(kind: .pulldown, equipment: .cable, variant: .closeGrip)
    case "直臂下拉":
      self.init(kind: .straightArmPulldown, equipment: .cable)
    case "坐姿划船":
      self.init(kind: .row, equipment: .cable)
    case "单臂哑铃划船":
      self.init(kind: .row, equipment: .dumbbell, variant: .singleArm)
    case "杠铃划船":
      self.init(kind: .row, equipment: .barbell)
    case "T杠划船":
      self.init(kind: .row, equipment: .barbell, variant: .tBar)
    case "胸托划船":
      self.init(kind: .row, equipment: .barbell, variant: .chestSupported)
    case "哑铃上拉":
      self.init(kind: .pullover, equipment: .dumbbell)

    case "肩推":
      self.init(kind: .shoulderPress, equipment: .barbell)
    case "军用推举":
      self.init(kind: .shoulderPress, equipment: .barbell, variant: .military)
    case "史密斯肩推":
      self.init(kind: .shoulderPress, equipment: .machine)
    case "哑铃肩推":
      self.init(kind: .shoulderPress, equipment: .dumbbell)
    case "阿诺德推举":
      self.init(kind: .shoulderPress, equipment: .dumbbell, variant: .arnold)
    case "侧平举":
      self.init(kind: .lateralRaise, equipment: .dumbbell)
    case "绳索侧平举":
      self.init(kind: .lateralRaise, equipment: .cable)
    case "哑铃前平举":
      self.init(kind: .frontRaise, equipment: .dumbbell)
    case "俯身飞鸟":
      self.init(kind: .reverseFly, equipment: .dumbbell)
    case "反向蝴蝶机":
      self.init(kind: .reverseFly, equipment: .machine)
    case "面拉":
      self.init(kind: .facePull, equipment: .cable)
    case "杠铃耸肩":
      self.init(kind: .shrug, equipment: .barbell)
    case "哑铃耸肩":
      self.init(kind: .shrug, equipment: .dumbbell)

    case "二头弯举":
      self.init(kind: .bicepsCurl, equipment: .dumbbell)
    case "杠铃弯举":
      self.init(kind: .bicepsCurl, equipment: .barbell)
    case "锤式弯举":
      self.init(kind: .bicepsCurl, equipment: .dumbbell, variant: .hammer)
    case "上斜哑铃弯举":
      self.init(kind: .bicepsCurl, equipment: .dumbbell, variant: .incline)
    case "绳索弯举":
      self.init(kind: .bicepsCurl, equipment: .cable)
    case "反握弯举":
      self.init(kind: .bicepsCurl, equipment: .barbell, variant: .reverseGrip)
    case "集中弯举":
      self.init(kind: .bicepsCurl, equipment: .dumbbell, variant: .concentration)
    case "牧师椅弯举":
      self.init(kind: .bicepsCurl, equipment: .dumbbell, variant: .preacher)
    case "三头下压":
      self.init(kind: .tricepsPushdown, equipment: .cable)
    case "过顶臂屈伸":
      self.init(kind: .tricepsOverhead, equipment: .dumbbell)
    case "绳索过顶臂屈伸":
      self.init(kind: .tricepsOverhead, equipment: .cable)
    case "仰卧臂屈伸":
      self.init(kind: .skullCrusher, equipment: .barbell)
    case "绳索下压":
      self.init(kind: .tricepsPushdown, equipment: .cable, variant: .rope)
    case "单臂绳索下压":
      self.init(kind: .tricepsPushdown, equipment: .cable, variant: .singleArm)
    case "腿举":
      self.init(kind: .legPress, equipment: .machine)
    case "腿屈伸":
      self.init(kind: .legExtension, equipment: .machine)
    case "腿弯举":
      self.init(kind: .legCurl, equipment: .machine)
    case "小腿提踵":
      self.init(kind: .calfRaise, equipment: .bodyweight)
    case "站姿小腿提踵":
      self.init(kind: .calfRaise, equipment: .machine)
    case "坐姿小腿提踵":
      self.init(kind: .seatedCalfRaise, equipment: .machine)

    case "平板支撑":
      self.init(kind: .plank, equipment: .bodyweight)
    case "卷腹":
      self.init(kind: .crunch, equipment: .bodyweight)
    case "反向卷腹":
      self.init(kind: .crunch, equipment: .bodyweight, variant: .reverse)
    case "绳索卷腹":
      self.init(kind: .crunch, equipment: .cable)
    case "悬垂举腿":
      self.init(kind: .legRaise, equipment: .bodyweight)
    case "俄罗斯转体":
      self.init(kind: .rotation, equipment: .bodyweight)
    case "Pallof抗旋转":
      self.init(kind: .rotation, equipment: .cable)
    case "死虫":
      self.init(kind: .deadBug, equipment: .bodyweight)
    case "鸟狗":
      self.init(kind: .birdDog, equipment: .bodyweight)
    case "侧桥":
      self.init(kind: .sidePlank, equipment: .bodyweight)
    case "罗马椅挺身":
      self.init(kind: .backExtension, equipment: .machine)

    case "壶铃摆动":
      self.init(kind: .kettlebellSwing, equipment: .kettlebell)
    case "农夫行走":
      self.init(kind: .carry, equipment: .dumbbell)
    case "药球砸地":
      self.init(kind: .ballSlam, equipment: .ball)
    case "雪橇推":
      self.init(kind: .sledPush, equipment: .sled)
    case "战绳":
      self.init(kind: .battleRope, equipment: .rope)

    default:
      self = Self.inferredProfile(from: name.lowercased())
    }
  }

  private static func inferredProfile(from name: String) -> ExerciseGlyphProfile {
    let equipment: ExerciseGlyphEquipment
    if name.contains("dumbbell") || name.contains("哑铃") {
      equipment = .dumbbell
    } else if name.contains("cable") || name.contains(cableKeyword) || name.contains("下拉")
      || name.contains("下压")
    {
      equipment = .cable
    } else if name.contains("machine") || name.contains(machineKeyword)
      || name.contains(smithKeyword)
    {
      equipment = .machine
    } else if name.contains("barbell") || name.contains(barbellKeyword) {
      equipment = .barbell
    } else {
      equipment = .bodyweight
    }

    if containsAny(name, ["bench", "卧推", "推胸"]) {
      return .init(kind: .benchPress, equipment: equipment)
    }
    if containsAny(name, ["push-up", "pushup", "俯卧撑"]) {
      return .init(kind: .pushUp, equipment: .bodyweight)
    }
    if containsAny(name, ["fly", "飞鸟", "夹胸"]) {
      return .init(kind: .chestFly, equipment: equipment)
    }
    if containsAny(name, ["squat", "深蹲"]) {
      return .init(kind: .squat, equipment: equipment)
    }
    if containsAny(name, ["lunge", "弓步", "箭步", "分腿蹲", "上步"]) {
      return .init(kind: .lunge, equipment: equipment)
    }
    if containsAny(name, ["deadlift", "硬拉"]) {
      return .init(kind: .hipHinge, equipment: equipment)
    }
    if containsAny(name, ["pull-up", "pullup", "引体"]) {
      return .init(kind: .pullUp, equipment: .bodyweight)
    }
    if containsAny(name, ["straight arm pulldown", "straight-arm pulldown", "直臂下拉"]) {
      return .init(kind: .straightArmPulldown, equipment: .cable)
    }
    if containsAny(name, ["pulldown", "下拉"]) {
      return .init(kind: .pulldown, equipment: .cable)
    }
    if containsAny(name, ["row", "划船"]) {
      return .init(kind: .row, equipment: equipment)
    }
    if containsAny(name, ["shoulder press", "overhead press", "肩推", "推举"]) {
      return .init(kind: .shoulderPress, equipment: equipment)
    }
    if containsAny(name, ["lateral raise", "侧平举", "前平举"]) {
      return .init(kind: .lateralRaise, equipment: equipment)
    }
    if containsAny(name, ["curl", "弯举", "二头"]) {
      return .init(kind: .bicepsCurl, equipment: equipment)
    }
    if containsAny(name, ["pushdown", "下压", "三头"]) {
      return .init(kind: .tricepsPushdown, equipment: .cable)
    }
    if containsAny(name, ["leg press", "腿举"]) {
      return .init(kind: .legPress, equipment: .machine)
    }
    if containsAny(name, ["plank", "平板", "侧桥"]) {
      return .init(kind: .plank, equipment: .bodyweight)
    }
    if containsAny(name, ["crunch", "卷腹"]) {
      return .init(kind: .crunch, equipment: equipment)
    }
    if containsAny(name, ["carry", "农夫"]) {
      return .init(kind: .carry, equipment: .dumbbell)
    }

    return .init(kind: .generic, equipment: equipment)
  }

  private static func containsAny(_ source: String, _ keywords: [String]) -> Bool {
    keywords.contains { source.contains($0) }
  }

  // Internal matching tokens are Unicode escapes so localization checks only inspect user-facing strings.
  private static let cableKeyword = "\u{7ef3}\u{7d22}"
  private static let machineKeyword = "\u{5668}\u{68b0}"
  private static let smithKeyword = "\u{53f2}\u{5bc6}\u{65af}"
  private static let barbellKeyword = "\u{6760}\u{94c3}"
}

private enum ExerciseGlyphKind {
  case benchPress
  case pushUp
  case dip
  case chestFly
  case squat
  case lunge
  case hipHinge
  case hipThrust
  case hipAbduction
  case pullUp
  case pulldown
  case straightArmPulldown
  case row
  case pullover
  case shoulderPress
  case lateralRaise
  case frontRaise
  case reverseFly
  case facePull
  case shrug
  case bicepsCurl
  case tricepsPushdown
  case tricepsOverhead
  case skullCrusher
  case legPress
  case legExtension
  case legCurl
  case calfRaise
  case seatedCalfRaise
  case plank
  case crunch
  case legRaise
  case rotation
  case deadBug
  case birdDog
  case sidePlank
  case backExtension
  case kettlebellSwing
  case carry
  case ballSlam
  case sledPush
  case battleRope
  case generic
}

private enum ExerciseGlyphEquipment {
  case barbell
  case dumbbell
  case machine
  case cable
  case bodyweight
  case kettlebell
  case ball
  case sled
  case rope
  case none
}

private enum ExerciseGlyphVariant {
  case standard
  case incline
  case decline
  case closeGrip
  case low
  case seatedMachine
  case frontLoaded
  case goblet
  case box
  case hack
  case bulgarian
  case reverse
  case stepUp
  case sumo
  case romanian
  case neutralGrip
  case reverseGrip
  case singleArm
  case tBar
  case chestSupported
  case military
  case arnold
  case hammer
  case concentration
  case preacher
  case rope
}

private struct ExerciseGlyphRenderer {
  let tint: Color

  private var bodyColor: Color { .white.opacity(0.90) }
  private var secondaryColor: Color { tint.opacity(0.30) }
  private var equipmentColor: Color { tint.opacity(0.94) }

  func draw(_ profile: ExerciseGlyphProfile, in context: inout GraphicsContext, canvasSize: CGSize)
  {
    switch profile.kind {
    case .benchPress:
      benchPress(profile.equipment, variant: profile.variant, in: &context, size: canvasSize)
    case .pushUp:
      pushUp(profile.variant, in: &context, size: canvasSize)
    case .dip:
      dip(in: &context, size: canvasSize)
    case .chestFly:
      chestFly(profile.equipment, variant: profile.variant, in: &context, size: canvasSize)
    case .squat:
      squat(profile.equipment, variant: profile.variant, in: &context, size: canvasSize)
    case .lunge:
      lunge(profile.variant, in: &context, size: canvasSize)
    case .hipHinge:
      hipHinge(profile.variant, in: &context, size: canvasSize)
    case .hipThrust:
      hipThrust(profile.equipment, in: &context, size: canvasSize)
    case .hipAbduction:
      hipAbduction(in: &context, size: canvasSize)
    case .pullUp:
      pullUp(profile.variant, in: &context, size: canvasSize)
    case .pulldown:
      pulldown(profile.variant, in: &context, size: canvasSize)
    case .straightArmPulldown:
      straightArmPulldown(in: &context, size: canvasSize)
    case .row:
      row(profile.equipment, variant: profile.variant, in: &context, size: canvasSize)
    case .pullover:
      pullover(profile.equipment, in: &context, size: canvasSize)
    case .shoulderPress:
      shoulderPress(profile.equipment, variant: profile.variant, in: &context, size: canvasSize)
    case .lateralRaise:
      lateralRaise(profile.equipment, in: &context, size: canvasSize)
    case .frontRaise:
      frontRaise(in: &context, size: canvasSize)
    case .reverseFly:
      reverseFly(profile.equipment, in: &context, size: canvasSize)
    case .facePull:
      facePull(in: &context, size: canvasSize)
    case .shrug:
      shrug(profile.equipment, in: &context, size: canvasSize)
    case .bicepsCurl:
      bicepsCurl(profile.equipment, variant: profile.variant, in: &context, size: canvasSize)
    case .tricepsPushdown:
      tricepsPushdown(profile.variant, in: &context, size: canvasSize)
    case .tricepsOverhead:
      tricepsOverhead(profile.equipment, in: &context, size: canvasSize)
    case .skullCrusher:
      skullCrusher(in: &context, size: canvasSize)
    case .legPress:
      legPress(in: &context, size: canvasSize)
    case .legExtension:
      legExtension(in: &context, size: canvasSize)
    case .legCurl:
      legCurl(in: &context, size: canvasSize)
    case .calfRaise:
      calfRaise(profile.equipment, in: &context, size: canvasSize)
    case .seatedCalfRaise:
      seatedCalfRaise(in: &context, size: canvasSize)
    case .plank:
      plank(in: &context, size: canvasSize)
    case .crunch:
      crunch(profile.equipment, variant: profile.variant, in: &context, size: canvasSize)
    case .legRaise:
      legRaise(in: &context, size: canvasSize)
    case .rotation:
      rotation(profile.equipment, in: &context, size: canvasSize)
    case .deadBug:
      deadBug(in: &context, size: canvasSize)
    case .birdDog:
      birdDog(in: &context, size: canvasSize)
    case .sidePlank:
      sidePlank(in: &context, size: canvasSize)
    case .backExtension:
      backExtension(in: &context, size: canvasSize)
    case .kettlebellSwing:
      kettlebellSwing(in: &context, size: canvasSize)
    case .carry:
      carry(in: &context, size: canvasSize)
    case .ballSlam:
      ballSlam(in: &context, size: canvasSize)
    case .sledPush:
      sledPush(in: &context, size: canvasSize)
    case .battleRope:
      battleRope(in: &context, size: canvasSize)
    case .generic:
      generic(in: &context, size: canvasSize)
    }
  }
}

extension ExerciseGlyphRenderer {
  fileprivate func benchPress(
    _ equipmentKind: ExerciseGlyphEquipment,
    variant: ExerciseGlyphVariant,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    if variant == .seatedMachine {
      // Seated chest press, side view: an upright back pad supports the torso
      // while bent elbows press the machine handles straight forward.
      equipment([(0.30, 0.27), (0.30, 0.69)], in: &context, size: size, width: 0.090)
      bench(from: (0.30, 0.68), to: (0.55, 0.68), in: &context, size: size)
      equipment([(0.86, 0.15), (0.86, 0.84)], in: &context, size: size, width: 0.034)
      equipment([(0.86, 0.25), (0.73, 0.41)], in: &context, size: size, width: 0.055)
      equipment([(0.70, 0.34), (0.70, 0.49)], in: &context, size: size, width: 0.055)
      equipmentBlock(center: (0.86, 0.66), in: &context, size: size)
      equipmentBlock(center: (0.86, 0.76), in: &context, size: size)

      head((0.43, 0.25), in: &context, size: size)
      body([(0.40, 0.34), (0.40, 0.62)], in: &context, size: size)
      body([(0.40, 0.62), (0.58, 0.70), (0.74, 0.82)], in: &context, size: size)
      body([(0.44, 0.39), (0.55, 0.49), (0.70, 0.39)], in: &context, size: size)
      body([(0.44, 0.44), (0.56, 0.53), (0.70, 0.45)], in: &context, size: size)
      accentArc(
        from: (0.51, 0.30), to: (0.75, 0.35), control: (0.64, 0.22), in: &context,
        size: size)
      return
    }

    if variant == .decline {
      bench(from: (0.18, 0.74), to: (0.80, 0.53), in: &context, size: size)
      head((0.30, 0.61), in: &context, size: size)
      body([(0.37, 0.62), (0.65, 0.54), (0.75, 0.59)], in: &context, size: size)
      body([(0.75, 0.59), (0.84, 0.78)], in: &context, size: size)
      body([(0.47, 0.58), (0.43, 0.38)], in: &context, size: size)
      body([(0.60, 0.54), (0.60, 0.36)], in: &context, size: size)
    } else if variant == .incline {
      bench(from: (0.18, 0.54), to: (0.82, 0.71), in: &context, size: size)
      head((0.27, 0.43), in: &context, size: size)
      body([(0.34, 0.48), (0.64, 0.60), (0.75, 0.69)], in: &context, size: size)
      body([(0.75, 0.69), (0.84, 0.83)], in: &context, size: size)
      body([(0.44, 0.52), (0.43, 0.34)], in: &context, size: size)
      body([(0.58, 0.57), (0.59, 0.36)], in: &context, size: size)
    } else {
      bench(from: (0.14, 0.69), to: (0.78, 0.69), in: &context, size: size)
      head((0.20, 0.54), in: &context, size: size)
      body([(0.28, 0.58), (0.61, 0.58), (0.72, 0.64)], in: &context, size: size)
      body([(0.72, 0.64), (0.80, 0.78), (0.90, 0.78)], in: &context, size: size)
      let leftHand: CGFloat = variant == .closeGrip ? 0.49 : 0.43
      let rightHand: CGFloat = variant == .closeGrip ? 0.54 : 0.59
      body([(0.40, 0.57), (0.38, 0.43), (leftHand, 0.30)], in: &context, size: size)
      body([(0.54, 0.57), (0.57, 0.43), (rightHand, 0.30)], in: &context, size: size)
    }

    if equipmentKind == .dumbbell {
      dumbbell(center: (0.43, 0.34), angle: 0, in: &context, size: size)
      dumbbell(center: (0.59, 0.34), angle: 0, in: &context, size: size)
    } else if equipmentKind == .machine {
      equipment([(0.30, 0.32), (0.72, 0.32)], in: &context, size: size, width: 0.055)
      equipment([(0.34, 0.23), (0.34, 0.43)], in: &context, size: size, width: 0.045)
      equipment([(0.68, 0.23), (0.68, 0.43)], in: &context, size: size, width: 0.045)
    } else {
      let barY: CGFloat = variant == .standard || variant == .closeGrip ? 0.27 : 0.32
      barbell(from: (0.12, barY), to: (0.86, barY), in: &context, size: size)
    }
  }

  fileprivate func pushUp(
    _ variant: ExerciseGlyphVariant, in context: inout GraphicsContext, size: CGSize
  ) {
    ground(from: (0.16, 0.82), to: (0.86, 0.82), in: &context, size: size)
    head((0.24, 0.46), in: &context, size: size)
    body([(0.32, 0.51), (0.63, 0.61), (0.83, 0.72)], in: &context, size: size)
    if variant == .closeGrip {
      body([(0.39, 0.54), (0.37, 0.68), (0.39, 0.78)], in: &context, size: size)
      body([(0.49, 0.57), (0.44, 0.69), (0.43, 0.78)], in: &context, size: size)
      equipment([(0.37, 0.78), (0.45, 0.78)], in: &context, size: size, width: 0.022)
    } else {
      body([(0.39, 0.54), (0.32, 0.77), (0.22, 0.77)], in: &context, size: size)
      body([(0.49, 0.57), (0.47, 0.78), (0.39, 0.78)], in: &context, size: size)
    }
    accentArc(from: (0.24, 0.35), to: (0.46, 0.42), control: (0.35, 0.27), in: &context, size: size)
  }

  fileprivate func dip(in context: inout GraphicsContext, size: CGSize) {
    equipment([(0.20, 0.52), (0.42, 0.52)], in: &context, size: size, width: 0.065)
    equipment([(0.58, 0.52), (0.80, 0.52)], in: &context, size: size, width: 0.065)
    head((0.50, 0.24), in: &context, size: size)
    body([(0.50, 0.33), (0.50, 0.62)], in: &context, size: size)
    body([(0.43, 0.38), (0.39, 0.52), (0.32, 0.52)], in: &context, size: size)
    body([(0.57, 0.38), (0.61, 0.52), (0.68, 0.52)], in: &context, size: size)
    body([(0.50, 0.62), (0.43, 0.74), (0.52, 0.83)], in: &context, size: size)
    body([(0.50, 0.62), (0.58, 0.74), (0.67, 0.82)], in: &context, size: size)
    accentArc(from: (0.82, 0.34), to: (0.82, 0.67), control: (0.91, 0.50), in: &context, size: size)
  }

  fileprivate func chestFly(
    _ equipmentKind: ExerciseGlyphEquipment,
    variant: ExerciseGlyphVariant,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    if variant == .low {
      head((0.50, 0.22), in: &context, size: size)
      body([(0.50, 0.31), (0.50, 0.68)], in: &context, size: size)
      body([(0.50, 0.68), (0.50, 0.85)], in: &context, size: size)
      body([(0.45, 0.40), (0.35, 0.50), (0.46, 0.36)], in: &context, size: size)
      body([(0.55, 0.40), (0.65, 0.50), (0.54, 0.36)], in: &context, size: size)
      equipment([(0.12, 0.82), (0.35, 0.50)], in: &context, size: size, width: 0.038)
      equipment([(0.88, 0.82), (0.65, 0.50)], in: &context, size: size, width: 0.038)
      accentArc(
        from: (0.28, 0.63), to: (0.44, 0.39), control: (0.28, 0.42), in: &context, size: size)
      accentArc(
        from: (0.72, 0.63), to: (0.56, 0.39), control: (0.72, 0.42), in: &context, size: size)
      return
    }

    if equipmentKind == .cable {
      head((0.50, 0.22), in: &context, size: size)
      body([(0.50, 0.31), (0.50, 0.67)], in: &context, size: size)
      body([(0.50, 0.67), (0.50, 0.85)], in: &context, size: size)
      body([(0.45, 0.39), (0.34, 0.48), (0.44, 0.51)], in: &context, size: size)
      body([(0.55, 0.39), (0.66, 0.48), (0.56, 0.51)], in: &context, size: size)
      equipment([(0.10, 0.19), (0.34, 0.48)], in: &context, size: size, width: 0.038)
      equipment([(0.90, 0.19), (0.66, 0.48)], in: &context, size: size, width: 0.038)
      accentArc(
        from: (0.27, 0.37), to: (0.43, 0.50), control: (0.31, 0.52), in: &context, size: size)
      accentArc(
        from: (0.73, 0.37), to: (0.57, 0.50), control: (0.69, 0.52), in: &context, size: size)
      return
    }

    if equipmentKind == .machine {
      bench(from: (0.39, 0.72), to: (0.65, 0.72), in: &context, size: size)
      head((0.50, 0.24), in: &context, size: size)
      body([(0.50, 0.33), (0.50, 0.67)], in: &context, size: size)
      body([(0.50, 0.67), (0.41, 0.76), (0.36, 0.85)], in: &context, size: size)
      body([(0.50, 0.67), (0.59, 0.76), (0.64, 0.85)], in: &context, size: size)
      body([(0.44, 0.40), (0.33, 0.48), (0.43, 0.51)], in: &context, size: size)
      body([(0.56, 0.40), (0.67, 0.48), (0.57, 0.51)], in: &context, size: size)
      equipment([(0.20, 0.29), (0.32, 0.48)], in: &context, size: size, width: 0.06)
      equipment([(0.80, 0.29), (0.68, 0.48)], in: &context, size: size, width: 0.06)
      equipment([(0.20, 0.29), (0.20, 0.82)], in: &context, size: size, width: 0.028)
      equipment([(0.80, 0.29), (0.80, 0.82)], in: &context, size: size, width: 0.028)
      accentArc(
        from: (0.26, 0.59), to: (0.40, 0.50), control: (0.28, 0.45), in: &context, size: size)
      return
    }

    bench(from: (0.22, 0.70), to: (0.80, 0.70), in: &context, size: size)
    head((0.31, 0.57), in: &context, size: size)
    body([(0.39, 0.60), (0.68, 0.60)], in: &context, size: size)
    body([(0.50, 0.59), (0.30, 0.37), (0.18, 0.42)], in: &context, size: size)
    body([(0.56, 0.59), (0.73, 0.37), (0.84, 0.42)], in: &context, size: size)

    dumbbell(center: (0.18, 0.42), angle: 88, in: &context, size: size)
    dumbbell(center: (0.84, 0.42), angle: 88, in: &context, size: size)
    accentArc(from: (0.26, 0.28), to: (0.76, 0.28), control: (0.51, 0.08), in: &context, size: size)
  }

  fileprivate func squat(
    _ equipmentKind: ExerciseGlyphEquipment,
    variant: ExerciseGlyphVariant,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    if variant == .hack {
      // Hack squat, side view: the torso stays against the inclined sled while
      // bent knees drive away from the fixed footplate.
      equipment([(0.26, 0.84), (0.70, 0.10)], in: &context, size: size, width: 0.032)
      equipment([(0.39, 0.86), (0.83, 0.12)], in: &context, size: size, width: 0.032)
      equipment([(0.43, 0.59), (0.64, 0.25)], in: &context, size: size, width: 0.090)
      equipment([(0.54, 0.31), (0.73, 0.38)], in: &context, size: size, width: 0.070)
      plate(center: (0.75, 0.39), scale: 0.64, in: &context, size: size)
      equipment([(0.33, 0.84), (0.83, 0.84)], in: &context, size: size, width: 0.075)

      head((0.67, 0.20), in: &context, size: size)
      body([(0.62, 0.29), (0.46, 0.57)], in: &context, size: size)
      body([(0.46, 0.57), (0.64, 0.65), (0.72, 0.81)], in: &context, size: size)
      body([(0.46, 0.57), (0.54, 0.70), (0.51, 0.81)], in: &context, size: size)
      body([(0.58, 0.36), (0.68, 0.39)], in: &context, size: size)
      body([(0.72, 0.81), (0.81, 0.81)], in: &context, size: size)
      body([(0.51, 0.81), (0.61, 0.81)], in: &context, size: size)
      accentArc(
        from: (0.24, 0.56), to: (0.36, 0.36), control: (0.20, 0.42), in: &context,
        size: size)
      return
    }

    ground(from: (0.18, 0.87), to: (0.84, 0.87), in: &context, size: size)
    head((0.59, 0.21), in: &context, size: size)
    body([(0.55, 0.30), (0.43, 0.53)], in: &context, size: size)
    body([(0.43, 0.53), (0.62, 0.67), (0.59, 0.83)], in: &context, size: size)
    body([(0.43, 0.53), (0.50, 0.69), (0.40, 0.83)], in: &context, size: size)
    body([(0.59, 0.83), (0.70, 0.83)], in: &context, size: size)
    body([(0.40, 0.83), (0.50, 0.83)], in: &context, size: size)
    if variant == .frontLoaded {
      body([(0.53, 0.36), (0.68, 0.37), (0.73, 0.29)], in: &context, size: size)
    } else {
      body([(0.53, 0.36), (0.63, 0.45), (0.54, 0.47)], in: &context, size: size)
    }

    if equipmentKind == .dumbbell {
      kettlebell(center: (0.64, 0.46), in: &context, size: size, scale: 0.68)
    } else {
      let barY: CGFloat = variant == .frontLoaded ? 0.34 : 0.31
      barbell(from: (0.24, barY), to: (0.82, barY), in: &context, size: size)
      if equipmentKind == .machine {
        equipment([(0.19, 0.14), (0.19, 0.82)], in: &context, size: size, width: 0.025)
        equipment([(0.85, 0.14), (0.85, 0.82)], in: &context, size: size, width: 0.025)
      }
    }
    if variant == .box {
      bench(from: (0.18, 0.60), to: (0.42, 0.60), in: &context, size: size)
    }
    accentArc(from: (0.34, 0.40), to: (0.40, 0.60), control: (0.25, 0.53), in: &context, size: size)
  }

  fileprivate func lunge(
    _ variant: ExerciseGlyphVariant, in context: inout GraphicsContext, size: CGSize
  ) {
    ground(from: (0.13, 0.87), to: (0.87, 0.87), in: &context, size: size)
    if variant == .stepUp {
      equipment([(0.58, 0.66), (0.88, 0.66), (0.88, 0.86)], in: &context, size: size, width: 0.06)
      head((0.48, 0.17), in: &context, size: size)
      body([(0.48, 0.26), (0.48, 0.50)], in: &context, size: size)
      body([(0.48, 0.50), (0.67, 0.53), (0.70, 0.63)], in: &context, size: size)
      body([(0.48, 0.50), (0.35, 0.67), (0.31, 0.84)], in: &context, size: size)
      body([(0.43, 0.34), (0.34, 0.49)], in: &context, size: size)
      body([(0.53, 0.34), (0.62, 0.46)], in: &context, size: size)
      accentArc(
        from: (0.72, 0.76), to: (0.72, 0.59), control: (0.80, 0.67), in: &context, size: size)
      return
    }

    if variant == .reverse {
      head((0.45, 0.19), in: &context, size: size)
      body([(0.48, 0.28), (0.52, 0.52)], in: &context, size: size)
      body([(0.52, 0.52), (0.32, 0.65), (0.32, 0.83)], in: &context, size: size)
      body([(0.52, 0.52), (0.66, 0.68), (0.80, 0.83)], in: &context, size: size)
      body([(0.32, 0.83), (0.21, 0.83)], in: &context, size: size)
      body([(0.80, 0.83), (0.70, 0.83)], in: &context, size: size)
      body([(0.53, 0.35), (0.61, 0.52)], in: &context, size: size)
      body([(0.45, 0.35), (0.39, 0.52)], in: &context, size: size)
      accentArc(
        from: (0.84, 0.57), to: (0.68, 0.68), control: (0.81, 0.73), in: &context, size: size)
      return
    }

    head((0.55, 0.19), in: &context, size: size)
    body([(0.52, 0.28), (0.48, 0.52)], in: &context, size: size)
    body([(0.48, 0.52), (0.68, 0.65), (0.68, 0.83)], in: &context, size: size)
    let rearFootX: CGFloat = 0.23
    let rearFootY: CGFloat = variant == .bulgarian ? 0.65 : 0.83
    body([(0.48, 0.52), (0.35, 0.68), (rearFootX, rearFootY)], in: &context, size: size)
    body([(0.68, 0.83), (0.79, 0.83)], in: &context, size: size)
    body([(rearFootX, rearFootY), (rearFootX + 0.10, rearFootY)], in: &context, size: size)
    body([(0.47, 0.35), (0.39, 0.52)], in: &context, size: size)
    body([(0.55, 0.35), (0.61, 0.52)], in: &context, size: size)
    if variant == .bulgarian {
      bench(from: (0.10, 0.70), to: (0.34, 0.70), in: &context, size: size)
    } else {
      accentArc(
        from: (0.19, 0.57), to: (0.32, 0.68), control: (0.20, 0.70), in: &context, size: size)
    }
  }

  fileprivate func hipHinge(
    _ variant: ExerciseGlyphVariant, in context: inout GraphicsContext, size: CGSize
  ) {
    ground(from: (0.12, 0.86), to: (0.90, 0.86), in: &context, size: size)
    head((0.34, 0.28), in: &context, size: size)
    body([(0.40, 0.35), (0.59, 0.52)], in: &context, size: size)
    let kneeY: CGFloat = variant == .romanian ? 0.76 : 0.70
    let leftFootX: CGFloat = variant == .sumo ? 0.37 : 0.47
    let rightFootX: CGFloat = variant == .sumo ? 0.84 : 0.75
    body([(0.59, 0.52), (0.52, kneeY), (leftFootX, 0.83)], in: &context, size: size)
    body([(0.59, 0.52), (0.70, kneeY), (rightFootX, 0.83)], in: &context, size: size)
    let barY: CGFloat = variant == .romanian ? 0.65 : 0.75
    body([(0.46, 0.40), (0.48, barY - 0.05)], in: &context, size: size)
    body([(0.53, 0.45), (0.62, barY - 0.05)], in: &context, size: size)
    barbell(from: (0.20, barY), to: (0.84, barY), in: &context, size: size)
    accentArc(from: (0.49, 0.24), to: (0.69, 0.47), control: (0.69, 0.23), in: &context, size: size)
  }

  fileprivate func hipThrust(
    _ equipmentKind: ExerciseGlyphEquipment, in context: inout GraphicsContext, size: CGSize
  ) {
    ground(from: (0.09, 0.84), to: (0.93, 0.84), in: &context, size: size)

    if equipmentKind == .bodyweight {
      // Glute bridge: shoulders remain on the floor while the hips form the
      // highest point between the upper body and bent knees.
      head((0.18, 0.70), in: &context, size: size)
      body([(0.27, 0.71), (0.57, 0.50)], in: &context, size: size)
      body([(0.57, 0.50), (0.73, 0.63), (0.75, 0.81), (0.87, 0.81)], in: &context, size: size)
      body([(0.55, 0.51), (0.66, 0.67), (0.64, 0.81), (0.76, 0.81)], in: &context, size: size)
      body([(0.31, 0.70), (0.47, 0.76)], in: &context, size: size)
      accentArc(
        from: (0.50, 0.67), to: (0.57, 0.48), control: (0.43, 0.53), in: &context,
        size: size)
      return
    }

    // Barbell hip thrust: the upper back is supported by a bench, the hips are
    // fully extended, and the bar sits directly across the hip crease.
    bench(from: (0.10, 0.62), to: (0.35, 0.62), in: &context, size: size)
    head((0.23, 0.49), in: &context, size: size)
    body([(0.31, 0.53), (0.58, 0.49)], in: &context, size: size)
    body([(0.58, 0.49), (0.75, 0.63), (0.77, 0.81), (0.89, 0.81)], in: &context, size: size)
    body([(0.56, 0.50), (0.68, 0.67), (0.66, 0.81), (0.78, 0.81)], in: &context, size: size)
    body([(0.36, 0.52), (0.52, 0.48)], in: &context, size: size)
    barbell(from: (0.40, 0.46), to: (0.73, 0.46), in: &context, size: size, plateScale: 0.72)
    accentArc(
      from: (0.49, 0.67), to: (0.58, 0.46), control: (0.43, 0.52), in: &context,
      size: size)
  }

  fileprivate func hipAbduction(in context: inout GraphicsContext, size: CGSize) {
    head((0.50, 0.20), in: &context, size: size)
    body([(0.50, 0.29), (0.50, 0.55)], in: &context, size: size)
    bench(from: (0.35, 0.60), to: (0.65, 0.60), in: &context, size: size)
    body([(0.50, 0.55), (0.29, 0.68), (0.25, 0.84)], in: &context, size: size)
    body([(0.50, 0.55), (0.71, 0.68), (0.75, 0.84)], in: &context, size: size)
    body([(0.44, 0.37), (0.32, 0.52)], in: &context, size: size)
    body([(0.56, 0.37), (0.68, 0.52)], in: &context, size: size)
    equipment([(0.17, 0.42), (0.17, 0.85)], in: &context, size: size, width: 0.034)
    equipment([(0.83, 0.42), (0.83, 0.85)], in: &context, size: size, width: 0.034)
    equipment([(0.18, 0.68), (0.30, 0.68)], in: &context, size: size, width: 0.075)
    equipment([(0.70, 0.68), (0.82, 0.68)], in: &context, size: size, width: 0.075)
    accentArc(
      from: (0.39, 0.61), to: (0.25, 0.62), control: (0.31, 0.54), in: &context,
      size: size)
    accentArc(
      from: (0.61, 0.61), to: (0.75, 0.62), control: (0.69, 0.54), in: &context,
      size: size)
  }

  fileprivate func pullUp(
    _ variant: ExerciseGlyphVariant, in context: inout GraphicsContext, size: CGSize
  ) {
    let barY: CGFloat = 0.14
    if variant == .neutralGrip {
      equipment([(0.30, barY), (0.70, barY)], in: &context, size: size, width: 0.065)
      equipment([(0.39, barY), (0.39, 0.23)], in: &context, size: size, width: 0.045)
      equipment([(0.61, barY), (0.61, 0.23)], in: &context, size: size, width: 0.045)
    } else {
      let gripInset: CGFloat = variant == .reverseGrip ? 0.14 : 0
      equipment(
        [(0.10 + gripInset, barY), (0.90 - gripInset, barY)], in: &context, size: size,
        width: 0.075
      )
    }
    head((0.50, 0.31), in: &context, size: size)
    body([(0.50, 0.40), (0.50, 0.66)], in: &context, size: size)
    let leftGrip: CGFloat = variant == .standard ? 0.22 : 0.39
    let rightGrip: CGFloat = variant == .standard ? 0.78 : 0.61
    let gripY: CGFloat = variant == .neutralGrip ? 0.23 : barY
    body(
      [(0.43, 0.42), (0.31, 0.35), (leftGrip, gripY)], in: &context, size: size)
    body(
      [(0.57, 0.42), (0.69, 0.35), (rightGrip, gripY)], in: &context, size: size)
    body([(0.50, 0.66), (0.43, 0.78), (0.51, 0.89)], in: &context, size: size)
    body([(0.50, 0.66), (0.57, 0.78), (0.49, 0.89)], in: &context, size: size)
    if variant == .reverseGrip {
      equipment([(0.33, 0.11), (0.41, 0.17)], in: &context, size: size, width: 0.022)
      equipment([(0.59, 0.17), (0.67, 0.11)], in: &context, size: size, width: 0.022)
    }
    accentArc(from: (0.91, 0.66), to: (0.91, 0.29), control: (0.99, 0.48), in: &context, size: size)
  }

  fileprivate func pulldown(
    _ variant: ExerciseGlyphVariant, in context: inout GraphicsContext, size: CGSize
  ) {
    let gripInset: CGFloat = variant == .standard ? 0 : 0.16
    equipment(
      [(0.18 + gripInset, 0.20), (0.82 - gripInset, 0.20)], in: &context, size: size, width: 0.065)
    equipment([(0.50, 0.08), (0.50, 0.20)], in: &context, size: size, width: 0.03)
    head((0.50, 0.43), in: &context, size: size)
    body([(0.50, 0.52), (0.50, 0.75)], in: &context, size: size)
    body([(0.43, 0.53), (0.34, 0.36), (0.24 + gripInset, 0.22)], in: &context, size: size)
    body([(0.57, 0.53), (0.66, 0.36), (0.76 - gripInset, 0.22)], in: &context, size: size)
    bench(from: (0.34, 0.77), to: (0.66, 0.77), in: &context, size: size)
    body([(0.50, 0.75), (0.44, 0.86)], in: &context, size: size)
    body([(0.50, 0.75), (0.57, 0.86)], in: &context, size: size)
    if variant == .reverseGrip {
      equipment([(0.37, 0.17), (0.43, 0.23)], in: &context, size: size, width: 0.022)
      equipment([(0.57, 0.23), (0.63, 0.17)], in: &context, size: size, width: 0.022)
    } else if variant == .closeGrip {
      equipment([(0.43, 0.17), (0.50, 0.24), (0.57, 0.17)], in: &context, size: size, width: 0.032)
    }
    accentArc(from: (0.88, 0.26), to: (0.88, 0.59), control: (0.96, 0.43), in: &context, size: size)
  }

  fileprivate func straightArmPulldown(in context: inout GraphicsContext, size: CGSize) {
    equipment([(0.10, 0.10), (0.10, 0.86)], in: &context, size: size, width: 0.034)
    equipment([(0.10, 0.12), (0.39, 0.57)], in: &context, size: size, width: 0.036)
    equipmentBlock(center: (0.10, 0.12), in: &context, size: size)

    head((0.62, 0.25), in: &context, size: size)
    body([(0.58, 0.34), (0.66, 0.61)], in: &context, size: size)
    body([(0.66, 0.61), (0.56, 0.74), (0.49, 0.86)], in: &context, size: size)
    body([(0.66, 0.61), (0.75, 0.73), (0.82, 0.86)], in: &context, size: size)
    body([(0.57, 0.38), (0.48, 0.49), (0.39, 0.57)], in: &context, size: size)
    body([(0.62, 0.40), (0.53, 0.52), (0.42, 0.60)], in: &context, size: size)
    equipment([(0.35, 0.58), (0.46, 0.58)], in: &context, size: size, width: 0.050)
    ground(from: (0.42, 0.89), to: (0.88, 0.89), in: &context, size: size)
    accentArc(
      from: (0.31, 0.31), to: (0.40, 0.55), control: (0.22, 0.47), in: &context,
      size: size)
  }

  fileprivate func row(
    _ equipmentKind: ExerciseGlyphEquipment,
    variant: ExerciseGlyphVariant,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    if equipmentKind == .cable {
      // Seated cable row: the athlete faces the low pulley with the hips visibly
      // supported, knees bent, feet braced, and the handle pulled toward the torso.
      equipment([(0.12, 0.18), (0.12, 0.84)], in: &context, size: size, width: 0.052)
      equipment([(0.08, 0.84), (0.21, 0.84)], in: &context, size: size, width: 0.052)
      equipmentBlock(center: (0.12, 0.67), in: &context, size: size)
      equipmentBlock(center: (0.12, 0.76), in: &context, size: size)
      equipment([(0.12, 0.49), (0.40, 0.51)], in: &context, size: size, width: 0.030)
      equipment([(0.35, 0.62), (0.42, 0.84)], in: &context, size: size, width: 0.050)

      bench(from: (0.54, 0.66), to: (0.75, 0.66), in: &context, size: size)
      head((0.67, 0.28), in: &context, size: size)
      body([(0.63, 0.36), (0.63, 0.61)], in: &context, size: size)
      body([(0.63, 0.61), (0.53, 0.69), (0.40, 0.78)], in: &context, size: size)
      body([(0.64, 0.61), (0.57, 0.73), (0.41, 0.83)], in: &context, size: size)
      body([(0.61, 0.40), (0.52, 0.47), (0.41, 0.51)], in: &context, size: size)
      body([(0.62, 0.45), (0.54, 0.52), (0.41, 0.51)], in: &context, size: size)
      equipment([(0.38, 0.47), (0.43, 0.55)], in: &context, size: size, width: 0.040)
      accentArc(
        from: (0.37, 0.38), to: (0.52, 0.45), control: (0.43, 0.31), in: &context,
        size: size)
      return
    }

    if equipmentKind == .bodyweight {
      // Inverted row: the athlete hangs below a fixed bar with a straight
      // shoulder-to-heel line and pulls the chest toward the bar.
      equipment([(0.13, 0.23), (0.87, 0.23)], in: &context, size: size, width: 0.065)
      equipment([(0.17, 0.23), (0.17, 0.85)], in: &context, size: size, width: 0.034)
      equipment([(0.83, 0.23), (0.83, 0.85)], in: &context, size: size, width: 0.034)
      ground(from: (0.10, 0.85), to: (0.92, 0.85), in: &context, size: size)

      head((0.28, 0.46), in: &context, size: size)
      body([(0.36, 0.50), (0.59, 0.64), (0.84, 0.78)], in: &context, size: size)
      body([(0.38, 0.51), (0.29, 0.37), (0.35, 0.23)], in: &context, size: size)
      body([(0.45, 0.55), (0.41, 0.37), (0.45, 0.23)], in: &context, size: size)
      body([(0.84, 0.78), (0.92, 0.81)], in: &context, size: size)
      accentArc(
        from: (0.23, 0.66), to: (0.34, 0.48), control: (0.18, 0.51), in: &context,
        size: size)
      return
    }

    head((0.33, 0.30), in: &context, size: size)
    body([(0.40, 0.36), (0.62, 0.52)], in: &context, size: size)
    body([(0.62, 0.52), (0.54, 0.69), (0.48, 0.84)], in: &context, size: size)
    body([(0.62, 0.52), (0.72, 0.68), (0.78, 0.84)], in: &context, size: size)

    if variant == .singleArm {
      bench(from: (0.16, 0.61), to: (0.47, 0.61), in: &context, size: size)
      body([(0.45, 0.40), (0.34, 0.59)], in: &context, size: size)
      body([(0.52, 0.44), (0.62, 0.63)], in: &context, size: size)
      dumbbell(center: (0.64, 0.68), angle: 8, in: &context, size: size)
    } else if variant == .chestSupported {
      bench(from: (0.27, 0.73), to: (0.58, 0.40), in: &context, size: size)
      body([(0.47, 0.41), (0.53, 0.61)], in: &context, size: size)
      body([(0.52, 0.43), (0.63, 0.61)], in: &context, size: size)
      barbell(from: (0.34, 0.67), to: (0.80, 0.67), in: &context, size: size, plateScale: 0.66)
    } else if variant == .tBar {
      body([(0.45, 0.40), (0.51, 0.58)], in: &context, size: size)
      body([(0.52, 0.44), (0.60, 0.58)], in: &context, size: size)
      equipment([(0.14, 0.80), (0.58, 0.62), (0.84, 0.51)], in: &context, size: size, width: 0.045)
      plate(center: (0.84, 0.51), scale: 0.72, in: &context, size: size)
      equipment([(0.48, 0.57), (0.64, 0.57)], in: &context, size: size, width: 0.055)
    } else {
      body([(0.45, 0.40), (0.50, 0.62)], in: &context, size: size)
      body([(0.52, 0.44), (0.60, 0.62)], in: &context, size: size)
      if equipmentKind == .dumbbell {
        dumbbell(center: (0.50, 0.67), angle: 12, in: &context, size: size)
      } else {
        barbell(from: (0.24, 0.69), to: (0.82, 0.69), in: &context, size: size, plateScale: 0.76)
      }
    }
    accentArc(from: (0.24, 0.77), to: (0.48, 0.55), control: (0.29, 0.57), in: &context, size: size)
  }

  fileprivate func pullover(
    _ equipmentKind: ExerciseGlyphEquipment, in context: inout GraphicsContext, size: CGSize
  ) {
    bench(from: (0.26, 0.68), to: (0.82, 0.68), in: &context, size: size)
    head((0.32, 0.56), in: &context, size: size)
    body([(0.40, 0.59), (0.70, 0.59)], in: &context, size: size)
    body([(0.45, 0.58), (0.28, 0.36), (0.18, 0.26)], in: &context, size: size)
    if equipmentKind == .cable {
      equipment([(0.08, 0.12), (0.18, 0.26)], in: &context, size: size, width: 0.035)
    } else {
      dumbbell(center: (0.16, 0.24), angle: 42, in: &context, size: size)
    }
    accentArc(from: (0.18, 0.43), to: (0.48, 0.27), control: (0.28, 0.18), in: &context, size: size)
  }
}

extension ExerciseGlyphRenderer {
  fileprivate func shoulderPress(
    _ equipmentKind: ExerciseGlyphEquipment,
    variant: ExerciseGlyphVariant,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    if variant == .arnold {
      // Arnold press starts seated with the dumbbells together in front of the
      // face; the paired arcs make the outward rotation distinct from a press.
      equipment([(0.30, 0.31), (0.30, 0.70)], in: &context, size: size, width: 0.080)
      bench(from: (0.30, 0.70), to: (0.56, 0.70), in: &context, size: size)
      head((0.47, 0.34), in: &context, size: size)
      body([(0.45, 0.43), (0.45, 0.66)], in: &context, size: size)
      body([(0.45, 0.66), (0.63, 0.72), (0.74, 0.84)], in: &context, size: size)
      body([(0.40, 0.47), (0.34, 0.39), (0.42, 0.32)], in: &context, size: size)
      body([(0.50, 0.47), (0.56, 0.39), (0.48, 0.32)], in: &context, size: size)
      dumbbell(center: (0.41, 0.28), angle: 88, in: &context, size: size)
      dumbbell(center: (0.49, 0.28), angle: 92, in: &context, size: size)
      accentArc(
        from: (0.31, 0.43), to: (0.36, 0.19), control: (0.22, 0.27), in: &context,
        size: size)
      accentArc(
        from: (0.59, 0.43), to: (0.54, 0.19), control: (0.68, 0.27), in: &context,
        size: size)
      return
    }

    if variant == .military {
      // Military press remains a strict standing barbell press.
      ground(from: (0.25, 0.87), to: (0.75, 0.87), in: &context, size: size)
      head((0.50, 0.34), in: &context, size: size)
      body([(0.50, 0.43), (0.50, 0.66)], in: &context, size: size)
      body([(0.50, 0.66), (0.41, 0.84)], in: &context, size: size)
      body([(0.50, 0.66), (0.59, 0.84)], in: &context, size: size)
      body([(0.44, 0.47), (0.37, 0.32), (0.40, 0.18)], in: &context, size: size)
      body([(0.56, 0.47), (0.63, 0.32), (0.60, 0.18)], in: &context, size: size)
      barbell(from: (0.19, 0.14), to: (0.81, 0.14), in: &context, size: size)
      return
    }

    // Other shoulder presses are seated so they no longer read as duplicate
    // military presses. The back pad and bent leg provide the seat cue.
    equipment([(0.29, 0.31), (0.29, 0.71)], in: &context, size: size, width: 0.080)
    bench(from: (0.29, 0.70), to: (0.55, 0.70), in: &context, size: size)
    head((0.45, 0.35), in: &context, size: size)
    body([(0.43, 0.44), (0.43, 0.66)], in: &context, size: size)
    body([(0.43, 0.66), (0.61, 0.72), (0.74, 0.84)], in: &context, size: size)
    body(
      [(0.38, 0.47), (0.32, 0.32), (0.34, 0.18)], in: &context, size: size)
    body(
      [(0.48, 0.47), (0.58, 0.32), (0.58, 0.18)], in: &context, size: size)

    if equipmentKind == .dumbbell {
      dumbbell(center: (0.34, 0.15), angle: 0, in: &context, size: size)
      dumbbell(center: (0.58, 0.15), angle: 0, in: &context, size: size)
    } else {
      barbell(from: (0.13, 0.14), to: (0.78, 0.14), in: &context, size: size)
      if equipmentKind == .machine {
        equipment([(0.11, 0.10), (0.11, 0.84)], in: &context, size: size, width: 0.028)
        equipment([(0.80, 0.10), (0.80, 0.84)], in: &context, size: size, width: 0.028)
        equipmentBlock(center: (0.80, 0.70), in: &context, size: size)
      }
    }
  }

  fileprivate func lateralRaise(
    _ equipmentKind: ExerciseGlyphEquipment, in context: inout GraphicsContext, size: CGSize
  ) {
    head((0.50, 0.22), in: &context, size: size)
    body([(0.50, 0.31), (0.50, 0.64)], in: &context, size: size)
    body([(0.50, 0.64), (0.50, 0.84)], in: &context, size: size)
    if equipmentKind == .cable {
      body([(0.56, 0.39), (0.75, 0.39), (0.87, 0.36)], in: &context, size: size)
      body([(0.44, 0.39), (0.38, 0.63)], in: &context, size: size)
      equipment([(0.13, 0.83), (0.38, 0.63)], in: &context, size: size, width: 0.035)
      equipment([(0.13, 0.73), (0.13, 0.87)], in: &context, size: size, width: 0.07)
      accentArc(
        from: (0.78, 0.57), to: (0.88, 0.39), control: (0.91, 0.51), in: &context, size: size)
    } else {
      body([(0.44, 0.39), (0.23, 0.39), (0.12, 0.36)], in: &context, size: size)
      body([(0.56, 0.39), (0.77, 0.39), (0.88, 0.36)], in: &context, size: size)
      dumbbell(center: (0.11, 0.34), angle: 90, in: &context, size: size)
      dumbbell(center: (0.89, 0.34), angle: 90, in: &context, size: size)
      accentArc(
        from: (0.18, 0.57), to: (0.11, 0.39), control: (0.09, 0.51), in: &context, size: size)
      accentArc(
        from: (0.82, 0.57), to: (0.89, 0.39), control: (0.91, 0.51), in: &context, size: size)
    }
  }

  fileprivate func frontRaise(in context: inout GraphicsContext, size: CGSize) {
    head((0.43, 0.22), in: &context, size: size)
    body([(0.43, 0.31), (0.43, 0.65)], in: &context, size: size)
    body([(0.43, 0.39), (0.62, 0.39), (0.78, 0.37)], in: &context, size: size)
    body([(0.43, 0.65), (0.43, 0.85)], in: &context, size: size)
    dumbbell(center: (0.81, 0.36), angle: 90, in: &context, size: size)
    accentArc(from: (0.74, 0.62), to: (0.82, 0.40), control: (0.88, 0.54), in: &context, size: size)
  }

  fileprivate func reverseFly(
    _ equipmentKind: ExerciseGlyphEquipment, in context: inout GraphicsContext, size: CGSize
  ) {
    if equipmentKind == .machine {
      // Reverse pec deck, rear view: the athlete is visibly seated while both
      // arms open outward against the machine handles.
      bench(from: (0.38, 0.70), to: (0.62, 0.70), in: &context, size: size)
      head((0.50, 0.24), in: &context, size: size)
      body([(0.50, 0.33), (0.50, 0.65)], in: &context, size: size)
      body([(0.50, 0.65), (0.39, 0.74), (0.34, 0.84)], in: &context, size: size)
      body([(0.50, 0.65), (0.61, 0.74), (0.66, 0.84)], in: &context, size: size)
      body([(0.44, 0.40), (0.29, 0.35), (0.16, 0.31)], in: &context, size: size)
      body([(0.56, 0.40), (0.71, 0.35), (0.84, 0.31)], in: &context, size: size)
      equipment([(0.16, 0.21), (0.16, 0.82)], in: &context, size: size, width: 0.028)
      equipment([(0.84, 0.21), (0.84, 0.82)], in: &context, size: size, width: 0.028)
      equipment([(0.12, 0.31), (0.21, 0.31)], in: &context, size: size, width: 0.07)
      equipment([(0.79, 0.31), (0.88, 0.31)], in: &context, size: size, width: 0.07)
      accentArc(
        from: (0.31, 0.49), to: (0.16, 0.34), control: (0.18, 0.49), in: &context, size: size)
      return
    }

    head((0.35, 0.31), in: &context, size: size)
    body([(0.42, 0.36), (0.63, 0.50)], in: &context, size: size)
    body([(0.63, 0.50), (0.54, 0.68), (0.48, 0.84)], in: &context, size: size)
    body([(0.63, 0.50), (0.72, 0.68), (0.79, 0.84)], in: &context, size: size)
    body([(0.49, 0.41), (0.30, 0.52), (0.18, 0.48)], in: &context, size: size)
    body([(0.52, 0.43), (0.67, 0.31), (0.81, 0.26)], in: &context, size: size)
    dumbbell(center: (0.16, 0.48), angle: 88, in: &context, size: size)
    dumbbell(center: (0.83, 0.25), angle: 88, in: &context, size: size)
    accentArc(from: (0.24, 0.67), to: (0.16, 0.51), control: (0.12, 0.62), in: &context, size: size)
    accentArc(from: (0.67, 0.45), to: (0.82, 0.29), control: (0.76, 0.40), in: &context, size: size)
  }

  fileprivate func facePull(in context: inout GraphicsContext, size: CGSize) {
    // High-pulley rope face pull, side view. The cable meets the hands beside
    // the face while both elbows stay high and wide.
    equipment([(0.11, 0.12), (0.11, 0.86)], in: &context, size: size, width: 0.040)
    equipment([(0.07, 0.86), (0.18, 0.86)], in: &context, size: size, width: 0.050)
    equipmentBlock(center: (0.11, 0.18), in: &context, size: size)
    equipmentBlock(center: (0.11, 0.74), in: &context, size: size)
    equipment([(0.11, 0.24), (0.53, 0.31)], in: &context, size: size, width: 0.030)
    equipment([(0.53, 0.31), (0.63, 0.27)], in: &context, size: size, width: 0.042)
    equipment([(0.53, 0.31), (0.63, 0.36)], in: &context, size: size, width: 0.042)

    head((0.70, 0.31), in: &context, size: size)
    body([(0.70, 0.40), (0.72, 0.67)], in: &context, size: size)
    body([(0.67, 0.41), (0.50, 0.35), (0.63, 0.27)], in: &context, size: size)
    body([(0.69, 0.46), (0.52, 0.47), (0.63, 0.36)], in: &context, size: size)
    body([(0.72, 0.67), (0.64, 0.84)], in: &context, size: size)
    body([(0.72, 0.67), (0.82, 0.84)], in: &context, size: size)
    ground(from: (0.56, 0.87), to: (0.90, 0.87), in: &context, size: size)
    accentArc(
      from: (0.28, 0.48), to: (0.55, 0.36), control: (0.39, 0.30), in: &context,
      size: size)
  }

  fileprivate func shrug(
    _ equipmentKind: ExerciseGlyphEquipment, in context: inout GraphicsContext, size: CGSize
  ) {
    head((0.50, 0.22), in: &context, size: size)
    body([(0.50, 0.31), (0.50, 0.65)], in: &context, size: size)
    body([(0.44, 0.38), (0.34, 0.65)], in: &context, size: size)
    body([(0.56, 0.38), (0.66, 0.65)], in: &context, size: size)
    body([(0.50, 0.65), (0.50, 0.85)], in: &context, size: size)
    if equipmentKind == .dumbbell {
      dumbbell(center: (0.33, 0.69), angle: 88, in: &context, size: size)
      dumbbell(center: (0.67, 0.69), angle: 88, in: &context, size: size)
    } else {
      barbell(from: (0.17, 0.70), to: (0.83, 0.70), in: &context, size: size)
    }
    accentArc(from: (0.34, 0.38), to: (0.42, 0.28), control: (0.32, 0.27), in: &context, size: size)
    accentArc(from: (0.66, 0.38), to: (0.58, 0.28), control: (0.68, 0.27), in: &context, size: size)
  }

  fileprivate func bicepsCurl(
    _ equipmentKind: ExerciseGlyphEquipment,
    variant: ExerciseGlyphVariant,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    if variant == .concentration {
      bench(from: (0.28, 0.66), to: (0.60, 0.66), in: &context, size: size)
      head((0.42, 0.25), in: &context, size: size)
      body([(0.46, 0.33), (0.56, 0.57)], in: &context, size: size)
      body([(0.56, 0.57), (0.72, 0.69), (0.78, 0.84)], in: &context, size: size)
      body([(0.56, 0.57), (0.43, 0.72), (0.35, 0.84)], in: &context, size: size)
      body([(0.48, 0.39), (0.56, 0.54), (0.47, 0.65)], in: &context, size: size)
      dumbbell(center: (0.45, 0.69), angle: 82, in: &context, size: size)
      accentArc(
        from: (0.34, 0.58), to: (0.47, 0.43), control: (0.32, 0.42), in: &context, size: size)
      return
    }

    if variant == .preacher {
      head((0.43, 0.22), in: &context, size: size)
      body([(0.43, 0.31), (0.43, 0.63)], in: &context, size: size)
      bench(from: (0.50, 0.48), to: (0.73, 0.68), in: &context, size: size)
      body([(0.48, 0.38), (0.60, 0.51), (0.55, 0.66)], in: &context, size: size)
      body([(0.43, 0.63), (0.43, 0.84)], in: &context, size: size)
      dumbbell(center: (0.54, 0.69), angle: 0, in: &context, size: size)
      accentArc(
        from: (0.73, 0.45), to: (0.61, 0.57), control: (0.73, 0.59), in: &context, size: size)
      return
    }

    head((0.50, 0.20), in: &context, size: size)
    if variant == .incline {
      bench(from: (0.30, 0.74), to: (0.48, 0.35), in: &context, size: size)
      body([(0.48, 0.29), (0.52, 0.64)], in: &context, size: size)
    } else {
      body([(0.50, 0.29), (0.50, 0.64)], in: &context, size: size)
    }
    body([(0.50, 0.64), (0.50, 0.85)], in: &context, size: size)
    if variant == .hammer {
      body([(0.43, 0.38), (0.37, 0.56), (0.40, 0.67)], in: &context, size: size)
      body([(0.57, 0.38), (0.63, 0.56), (0.60, 0.67)], in: &context, size: size)
    } else {
      body([(0.43, 0.38), (0.36, 0.58), (0.46, 0.48)], in: &context, size: size)
      body([(0.57, 0.38), (0.64, 0.58), (0.54, 0.48)], in: &context, size: size)
    }

    if equipmentKind == .cable {
      equipment([(0.22, 0.84), (0.45, 0.49)], in: &context, size: size, width: 0.032)
      equipment([(0.22, 0.84), (0.55, 0.49)], in: &context, size: size, width: 0.032)
    } else if equipmentKind == .dumbbell {
      if variant == .hammer {
        dumbbell(center: (0.40, 0.70), angle: 88, in: &context, size: size)
        dumbbell(center: (0.60, 0.70), angle: 92, in: &context, size: size)
      } else {
        dumbbell(center: (0.46, 0.46), angle: 0, in: &context, size: size)
        dumbbell(center: (0.54, 0.46), angle: 0, in: &context, size: size)
      }
    } else {
      barbell(from: (0.34, 0.46), to: (0.66, 0.46), in: &context, size: size, plateScale: 0.62)
      if variant == .reverseGrip {
        equipment([(0.42, 0.42), (0.46, 0.50)], in: &context, size: size, width: 0.018)
        equipment([(0.54, 0.50), (0.58, 0.42)], in: &context, size: size, width: 0.018)
      }
    }
    accentArc(from: (0.31, 0.67), to: (0.43, 0.49), control: (0.29, 0.52), in: &context, size: size)
  }

  fileprivate func tricepsPushdown(
    _ variant: ExerciseGlyphVariant, in context: inout GraphicsContext, size: CGSize
  ) {
    equipment([(0.13, 0.12), (0.13, 0.85)], in: &context, size: size, width: 0.042)
    equipment([(0.09, 0.85), (0.22, 0.85)], in: &context, size: size, width: 0.055)
    equipment([(0.13, 0.12), (0.50, 0.12)], in: &context, size: size, width: 0.042)
    equipmentBlock(center: (0.13, 0.66), in: &context, size: size)
    equipmentBlock(center: (0.13, 0.75), in: &context, size: size)
    equipment([(0.50, 0.12), (0.50, 0.47)], in: &context, size: size, width: 0.030)

    head((0.69, 0.23), in: &context, size: size)
    body([(0.65, 0.32), (0.62, 0.62)], in: &context, size: size)
    body([(0.62, 0.62), (0.54, 0.84)], in: &context, size: size)
    body([(0.62, 0.62), (0.72, 0.84)], in: &context, size: size)
    if variant == .singleArm {
      body([(0.62, 0.38), (0.54, 0.50), (0.51, 0.69)], in: &context, size: size)
      body([(0.69, 0.39), (0.72, 0.59)], in: &context, size: size)
      equipment([(0.46, 0.69), (0.55, 0.69)], in: &context, size: size, width: 0.050)
    } else {
      body([(0.61, 0.38), (0.53, 0.49), (0.46, 0.68)], in: &context, size: size)
      body([(0.68, 0.39), (0.61, 0.50), (0.57, 0.68)], in: &context, size: size)
      if variant == .rope {
        equipment(
          [(0.50, 0.47), (0.47, 0.57), (0.42, 0.70)], in: &context, size: size,
          width: 0.035)
        equipment(
          [(0.50, 0.47), (0.53, 0.57), (0.61, 0.70)], in: &context, size: size,
          width: 0.035)
        equipmentBlock(center: (0.42, 0.72), in: &context, size: size)
        equipmentBlock(center: (0.61, 0.72), in: &context, size: size)
      } else {
        equipment([(0.40, 0.69), (0.63, 0.69)], in: &context, size: size, width: 0.055)
      }
    }
    accentArc(
      from: (0.32, 0.42), to: (0.32, 0.69), control: (0.23, 0.55), in: &context,
      size: size)
  }

  fileprivate func tricepsOverhead(
    _ equipmentKind: ExerciseGlyphEquipment, in context: inout GraphicsContext, size: CGSize
  ) {
    head((0.50, 0.33), in: &context, size: size)
    body([(0.50, 0.42), (0.50, 0.70)], in: &context, size: size)
    body([(0.50, 0.70), (0.50, 0.86)], in: &context, size: size)
    body([(0.44, 0.46), (0.35, 0.27), (0.44, 0.16)], in: &context, size: size)
    body([(0.56, 0.46), (0.65, 0.27), (0.56, 0.16)], in: &context, size: size)
    if equipmentKind == .cable {
      equipment([(0.50, 0.06), (0.50, 0.16)], in: &context, size: size, width: 0.035)
    } else {
      dumbbell(center: (0.50, 0.13), angle: 0, in: &context, size: size)
    }
    accentArc(from: (0.73, 0.36), to: (0.61, 0.17), control: (0.76, 0.19), in: &context, size: size)
  }

  fileprivate func skullCrusher(in context: inout GraphicsContext, size: CGSize) {
    bench(from: (0.18, 0.70), to: (0.82, 0.70), in: &context, size: size)
    head((0.28, 0.58), in: &context, size: size)
    body([(0.36, 0.61), (0.68, 0.61)], in: &context, size: size)
    body([(0.46, 0.59), (0.48, 0.38), (0.37, 0.28)], in: &context, size: size)
    body([(0.58, 0.59), (0.59, 0.38), (0.48, 0.28)], in: &context, size: size)
    barbell(from: (0.28, 0.24), to: (0.58, 0.24), in: &context, size: size, plateScale: 0.60)
    accentArc(from: (0.68, 0.28), to: (0.57, 0.45), control: (0.72, 0.43), in: &context, size: size)
  }
}

extension ExerciseGlyphRenderer {
  fileprivate func legPress(in context: inout GraphicsContext, size: CGSize) {
    // 45-degree sled press: the back stays on the inclined pad, both knees are
    // bent, and both feet clearly contact the moving footplate.
    equipment([(0.54, 0.86), (0.86, 0.12)], in: &context, size: size, width: 0.032)
    equipment([(0.66, 0.87), (0.96, 0.20)], in: &context, size: size, width: 0.032)
    equipment([(0.77, 0.24), (0.93, 0.37)], in: &context, size: size, width: 0.085)
    equipmentBlock(center: (0.88, 0.22), in: &context, size: size)

    equipment([(0.17, 0.75), (0.39, 0.48)], in: &context, size: size, width: 0.090)
    bench(from: (0.30, 0.72), to: (0.52, 0.72), in: &context, size: size)
    head((0.31, 0.43), in: &context, size: size)
    body([(0.37, 0.49), (0.51, 0.66)], in: &context, size: size)
    body([(0.51, 0.66), (0.65, 0.53), (0.80, 0.31)], in: &context, size: size)
    body([(0.50, 0.64), (0.69, 0.61), (0.84, 0.35)], in: &context, size: size)
    body([(0.40, 0.52), (0.30, 0.61)], in: &context, size: size)
    accentArc(
      from: (0.59, 0.32), to: (0.79, 0.24), control: (0.68, 0.17), in: &context,
      size: size)
  }

  fileprivate func legExtension(in context: inout GraphicsContext, size: CGSize) {
    head((0.34, 0.23), in: &context, size: size)
    body([(0.34, 0.32), (0.34, 0.57)], in: &context, size: size)
    bench(from: (0.25, 0.59), to: (0.57, 0.59), in: &context, size: size)
    body([(0.34, 0.57), (0.57, 0.60), (0.79, 0.60)], in: &context, size: size)
    equipment([(0.76, 0.52), (0.82, 0.68)], in: &context, size: size, width: 0.07)
    equipment([(0.24, 0.84), (0.24, 0.58)], in: &context, size: size, width: 0.035)
    accentArc(from: (0.61, 0.77), to: (0.80, 0.63), control: (0.78, 0.81), in: &context, size: size)
  }

  fileprivate func legCurl(in context: inout GraphicsContext, size: CGSize) {
    bench(from: (0.16, 0.61), to: (0.78, 0.61), in: &context, size: size)
    head((0.24, 0.49), in: &context, size: size)
    body([(0.32, 0.52), (0.63, 0.53)], in: &context, size: size)
    body([(0.63, 0.53), (0.74, 0.42), (0.76, 0.25)], in: &context, size: size)
    equipment([(0.70, 0.22), (0.83, 0.22)], in: &context, size: size, width: 0.075)
    equipment([(0.18, 0.84), (0.18, 0.62)], in: &context, size: size, width: 0.035)
    accentArc(from: (0.88, 0.50), to: (0.80, 0.26), control: (0.93, 0.32), in: &context, size: size)
  }

  fileprivate func calfRaise(
    _ equipmentKind: ExerciseGlyphEquipment, in context: inout GraphicsContext, size: CGSize
  ) {
    if equipmentKind == .machine {
      // Standing calf raise, side view: straight legs and elevated heels make
      // the ankle movement readable even at the compact picker size.
      equipment([(0.80, 0.14), (0.80, 0.86)], in: &context, size: size, width: 0.034)
      equipment([(0.73, 0.14), (0.86, 0.14)], in: &context, size: size, width: 0.050)
      equipment([(0.43, 0.34), (0.67, 0.34)], in: &context, size: size, width: 0.075)
      equipment([(0.58, 0.87), (0.86, 0.87)], in: &context, size: size, width: 0.065)

      head((0.53, 0.20), in: &context, size: size)
      body([(0.53, 0.29), (0.52, 0.58)], in: &context, size: size)
      body([(0.52, 0.58), (0.48, 0.77), (0.45, 0.81), (0.61, 0.85)], in: &context, size: size)
      body([(0.54, 0.58), (0.55, 0.77), (0.52, 0.81), (0.67, 0.85)], in: &context, size: size)
      body([(0.55, 0.38), (0.65, 0.43), (0.78, 0.39)], in: &context, size: size)
      accentArc(
        from: (0.31, 0.78), to: (0.31, 0.55), control: (0.22, 0.66), in: &context,
        size: size)
      return
    }

    // Bodyweight calf raise, side view: hands use a fixed support while the
    // forefeet stay on a step and the heels rise above it.
    equipment([(0.77, 0.18), (0.77, 0.85)], in: &context, size: size, width: 0.034)
    equipment([(0.62, 0.84), (0.88, 0.84)], in: &context, size: size, width: 0.070)
    head((0.48, 0.20), in: &context, size: size)
    body([(0.50, 0.29), (0.53, 0.59)], in: &context, size: size)
    body([(0.53, 0.59), (0.56, 0.76), (0.52, 0.81), (0.66, 0.83)], in: &context, size: size)
    body([(0.55, 0.59), (0.62, 0.76), (0.58, 0.81), (0.72, 0.83)], in: &context, size: size)
    body([(0.54, 0.38), (0.64, 0.43), (0.76, 0.39)], in: &context, size: size)
    accentArc(
      from: (0.35, 0.80), to: (0.35, 0.61), control: (0.27, 0.70), in: &context,
      size: size)
  }

  fileprivate func seatedCalfRaise(in context: inout GraphicsContext, size: CGSize) {
    // Seated calf machine: knees are held under the thigh pad while only the
    // balls of the feet remain on the front step and the heels lift freely.
    equipment([(0.23, 0.29), (0.23, 0.66)], in: &context, size: size, width: 0.080)
    bench(from: (0.22, 0.64), to: (0.48, 0.64), in: &context, size: size)
    head((0.35, 0.25), in: &context, size: size)
    body([(0.35, 0.34), (0.36, 0.59)], in: &context, size: size)
    body([(0.36, 0.59), (0.60, 0.62), (0.60, 0.79), (0.54, 0.84)], in: &context, size: size)
    body([(0.39, 0.59), (0.66, 0.64), (0.69, 0.79), (0.63, 0.84)], in: &context, size: size)
    equipment([(0.46, 0.54), (0.70, 0.54)], in: &context, size: size, width: 0.085)
    equipment([(0.50, 0.86), (0.75, 0.86)], in: &context, size: size, width: 0.070)
    equipment([(0.74, 0.55), (0.74, 0.86)], in: &context, size: size, width: 0.034)
    accentArc(
      from: (0.85, 0.81), to: (0.85, 0.64), control: (0.92, 0.72), in: &context,
      size: size)
  }

  fileprivate func plank(in context: inout GraphicsContext, size: CGSize) {
    ground(from: (0.08, 0.82), to: (0.95, 0.82), in: &context, size: size)
    head((0.17, 0.49), in: &context, size: size)

    // Forearm plank, side view: shoulders, hips, and heels stay aligned while
    // both bent arms rest horizontally on the floor and only the toes support the rear.
    body([(0.26, 0.54), (0.56, 0.55), (0.82, 0.61)], in: &context, size: size)
    body([(0.28, 0.55), (0.30, 0.74), (0.13, 0.77)], in: &context, size: size)
    body([(0.35, 0.55), (0.38, 0.74), (0.21, 0.77)], in: &context, size: size)
    body([(0.82, 0.61), (0.91, 0.78), (0.95, 0.78)], in: &context, size: size)
  }

  fileprivate func crunch(
    _ equipmentKind: ExerciseGlyphEquipment,
    variant: ExerciseGlyphVariant,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    if equipmentKind == .cable {
      equipment([(0.38, 0.08), (0.42, 0.31)], in: &context, size: size, width: 0.035)
      head((0.51, 0.32), in: &context, size: size)
      body([(0.50, 0.41), (0.58, 0.61), (0.51, 0.70)], in: &context, size: size)
      body([(0.51, 0.70), (0.38, 0.78), (0.31, 0.85)], in: &context, size: size)
      body([(0.51, 0.70), (0.64, 0.78), (0.71, 0.85)], in: &context, size: size)
      body([(0.46, 0.43), (0.41, 0.32), (0.48, 0.27)], in: &context, size: size)
      body([(0.54, 0.43), (0.49, 0.33), (0.42, 0.31)], in: &context, size: size)
      ground(from: (0.22, 0.87), to: (0.80, 0.87), in: &context, size: size)
      accentArc(
        from: (0.70, 0.40), to: (0.60, 0.63), control: (0.76, 0.57), in: &context, size: size)
      return
    }

    ground(from: (0.12, 0.84), to: (0.88, 0.84), in: &context, size: size)
    if variant == .reverse {
      head((0.24, 0.70), in: &context, size: size)
      body([(0.32, 0.72), (0.53, 0.72), (0.62, 0.61)], in: &context, size: size)
      body([(0.62, 0.61), (0.68, 0.41), (0.56, 0.28)], in: &context, size: size)
      body([(0.62, 0.61), (0.77, 0.49), (0.78, 0.31)], in: &context, size: size)
      body([(0.37, 0.70), (0.27, 0.78)], in: &context, size: size)
      accentArc(
        from: (0.80, 0.68), to: (0.69, 0.37), control: (0.91, 0.45), in: &context, size: size)
      return
    }
    head((0.33, 0.45), in: &context, size: size)
    body([(0.39, 0.51), (0.52, 0.65), (0.60, 0.76)], in: &context, size: size)
    body([(0.60, 0.76), (0.72, 0.61), (0.84, 0.77)], in: &context, size: size)
    body([(0.40, 0.53), (0.29, 0.60)], in: &context, size: size)
    accentArc(from: (0.24, 0.68), to: (0.37, 0.47), control: (0.19, 0.49), in: &context, size: size)
  }

  fileprivate func legRaise(in context: inout GraphicsContext, size: CGSize) {
    equipment([(0.14, 0.15), (0.86, 0.15)], in: &context, size: size, width: 0.07)
    head((0.50, 0.37), in: &context, size: size)
    body([(0.50, 0.46), (0.50, 0.67)], in: &context, size: size)
    body([(0.44, 0.46), (0.32, 0.27), (0.25, 0.15)], in: &context, size: size)
    body([(0.56, 0.46), (0.68, 0.27), (0.75, 0.15)], in: &context, size: size)
    body([(0.50, 0.67), (0.68, 0.66), (0.82, 0.59)], in: &context, size: size)
    body([(0.50, 0.67), (0.67, 0.77), (0.82, 0.76)], in: &context, size: size)
    accentArc(from: (0.65, 0.86), to: (0.84, 0.68), control: (0.85, 0.87), in: &context, size: size)
  }

  fileprivate func rotation(
    _ equipmentKind: ExerciseGlyphEquipment, in context: inout GraphicsContext, size: CGSize
  ) {
    if equipmentKind != .cable {
      ground(from: (0.10, 0.86), to: (0.90, 0.86), in: &context, size: size)
      head((0.38, 0.30), in: &context, size: size)
      body([(0.42, 0.39), (0.54, 0.63)], in: &context, size: size)
      body([(0.54, 0.63), (0.69, 0.55), (0.84, 0.69)], in: &context, size: size)
      body([(0.54, 0.63), (0.70, 0.72), (0.86, 0.78)], in: &context, size: size)
      body([(0.45, 0.43), (0.62, 0.40), (0.75, 0.48)], in: &context, size: size)
      ball(center: (0.79, 0.50), radius: 0.065, in: &context, size: size)
      accentArc(
        from: (0.24, 0.49), to: (0.72, 0.36), control: (0.44, 0.20), in: &context,
        size: size)
      return
    }

    head((0.50, 0.20), in: &context, size: size)
    body([(0.50, 0.29), (0.50, 0.64)], in: &context, size: size)
    body([(0.50, 0.64), (0.50, 0.84)], in: &context, size: size)
    body([(0.45, 0.40), (0.60, 0.45), (0.75, 0.38)], in: &context, size: size)
    equipment([(0.91, 0.20), (0.75, 0.38)], in: &context, size: size, width: 0.035)
    accentArc(from: (0.25, 0.50), to: (0.73, 0.51), control: (0.49, 0.70), in: &context, size: size)
  }

  fileprivate func deadBug(in context: inout GraphicsContext, size: CGSize) {
    ground(from: (0.10, 0.82), to: (0.91, 0.82), in: &context, size: size)
    head((0.26, 0.70), in: &context, size: size)
    body([(0.34, 0.71), (0.58, 0.71)], in: &context, size: size)

    // Opposite arm and leg extend away from the trunk; the other arm and leg
    // stay visibly bent at 90 degrees.
    body([(0.39, 0.69), (0.24, 0.50), (0.13, 0.35)], in: &context, size: size)
    body([(0.45, 0.69), (0.50, 0.43), (0.64, 0.43)], in: &context, size: size)
    body([(0.58, 0.71), (0.69, 0.48), (0.82, 0.48)], in: &context, size: size)
    body([(0.58, 0.71), (0.75, 0.75), (0.90, 0.79)], in: &context, size: size)
    accentArc(
      from: (0.18, 0.56), to: (0.12, 0.37), control: (0.09, 0.48), in: &context,
      size: size)
    accentArc(
      from: (0.77, 0.65), to: (0.89, 0.76), control: (0.89, 0.65), in: &context,
      size: size)
  }

  fileprivate func birdDog(in context: inout GraphicsContext, size: CGSize) {
    ground(from: (0.11, 0.84), to: (0.90, 0.84), in: &context, size: size)
    head((0.30, 0.43), in: &context, size: size)
    body([(0.37, 0.48), (0.62, 0.57)], in: &context, size: size)
    body([(0.45, 0.51), (0.33, 0.72), (0.30, 0.82)], in: &context, size: size)
    body([(0.60, 0.57), (0.56, 0.75), (0.54, 0.82)], in: &context, size: size)
    body([(0.38, 0.49), (0.20, 0.38), (0.10, 0.31)], in: &context, size: size)
    body([(0.62, 0.57), (0.78, 0.47), (0.91, 0.39)], in: &context, size: size)
    accentArc(from: (0.10, 0.48), to: (0.19, 0.34), control: (0.08, 0.33), in: &context, size: size)
    accentArc(from: (0.78, 0.58), to: (0.90, 0.43), control: (0.91, 0.58), in: &context, size: size)
  }

  fileprivate func sidePlank(in context: inout GraphicsContext, size: CGSize) {
    ground(from: (0.10, 0.84), to: (0.92, 0.84), in: &context, size: size)
    // Side plank: elbow sits under the shoulder, the forearm lies flat, and
    // the shoulder, hip, and stacked feet form one continuous line.
    head((0.27, 0.46), in: &context, size: size)
    body([(0.34, 0.52), (0.58, 0.63), (0.84, 0.77)], in: &context, size: size)
    body([(0.36, 0.53), (0.30, 0.72), (0.15, 0.79)], in: &context, size: size)
    body([(0.43, 0.56), (0.50, 0.34), (0.53, 0.13)], in: &context, size: size)
    body([(0.84, 0.77), (0.93, 0.81)], in: &context, size: size)
    body([(0.82, 0.78), (0.91, 0.84)], in: &context, size: size)
  }

  fileprivate func backExtension(in context: inout GraphicsContext, size: CGSize) {
    equipment([(0.52, 0.63), (0.76, 0.76)], in: &context, size: size, width: 0.09)
    equipment([(0.69, 0.71), (0.77, 0.87)], in: &context, size: size, width: 0.035)
    head((0.27, 0.35), in: &context, size: size)
    body([(0.34, 0.40), (0.58, 0.57), (0.73, 0.72)], in: &context, size: size)
    body([(0.72, 0.72), (0.84, 0.82)], in: &context, size: size)
    body([(0.43, 0.47), (0.35, 0.61)], in: &context, size: size)
    accentArc(from: (0.24, 0.63), to: (0.42, 0.38), control: (0.20, 0.41), in: &context, size: size)
  }
}

extension ExerciseGlyphRenderer {
  fileprivate func kettlebellSwing(in context: inout GraphicsContext, size: CGSize) {
    ground(from: (0.12, 0.88), to: (0.90, 0.88), in: &context, size: size)
    head((0.33, 0.23), in: &context, size: size)
    body([(0.38, 0.32), (0.53, 0.53)], in: &context, size: size)
    body([(0.53, 0.53), (0.39, 0.69), (0.27, 0.85)], in: &context, size: size)
    body([(0.53, 0.53), (0.68, 0.69), (0.81, 0.85)], in: &context, size: size)
    body([(0.42, 0.37), (0.62, 0.42), (0.77, 0.43)], in: &context, size: size)
    body([(0.45, 0.42), (0.63, 0.47), (0.77, 0.43)], in: &context, size: size)
    kettlebell(center: (0.85, 0.44), in: &context, size: size, scale: 1.08)
    accentArc(from: (0.55, 0.72), to: (0.88, 0.54), control: (0.82, 0.72), in: &context, size: size)
  }

  fileprivate func carry(in context: inout GraphicsContext, size: CGSize) {
    head((0.44, 0.17), in: &context, size: size)
    body([(0.45, 0.26), (0.49, 0.60)], in: &context, size: size)
    body([(0.40, 0.35), (0.30, 0.64)], in: &context, size: size)
    body([(0.52, 0.35), (0.66, 0.61)], in: &context, size: size)
    body([(0.49, 0.60), (0.35, 0.78), (0.24, 0.86)], in: &context, size: size)
    body([(0.49, 0.60), (0.63, 0.76), (0.76, 0.82)], in: &context, size: size)
    dumbbell(center: (0.29, 0.69), angle: 88, in: &context, size: size)
    dumbbell(center: (0.68, 0.66), angle: 88, in: &context, size: size)
    ground(from: (0.16, 0.89), to: (0.84, 0.89), in: &context, size: size)
    accentArc(from: (0.75, 0.52), to: (0.91, 0.52), control: (0.83, 0.44), in: &context, size: size)
  }

  fileprivate func ballSlam(in context: inout GraphicsContext, size: CGSize) {
    head((0.43, 0.27), in: &context, size: size)
    body([(0.46, 0.36), (0.56, 0.59)], in: &context, size: size)
    body([(0.56, 0.59), (0.41, 0.71), (0.29, 0.84)], in: &context, size: size)
    body([(0.56, 0.59), (0.70, 0.71), (0.80, 0.84)], in: &context, size: size)
    body([(0.48, 0.39), (0.62, 0.29), (0.74, 0.38)], in: &context, size: size)
    body([(0.51, 0.43), (0.66, 0.34), (0.74, 0.38)], in: &context, size: size)
    ball(center: (0.80, 0.41), radius: 0.09, in: &context, size: size)
    accentArc(from: (0.82, 0.24), to: (0.82, 0.68), control: (0.98, 0.47), in: &context, size: size)
    ground(from: (0.18, 0.87), to: (0.89, 0.87), in: &context, size: size)
  }

  fileprivate func sledPush(in context: inout GraphicsContext, size: CGSize) {
    head((0.27, 0.29), in: &context, size: size)
    body([(0.34, 0.34), (0.54, 0.52)], in: &context, size: size)
    body([(0.54, 0.52), (0.41, 0.68), (0.25, 0.85)], in: &context, size: size)
    body([(0.54, 0.52), (0.66, 0.70), (0.73, 0.85)], in: &context, size: size)
    body([(0.40, 0.39), (0.62, 0.34), (0.76, 0.34)], in: &context, size: size)
    body([(0.44, 0.44), (0.64, 0.43), (0.76, 0.34)], in: &context, size: size)
    equipment([(0.78, 0.20), (0.78, 0.79)], in: &context, size: size, width: 0.065)
    equipment([(0.90, 0.28), (0.90, 0.79)], in: &context, size: size, width: 0.065)
    equipment([(0.75, 0.79), (0.96, 0.79)], in: &context, size: size, width: 0.075)
    plate(center: (0.84, 0.68), scale: 0.62, in: &context, size: size)
    ground(from: (0.13, 0.88), to: (0.97, 0.88), in: &context, size: size)
    accentArc(from: (0.08, 0.60), to: (0.23, 0.60), control: (0.15, 0.51), in: &context, size: size)
  }

  fileprivate func battleRope(in context: inout GraphicsContext, size: CGSize) {
    head((0.29, 0.24), in: &context, size: size)
    body([(0.34, 0.33), (0.46, 0.57)], in: &context, size: size)
    body([(0.46, 0.57), (0.30, 0.70), (0.17, 0.85)], in: &context, size: size)
    body([(0.46, 0.57), (0.62, 0.70), (0.73, 0.85)], in: &context, size: size)
    body([(0.37, 0.38), (0.51, 0.44), (0.62, 0.52)], in: &context, size: size)
    body([(0.39, 0.44), (0.52, 0.51), (0.61, 0.60)], in: &context, size: size)
    rope(from: (0.62, 0.52), to: (0.97, 0.77), phase: -0.04, in: &context, size: size)
    rope(from: (0.61, 0.60), to: (0.97, 0.86), phase: 0.08, in: &context, size: size)
    equipmentBlock(center: (0.97, 0.82), in: &context, size: size)
    ground(from: (0.10, 0.89), to: (0.98, 0.89), in: &context, size: size)
  }

  fileprivate func generic(in context: inout GraphicsContext, size: CGSize) {
    head((0.50, 0.20), in: &context, size: size)
    body([(0.50, 0.29), (0.50, 0.63)], in: &context, size: size)
    body([(0.44, 0.38), (0.34, 0.62)], in: &context, size: size)
    body([(0.56, 0.38), (0.66, 0.62)], in: &context, size: size)
    body([(0.50, 0.63), (0.50, 0.84)], in: &context, size: size)
    dumbbell(center: (0.33, 0.67), angle: 88, in: &context, size: size)
    dumbbell(center: (0.67, 0.67), angle: 88, in: &context, size: size)
    accentArc(from: (0.22, 0.78), to: (0.22, 0.48), control: (0.12, 0.63), in: &context, size: size)
  }
}

extension ExerciseGlyphRenderer {
  fileprivate func body(
    _ points: [(CGFloat, CGFloat)],
    in context: inout GraphicsContext,
    size: CGSize,
    width: CGFloat = 0.060
  ) {
    stroke(points, color: bodyColor, in: &context, size: size, width: width)
  }

  fileprivate func equipment(
    _ points: [(CGFloat, CGFloat)],
    in context: inout GraphicsContext,
    size: CGSize,
    width: CGFloat = 0.042
  ) {
    stroke(points, color: equipmentColor, in: &context, size: size, width: width)
  }

  fileprivate func ground(
    from start: (CGFloat, CGFloat),
    to end: (CGFloat, CGFloat),
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    stroke([start, end], color: secondaryColor, in: &context, size: size, width: 0.024)
  }

  fileprivate func head(
    _ center: (CGFloat, CGFloat), in context: inout GraphicsContext, size: CGSize
  ) {
    let diameter = min(size.width, size.height) * 0.12
    let rect = CGRect(
      x: size.width * center.0 - diameter / 2,
      y: size.height * center.1 - diameter / 2,
      width: diameter,
      height: diameter
    )
    context.fill(Path(ellipseIn: rect), with: .color(bodyColor))
  }

  fileprivate func bench(
    from start: (CGFloat, CGFloat),
    to end: (CGFloat, CGFloat),
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    stroke([start, end], color: secondaryColor, in: &context, size: size, width: 0.07)
    let leftLeg = (start.0 + (end.0 - start.0) * 0.25, start.1 + (end.1 - start.1) * 0.25)
    let rightLeg = (start.0 + (end.0 - start.0) * 0.76, start.1 + (end.1 - start.1) * 0.76)
    stroke(
      [leftLeg, (leftLeg.0 - 0.02, min(0.90, leftLeg.1 + 0.16))], color: secondaryColor,
      in: &context, size: size, width: 0.035)
    stroke(
      [rightLeg, (rightLeg.0 + 0.02, min(0.90, rightLeg.1 + 0.16))], color: secondaryColor,
      in: &context, size: size, width: 0.035)
  }

  fileprivate func barbell(
    from start: (CGFloat, CGFloat),
    to end: (CGFloat, CGFloat),
    in context: inout GraphicsContext,
    size: CGSize,
    plateScale: CGFloat = 1
  ) {
    stroke([start, end], color: equipmentColor, in: &context, size: size, width: 0.038)
    plate(center: start, scale: plateScale, in: &context, size: size)
    plate(center: end, scale: plateScale, in: &context, size: size)
  }

  fileprivate func plate(
    center: (CGFloat, CGFloat),
    scale: CGFloat,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    let width = size.width * 0.075 * scale
    let height = size.height * 0.18 * scale
    let rect = CGRect(
      x: size.width * center.0 - width / 2,
      y: size.height * center.1 - height / 2,
      width: width,
      height: height
    )
    context.fill(Path(roundedRect: rect, cornerRadius: width * 0.42), with: .color(equipmentColor))
  }

  fileprivate func dumbbell(
    center: (CGFloat, CGFloat),
    angle: Double,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    let radians = angle * .pi / 180
    let halfLength: CGFloat = 0.075
    let dx = CGFloat(cos(radians)) * halfLength
    let dy = CGFloat(sin(radians)) * halfLength
    let start = (center.0 - dx, center.1 - dy)
    let end = (center.0 + dx, center.1 + dy)
    stroke([start, end], color: equipmentColor, in: &context, size: size, width: 0.045)
    equipmentBlock(center: start, in: &context, size: size)
    equipmentBlock(center: end, in: &context, size: size)
  }

  fileprivate func equipmentBlock(
    center: (CGFloat, CGFloat), in context: inout GraphicsContext, size: CGSize
  ) {
    let side = size.width * 0.060
    let rect = CGRect(
      x: size.width * center.0 - side / 2,
      y: size.height * center.1 - side / 2,
      width: side,
      height: side
    )
    context.fill(Path(roundedRect: rect, cornerRadius: side * 0.28), with: .color(equipmentColor))
  }

  fileprivate func kettlebell(
    center: (CGFloat, CGFloat),
    in context: inout GraphicsContext,
    size: CGSize,
    scale: CGFloat = 1
  ) {
    let radius = size.width * 0.075 * scale
    let ballRect = CGRect(
      x: size.width * center.0 - radius,
      y: size.height * center.1 - radius * 0.20,
      width: radius * 2,
      height: radius * 1.55
    )
    context.fill(Path(ellipseIn: ballRect), with: .color(equipmentColor))
    let handleRect = CGRect(
      x: size.width * center.0 - radius * 0.62,
      y: size.height * center.1 - radius * 0.86,
      width: radius * 1.24,
      height: radius * 0.95
    )
    context.stroke(
      Path(roundedRect: handleRect, cornerRadius: radius * 0.48),
      with: .color(equipmentColor),
      lineWidth: max(1, size.width * 0.035 * scale)
    )
  }

  fileprivate func ball(
    center: (CGFloat, CGFloat),
    radius: CGFloat,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    let diameter = size.width * radius * 2
    let rect = CGRect(
      x: size.width * center.0 - diameter / 2,
      y: size.height * center.1 - diameter / 2,
      width: diameter,
      height: diameter
    )
    context.fill(Path(ellipseIn: rect), with: .color(equipmentColor))
    context.stroke(
      Path(ellipseIn: rect.insetBy(dx: diameter * 0.22, dy: diameter * 0.22)),
      with: .color(.white.opacity(0.45)), lineWidth: max(0.75, size.width * 0.02))
  }

  fileprivate func rope(
    from start: (CGFloat, CGFloat),
    to end: (CGFloat, CGFloat),
    phase: CGFloat,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    var path = Path()
    path.move(to: CGPoint(x: size.width * start.0, y: size.height * start.1))
    path.addCurve(
      to: CGPoint(x: size.width * end.0, y: size.height * end.1),
      control1: CGPoint(
        x: size.width * (start.0 + 0.08), y: size.height * (start.1 + 0.12 + phase)),
      control2: CGPoint(x: size.width * (end.0 - 0.08), y: size.height * (end.1 - 0.14 + phase))
    )
    context.stroke(path, with: .color(equipmentColor), style: strokeStyle(size: size, width: 0.045))
  }

  fileprivate func accentArc(
    from start: (CGFloat, CGFloat),
    to end: (CGFloat, CGFloat),
    control: (CGFloat, CGFloat),
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    var path = Path()
    path.move(to: CGPoint(x: size.width * start.0, y: size.height * start.1))
    path.addQuadCurve(
      to: CGPoint(x: size.width * end.0, y: size.height * end.1),
      control: CGPoint(x: size.width * control.0, y: size.height * control.1)
    )
    context.stroke(
      path, with: .color(tint.opacity(0.28)), style: strokeStyle(size: size, width: 0.026))
  }

  fileprivate func stroke(
    _ points: [(CGFloat, CGFloat)],
    color: Color,
    in context: inout GraphicsContext,
    size: CGSize,
    width: CGFloat
  ) {
    guard let first = points.first else {
      return
    }

    var path = Path()
    path.move(to: CGPoint(x: size.width * first.0, y: size.height * first.1))
    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: size.width * point.0, y: size.height * point.1))
    }
    context.stroke(path, with: .color(color), style: strokeStyle(size: size, width: width))
  }

  fileprivate func strokeStyle(size: CGSize, width: CGFloat) -> StrokeStyle {
    StrokeStyle(
      lineWidth: max(1, size.width * width),
      lineCap: .round,
      lineJoin: .round
    )
  }
}
