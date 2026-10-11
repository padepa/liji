import UIKit

struct PersonalRecordPosterItem {
    let exerciseName: String
    let resultText: String
    let achievedAt: Date
    let improvementText: String?
}

enum SharePosterService {
    static func makePersonalRecordPoster(
        records: [PersonalRecordPosterItem],
        theme: TrainingTheme = .defaultTheme
    ) -> URL? {
        let highlights = Array(records.prefix(4))
        guard !highlights.isEmpty else {
            return nil
        }

        let size = CGSize(width: 1080, height: 1600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            drawBackground(in: context.cgContext, size: size, theme: theme)

            draw(
                L10n.string("力迹"),
                at: CGPoint(x: 86, y: 100),
                font: .systemFont(ofSize: 72, weight: .black),
                color: .white
            )
            draw(
                L10n.string("个人最佳"),
                at: CGPoint(x: 90, y: 205),
                font: .systemFont(ofSize: 34, weight: .heavy),
                color: theme.primaryUIColor
            )
            drawStrengthMark(
                in: context.cgContext,
                center: CGPoint(x: 850, y: 205),
                size: 250,
                theme: theme
            )

            draw(
                L10n.string("我的 PR 高光"),
                in: CGRect(x: 86, y: 345, width: 908, height: 110),
                font: .systemFont(ofSize: 74, weight: .black),
                color: .white
            )
            draw(
                L10n.string("真实完成的个人最佳"),
                at: CGPoint(x: 90, y: 450),
                font: .systemFont(ofSize: 28, weight: .semibold),
                color: UIColor(white: 0.52, alpha: 1)
            )

            if highlights.count == 1, let record = highlights.first {
                drawSoloPersonalRecord(record, theme: theme)
            } else {
                drawPersonalRecordHighlights(highlights, theme: theme)
            }

            draw(
                L10n.string("由 力迹 生成"),
                at: CGPoint(x: 90, y: 1450),
                font: .systemFont(ofSize: 34, weight: .semibold),
                color: UIColor(white: 0.62, alpha: 1)
            )
        }

        guard let data = image.pngData() else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("strength-poster-pr-\(UUID().uuidString).png")

        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
        }
    }

    static func makePoster(
        session: WorkoutSession,
        setLogs: [SetLog],
        exercises: [Exercise],
        theme: TrainingTheme = .defaultTheme
    ) -> URL? {
        let size = CGSize(width: 1080, height: 1600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            drawBackground(in: context.cgContext, size: size, theme: theme)

            let exerciseCount = WorkoutService.exerciseCount(in: session, setLogs: setLogs)
            let setCount = WorkoutService.totalSetCount(in: session, setLogs: setLogs)
            let duration = WorkoutService.durationText(for: session)
            let date = session.startedAt.formatted(date: .abbreviated, time: .shortened)

            draw(L10n.string("力迹"), at: CGPoint(x: 86, y: 110), font: .systemFont(ofSize: 82, weight: .black), color: .white)
            draw(date, at: CGPoint(x: 90, y: 218), font: .systemFont(ofSize: 34, weight: .semibold), color: UIColor(white: 0.68, alpha: 1))

            drawStrengthMark(in: context.cgContext, center: CGPoint(x: 820, y: 210), size: 270, theme: theme)

            drawMetric(title: L10n.string("训练时长"), value: duration, frame: CGRect(x: 86, y: 420, width: 390, height: 220))
            drawMetric(title: L10n.string("动作"), value: "\(exerciseCount)", frame: CGRect(x: 540, y: 420, width: 200, height: 220))
            drawMetric(title: L10n.string("组数"), value: "\(setCount)", frame: CGRect(x: 780, y: 420, width: 210, height: 220))

            let usedExerciseNames = WorkoutService.exercisesUsed(in: session, exercises: exercises, setLogs: setLogs)
                .map(\.displayName)
                .prefix(6)
                .joined(separator: " / ")
            draw(L10n.string("本次动作"), at: CGPoint(x: 90, y: 760), font: .systemFont(ofSize: 42, weight: .bold), color: .white)
            drawFitted(
                usedExerciseNames.isEmpty ? L10n.string("暂无动作") : usedExerciseNames,
                in: CGRect(x: 90, y: 830, width: 900, height: 220),
                maximumFontSize: 46,
                minimumFontSize: 30,
                color: .white
            )

            draw(L10n.string("由 力迹 生成"), at: CGPoint(x: 90, y: 1420), font: .systemFont(ofSize: 34, weight: .semibold), color: UIColor(white: 0.55, alpha: 1))
        }

        guard let data = image.pngData() else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("strength-poster-\(session.id.uuidString).png")

        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
        }
    }

    static func removePoster(at url: URL) {
        guard url.isFileURL,
              url.deletingLastPathComponent().standardizedFileURL
                == FileManager.default.temporaryDirectory.standardizedFileURL,
              url.lastPathComponent.hasPrefix("strength-poster-"),
              url.pathExtension.lowercased() == "png" else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }

    private static func drawBackground(in context: CGContext, size: CGSize, theme: TrainingTheme) {
        let rect = CGRect(origin: .zero, size: size)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(rect)

        let colors = [theme.primaryUIColor.withAlphaComponent(0.38).cgColor, UIColor.clear.cgColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else {
            return
        }
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: 80, y: 80), startRadius: 0, endCenter: CGPoint(x: 80, y: 80), endRadius: 620, options: [])
    }

    private static func drawStrengthMark(in context: CGContext, center: CGPoint, size: CGFloat, theme: TrainingTheme) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)

        fillRounded(
            CGRect(x: -size * 0.48, y: -size * 0.48, width: size * 0.96, height: size * 0.96),
            radius: size * 0.26,
            fill: UIColor.white.withAlphaComponent(0.08),
            stroke: UIColor.white.withAlphaComponent(0.16),
            lineWidth: 2
        )

        context.rotate(by: -0.18)

        fillRounded(
            CGRect(x: -size * 0.22, y: -size * 0.33, width: size * 0.44, height: size * 0.66),
            radius: size * 0.15,
            fill: UIColor.black.withAlphaComponent(0.50),
            stroke: theme.primaryUIColor.withAlphaComponent(0.30),
            lineWidth: 3
        )

        drawSetTick(x: -size * 0.13, y: -size * 0.20, height: size * 0.40, width: size * 0.055, color: theme.successUIColor)
        drawSetTick(x: -size * 0.025, y: -size * 0.26, height: size * 0.52, width: size * 0.055, color: theme.accentUIColor)
        drawSetTick(x: size * 0.08, y: -size * 0.16, height: size * 0.32, width: size * 0.055, color: theme.primaryUIColor)

        fillRounded(
            CGRect(x: -size * 0.40, y: -size * 0.05, width: size * 0.80, height: size * 0.10),
            radius: size * 0.05,
            fill: UIColor(white: 0.94, alpha: 1),
            stroke: nil,
            lineWidth: 0
        )

        drawPlates(side: -1, size: size)
        drawPlates(side: 1, size: size)

        fillRounded(
            CGRect(x: -size * 0.095, y: -size * 0.115, width: size * 0.19, height: size * 0.23),
            radius: size * 0.065,
            fill: UIColor.black.withAlphaComponent(0.94),
            stroke: UIColor.white.withAlphaComponent(0.94),
            lineWidth: size * 0.024
        )

        context.restoreGState()
    }

    private static func drawSetTick(x: CGFloat, y: CGFloat, height: CGFloat, width: CGFloat, color: UIColor) {
        fillRounded(
            CGRect(x: x, y: y, width: width, height: height),
            radius: width * 0.5,
            fill: color.withAlphaComponent(0.92),
            stroke: nil,
            lineWidth: 0
        )
    }

    private static func drawPlates(side: CGFloat, size: CGFloat) {
        let widths = [size * 0.18, size * 0.14]
        let heights = [size * 0.40, size * 0.30]
        let offsets = [size * 0.42, size * 0.29]

        for index in 0..<widths.count {
            let width = widths[index]
            let height = heights[index]
            let x = side * offsets[index] - width / 2
            fillRounded(
                CGRect(x: x, y: -height / 2, width: width, height: height),
                radius: width * 0.42,
                fill: UIColor(white: 0.90 + CGFloat(index) * 0.03, alpha: 1),
                stroke: UIColor.white.withAlphaComponent(0.20),
                lineWidth: 1.5
            )
        }
    }

    private static func fillRounded(
        _ rect: CGRect,
        radius: CGFloat,
        fill: UIColor,
        stroke: UIColor?,
        lineWidth: CGFloat
    ) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        fill.setFill()
        path.fill()

        if let stroke, lineWidth > 0 {
            stroke.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }

    private static func drawSoloPersonalRecord(_ record: PersonalRecordPosterItem, theme: TrainingTheme) {
        drawFitted(
            record.exerciseName,
            in: CGRect(x: 86, y: 560, width: 908, height: 150),
            maximumFontSize: 88,
            minimumFontSize: 50,
            color: .white
        )

        draw(
            L10n.string("最佳一组"),
            at: CGPoint(x: 90, y: 760),
            font: .systemFont(ofSize: 32, weight: .bold),
            color: UIColor(white: 0.66, alpha: 1)
        )
        drawSingleLineFitted(
            record.resultText,
            in: CGRect(x: 82, y: 820, width: 916, height: 160),
            maximumFontSize: 132,
            minimumFontSize: 72,
            weight: .black,
            monospacedDigits: true,
            color: theme.primaryUIColor
        )

        drawPersonalRecordMetric(
            title: L10n.string("达成日期"),
            value: record.achievedAt.formatted(date: .abbreviated, time: .omitted),
            frame: CGRect(x: 82, y: 1070, width: 446, height: 220)
        )
        drawPersonalRecordMetric(
            title: L10n.string("较此前纪录"),
            value: record.improvementText ?? L10n.string("个人最佳"),
            frame: CGRect(x: 552, y: 1070, width: 446, height: 220)
        )
    }

    private static func drawPersonalRecordHighlights(
        _ records: [PersonalRecordPosterItem],
        theme: TrainingTheme
    ) {
        let cardHeight: CGFloat
        let spacing: CGFloat

        switch records.count {
        case 2:
            cardHeight = 330
            spacing = 24
        case 3:
            cardHeight = 235
            spacing = 22
        default:
            cardHeight = 175
            spacing = 20
        }

        for (index, record) in records.enumerated() {
            let y = 550 + CGFloat(index) * (cardHeight + spacing)
            drawPersonalRecordHighlight(
                record,
                index: index,
                frame: CGRect(x: 82, y: y, width: 916, height: cardHeight),
                theme: theme
            )
        }
    }

    private static func drawPersonalRecordHighlight(
        _ record: PersonalRecordPosterItem,
        index: Int,
        frame: CGRect,
        theme: TrainingTheme
    ) {
        let isHero = index == 0
        fillRounded(
            frame,
            radius: 42,
            fill: isHero ? theme.primaryUIColor.withAlphaComponent(0.16) : UIColor.white.withAlphaComponent(0.08),
            stroke: isHero ? theme.primaryUIColor.withAlphaComponent(0.52) : UIColor.white.withAlphaComponent(0.10),
            lineWidth: isHero ? 3 : 1.5
        )

        let topInset: CGFloat = frame.height <= 180 ? 24 : 32
        draw(
            "#\(index + 1)",
            in: CGRect(x: frame.minX + 32, y: frame.minY + topInset, width: 70, height: 54),
            font: .monospacedDigitSystemFont(ofSize: 32, weight: .black),
            color: isHero ? theme.primaryUIColor : UIColor(white: 0.55, alpha: 1)
        )

        drawSingleLineFitted(
            record.exerciseName,
            in: CGRect(x: frame.minX + 120, y: frame.minY + topInset, width: 470, height: 58),
            maximumFontSize: frame.height <= 180 ? 40 : 48,
            minimumFontSize: 28,
            weight: .black,
            color: .white
        )

        drawSingleLineFitted(
            L10n.string("最佳一组"),
            in: CGRect(x: frame.minX + 640, y: frame.minY + topInset - 2, width: 230, height: 34),
            maximumFontSize: 24,
            minimumFontSize: 17,
            weight: .bold,
            color: UIColor(white: 0.62, alpha: 1)
        )
        drawSingleLineFitted(
            record.resultText,
            in: CGRect(x: frame.minX + 640, y: frame.minY + topInset + 38, width: 230, height: 62),
            maximumFontSize: frame.height <= 180 ? 46 : 54,
            minimumFontSize: 30,
            weight: .black,
            monospacedDigits: true,
            color: theme.primaryUIColor
        )

        drawSingleLineFitted(
            personalRecordDetails(record),
            in: CGRect(x: frame.minX + 120, y: frame.maxY - 52, width: 750, height: 32),
            maximumFontSize: 23,
            minimumFontSize: 16,
            weight: .semibold,
            color: UIColor(white: 0.58, alpha: 1)
        )
    }

    private static func drawMetric(title: String, value: String, frame: CGRect) {
        let path = UIBezierPath(roundedRect: frame, cornerRadius: 44)
        UIColor.white.withAlphaComponent(0.09).setFill()
        path.fill()

        draw(title, at: CGPoint(x: frame.minX + 34, y: frame.minY + 34), font: .systemFont(ofSize: 30, weight: .bold), color: UIColor(white: 0.65, alpha: 1))
        draw(value, at: CGPoint(x: frame.minX + 34, y: frame.minY + 88), font: .monospacedDigitSystemFont(ofSize: 66, weight: .black), color: .white)
    }

    private static func drawPersonalRecordMetric(title: String, value: String, frame: CGRect) {
        let path = UIBezierPath(roundedRect: frame, cornerRadius: 44)
        UIColor.white.withAlphaComponent(0.09).setFill()
        path.fill()

        let contentWidth = frame.width - 60
        drawSingleLineFitted(
            title,
            in: CGRect(x: frame.minX + 30, y: frame.minY + 34, width: contentWidth, height: 38),
            maximumFontSize: 28,
            minimumFontSize: 20,
            weight: .bold,
            color: UIColor(white: 0.65, alpha: 1)
        )
        drawSingleLineFitted(
            value,
            in: CGRect(x: frame.minX + 30, y: frame.minY + 92, width: contentWidth, height: 76),
            maximumFontSize: 58,
            minimumFontSize: 34,
            weight: .black,
            monospacedDigits: true,
            color: .white
        )
    }

    private static func personalRecordDetails(_ record: PersonalRecordPosterItem) -> String {
        let achieved = "\(L10n.string("达成日期")) \(record.achievedAt.formatted(date: .abbreviated, time: .omitted))"
        guard let improvementText = record.improvementText else {
            return achieved
        }
        return "\(achieved)  ·  \(improvementText)"
    }

    private static func draw(_ string: String, at point: CGPoint, font: UIFont, color: UIColor) {
        draw(string, in: CGRect(x: point.x, y: point.y, width: 900, height: 120), font: font, color: color)
    }

    private static func draw(_ string: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        string.draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    private static func drawFitted(
        _ string: String,
        in rect: CGRect,
        maximumFontSize: CGFloat,
        minimumFontSize: CGFloat,
        color: UIColor
    ) {
        var fontSize = maximumFontSize

        while fontSize > minimumFontSize {
            let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
            let bounds = string.boundingRect(
                with: rect.size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            if bounds.height <= rect.height {
                draw(string, in: rect, font: font, color: color)
                return
            }
            fontSize -= 2
        }

        draw(
            string,
            in: rect,
            font: .systemFont(ofSize: minimumFontSize, weight: .heavy),
            color: color
        )
    }

    private static func drawSingleLineFitted(
        _ string: String,
        in rect: CGRect,
        maximumFontSize: CGFloat,
        minimumFontSize: CGFloat,
        weight: UIFont.Weight,
        monospacedDigits: Bool = false,
        color: UIColor
    ) {
        var fontSize = maximumFontSize

        while fontSize > minimumFontSize {
            let font = monospacedDigits
                ? UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight)
                : UIFont.systemFont(ofSize: fontSize, weight: weight)
            if string.size(withAttributes: [.font: font]).width <= rect.width {
                draw(string, in: rect, font: font, color: color)
                return
            }
            fontSize -= 2
        }

        let font = monospacedDigits
            ? UIFont.monospacedDigitSystemFont(ofSize: minimumFontSize, weight: weight)
            : UIFont.systemFont(ofSize: minimumFontSize, weight: weight)
        draw(string, in: rect, font: font, color: color)
    }
}
