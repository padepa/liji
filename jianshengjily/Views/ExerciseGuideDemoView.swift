#if DEBUG
import SwiftUI

struct ExerciseGuideDemoView: View {
  @Environment(\.trainingTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var selectedGuideID = ExerciseGuideDemo.samples[0].id

  private var selectedGuide: ExerciseGuideDemo {
    ExerciseGuideDemo.samples.first(where: { $0.id == selectedGuideID })
      ?? ExerciseGuideDemo.samples[0]
  }

  private var orderedGuides: [ExerciseGuideDemo] {
    let motionNames = ["卧推", "面拉", "腿举"]
    let motionGuides = motionNames.compactMap { name in
      ExerciseGuideDemo.samples.first(where: { $0.name == name })
    }
    let staticGuides = ExerciseGuideDemo.samples.filter { !motionNames.contains($0.name) }
    return motionGuides + staticGuides
  }

  var body: some View {
    ZStack {
      TrainingGlassBackground()

      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          demoHeader
          guideSelector
          guideDetail(selectedGuide)
          sourceNote
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 32)
      }
    }
    .navigationTitle("动作指导")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
  }

  private var demoHeader: some View {
    VStack(alignment: .leading, spacing: 10) {
      TrainingStageLabel(text: "原创动画 Demo")

      Text("先看动作，再开始训练")
        .font(.system(size: 32, weight: .black, design: .rounded))
        .tracking(-0.7)
        .foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true)

      Text("卧推、面拉和腿举已加入力迹原创矢量动画；另外 3 个动作继续用于验证肌群、器械、步骤和常见错误的内容结构。")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var guideSelector: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(orderedGuides) { guide in
          guideSelectorButton(guide)
        }
      }
      .padding(.vertical, 2)
    }
    .contentMargins(.horizontal, 1, for: .scrollContent)
  }

  private func guideSelectorButton(_ guide: ExerciseGuideDemo) -> some View {
    let isSelected = guide.id == selectedGuideID

    return Button {
      HapticsService.switchExercise()
      if reduceMotion {
        selectedGuideID = guide.id
      } else {
        withAnimation(.snappy(duration: 0.32)) {
          selectedGuideID = guide.id
        }
      }
    } label: {
      VStack(spacing: 8) {
        ExerciseGlyphView(exerciseName: guide.name, size: 52)

        Text(L10n.string(guide.name))
          .font(.caption.weight(.black))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.76)
      }
      .frame(width: 94, height: 102)
      .background(
        isSelected ? theme.primary.opacity(0.20) : Color.white.opacity(0.065),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(
            isSelected ? theme.primary.opacity(0.72) : .white.opacity(0.09),
            lineWidth: isSelected ? 1.5 : 1
          )
      }
      .overlay(alignment: .topTrailing) {
        if guide.motionKind != nil {
          Image(systemName: "play.fill")
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(.black)
            .frame(width: 22, height: 22)
            .background(theme.primary, in: Circle())
            .padding(7)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.string(guide.name))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func guideDetail(_ guide: ExerciseGuideDemo) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      guideIdentity(guide)

      if let motionKind = guide.motionKind {
        ExerciseMotionDemoView(kind: motionKind)
      }

      guideSummary(guide)
      numberedCard(title: "动作步骤", systemImage: "list.number", items: guide.steps)
      noteCard(title: "常见错误", systemImage: "exclamationmark.triangle.fill", items: guide.mistakes)
      cueCard(guide.cue)
    }
    .id(guide.id)
    .transition(.opacity.combined(with: .offset(y: 10)))
  }

  private func guideIdentity(_ guide: ExerciseGuideDemo) -> some View {
    HStack(alignment: .center, spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(theme.primary.opacity(0.13))

        RadialGradient(
          colors: [theme.primary.opacity(0.24), .clear],
          center: .center,
          startRadius: 5,
          endRadius: 58
        )

        ExerciseGlyphView(exerciseName: guide.name, size: 88)
      }
      .frame(width: 112, height: 112)
      .overlay {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(theme.primary.opacity(0.24), lineWidth: 1)
      }

      VStack(alignment: .leading, spacing: 7) {
        Text(L10n.string(guide.name))
          .font(.system(size: 27, weight: .black, design: .rounded))
          .tracking(-0.45)
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.78)

        Text(verbatim: guide.englishName)
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)

        metadataLine(icon: "scope", text: guide.primaryMuscle)
        metadataLine(icon: "dumbbell.fill", text: guide.equipment)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .liquidGlassCard(cornerRadius: 28, tint: theme.primary)
  }

  private func metadataLine(icon: String, text: String) -> some View {
    Label {
      Text(L10n.string(text))
        .lineLimit(1)
    } icon: {
      Image(systemName: icon)
        .frame(width: 15)
    }
    .font(.caption.weight(.heavy))
    .foregroundStyle(theme.primary)
  }

  private func guideSummary(_ guide: ExerciseGuideDemo) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("动作目标")
        .font(.headline.weight(.heavy))
        .foregroundStyle(.white)

      Text(L10n.string(guide.summary))
        .font(.body.weight(.semibold))
        .foregroundStyle(.white.opacity(0.82))
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 7) {
        Text("辅助肌群")
          .foregroundStyle(.secondary)

        Text(L10n.string(guide.secondaryMuscles))
          .foregroundStyle(.white)
      }
      .font(.caption.weight(.bold))
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .liquidGlassCard(cornerRadius: 22)
  }

  private func numberedCard(title: String, systemImage: String, items: [String]) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(L10n.string(title), systemImage: systemImage)
        .font(.headline.weight(.heavy))
        .foregroundStyle(.white)

      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        HStack(alignment: .top, spacing: 12) {
          Text("\(index + 1)")
            .font(.caption.weight(.black))
            .monospacedDigit()
            .foregroundStyle(.black)
            .frame(width: 24, height: 24)
            .background(theme.primary, in: Circle())

          Text(L10n.string(item))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.86))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .liquidGlassCard(cornerRadius: 22)
  }

  private func noteCard(title: String, systemImage: String, items: [String]) -> some View {
    VStack(alignment: .leading, spacing: 13) {
      Label(L10n.string(title), systemImage: systemImage)
        .font(.headline.weight(.heavy))
        .foregroundStyle(.white)

      ForEach(items, id: \.self) { item in
        HStack(alignment: .top, spacing: 10) {
          Circle()
            .fill(theme.primary)
            .frame(width: 6, height: 6)
            .padding(.top, 7)

          Text(L10n.string(item))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .liquidGlassCard(cornerRadius: 22)
  }

  private func cueCard(_ cue: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("记住一句")
        .font(.caption.weight(.black))
        .tracking(0.8)
        .foregroundStyle(theme.primary)

      Text(L10n.string(cue))
        .font(.title3.weight(.black))
        .foregroundStyle(.white)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [theme.primary.opacity(0.21), theme.primary.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(theme.primary.opacity(0.26), lineWidth: 1)
    }
  }

  private var sourceNote: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("关于这个 Demo")
        .font(.caption.weight(.black))
        .foregroundStyle(.white)

      Text("内容结构参考 exercises-dataset，中文已重新整理；动作动画由力迹原创绘制，不包含该仓库或 Gym Visual 的图片、角色和关键帧。")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Link("查看数据来源", destination: URL(string: "https://github.com/hasaneyldrm/exercises-dataset")!)
        .font(.caption.weight(.heavy))
        .foregroundStyle(theme.primary)
    }
    .padding(.horizontal, 4)
  }
}

private struct ExerciseGuideDemo: Identifiable {
  let name: String
  let englishName: String
  let primaryMuscle: String
  let secondaryMuscles: String
  let equipment: String
  let summary: String
  let steps: [String]
  let mistakes: [String]
  let cue: String

  var id: String { name }

  var motionKind: ExerciseMotionKind? {
    ExerciseMotionKind(exerciseName: name)
  }

  static let samples: [ExerciseGuideDemo] = [
    ExerciseGuideDemo(
      name: "卧推",
      englishName: "Barbell Bench Press",
      primaryMuscle: "胸大肌",
      secondaryMuscles: "肱三头肌、三角肌前束",
      equipment: "杠铃与卧推凳",
      summary: "让杠铃稳定落到胸部中下段，再沿同一路径推起。",
      steps: [
        "双脚踩稳地面，肩胛骨向后、向下收紧。",
        "握距略宽于肩，手腕保持在前臂正上方。",
        "控制杠铃下降到胸部中下段，肘部不要过度外张。",
        "脚掌持续发力，胸肩同步把杠铃推回起点。",
      ],
      mistakes: [
        "肩膀离开凳面，或手腕明显向后折。",
        "杠铃弹胸，下降路径忽左忽右。",
      ],
      cue: "肩胛固定，杠铃稳稳落下再推起。"
    ),
    ExerciseGuideDemo(
      name: "臀推",
      englishName: "Barbell Hip Thrust",
      primaryMuscle: "臀大肌",
      secondaryMuscles: "腘绳肌、股四头肌",
      equipment: "杠铃与训练凳",
      summary: "肩背固定在凳边，顶髋到肩、髋、膝接近一条直线。",
      steps: [
        "让肩胛骨下缘靠住凳边，双脚稳定踩地。",
        "杠铃放在髋部折痕处，双手扶稳。",
        "收紧腹部并夹紧臀部，把髋部向上推。",
        "到顶部稍作停顿，再控制髋部下降。",
      ],
      mistakes: [
        "用腰部后仰代替伸髋，顶部肋骨明显外翻。",
        "双脚离身体太远或太近，顶部膝盖角度失控。",
      ],
      cue: "下巴微收，用臀部把髋推到最高点。"
    ),
    ExerciseGuideDemo(
      name: "反向划船",
      englishName: "Inverted Row",
      primaryMuscle: "上背部与背阔肌",
      secondaryMuscles: "肱二头肌、三角肌后束",
      equipment: "固定横杆与自重",
      summary: "身体保持一条直线，让胸口主动靠近横杆。",
      steps: [
        "把横杆调到合适高度，双手略宽于肩握住。",
        "脚跟着地，收紧臀腹，让身体像木板一样稳定。",
        "先向后收肩胛，再弯曲手肘把胸口拉向横杆。",
        "控制身体下降，手臂伸直后再开始下一次。",
      ],
      mistakes: [
        "髋部下坠，身体在拉起时折成两段。",
        "耸肩并用手臂猛拉，胸口始终远离横杆。",
      ],
      cue: "先收肩胛，再把胸口带向横杆。"
    ),
    ExerciseGuideDemo(
      name: "面拉",
      englishName: "Cable Face Pull",
      primaryMuscle: "三角肌后束与上背部",
      secondaryMuscles: "斜方肌、肩袖肌群",
      equipment: "高位绳索与双头绳",
      summary: "把绳索拉向眉眼位置，同时让双肘向外打开。",
      steps: [
        "把滑轮调到面部附近高度，双手握住绳头。",
        "身体略微后倾，臀腹收紧，肩膀保持下沉。",
        "双肘向外打开，把绳头拉到面部两侧。",
        "肩胛骨收紧后慢慢伸直手臂，不让配重撞击。",
      ],
      mistakes: [
        "把动作做成低位划船，绳索只拉到胸口。",
        "腰部大幅后仰借力，肩膀全程耸起。",
      ],
      cue: "绳子拉向眼睛，双手在脸旁分开。"
    ),
    ExerciseGuideDemo(
      name: "腿举",
      englishName: "45° Leg Press",
      primaryMuscle: "股四头肌与臀大肌",
      secondaryMuscles: "腘绳肌、内收肌群",
      equipment: "45 度腿举机",
      summary: "臀背贴住靠垫，让膝盖沿脚尖方向弯曲和伸展。",
      steps: [
        "调整座椅，双脚以舒适站距踩在踏板上。",
        "解开安全锁，保持臀部和下背贴住靠垫。",
        "弯曲膝盖，让踏板平稳靠近身体。",
        "脚掌整体发力推回，顶部不要猛烈锁死膝盖。",
      ],
      mistakes: [
        "下降过深导致臀部卷起、下背离开靠垫。",
        "膝盖向内扣，或只用脚尖推动踏板。",
      ],
      cue: "臀背贴稳，膝盖始终跟着脚尖走。"
    ),
    ExerciseGuideDemo(
      name: "死虫",
      englishName: "Dead Bug",
      primaryMuscle: "深层核心肌群",
      secondaryMuscles: "腹直肌、髋屈肌群",
      equipment: "自重与地垫",
      summary: "腰背稳定贴地，缓慢伸出对侧手脚。",
      steps: [
        "仰卧抬起双腿，让髋和膝都保持约 90 度。",
        "双臂伸向上方，呼气并让下背部轻贴地面。",
        "缓慢伸出一侧手臂和对侧腿，躯干保持不动。",
        "回到起点后换边，动作范围以腰背不离地为准。",
      ],
      mistakes: [
        "手脚伸得太低，导致腰部拱起离开地面。",
        "动作过快，只摆动四肢而没有控制呼吸。",
      ],
      cue: "先稳住腰背，再慢慢伸出对侧手脚。"
    ),
  ]
}
#endif
