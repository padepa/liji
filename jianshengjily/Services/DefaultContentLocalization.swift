import Foundation

enum DefaultContentLocalization {
    static func exerciseName(_ name: String) -> String {
        guard WorkoutService.defaultExerciseNames.contains(name) else {
            return name
        }
        return L10n.string(name)
    }

    static func templateName(_ template: WorkoutTemplate) -> String {
        guard WorkoutService.defaultTemplateNames.contains(template.name) else {
            return template.name
        }
        return L10n.string(template.name)
    }

    static func trainingPlanName(_ plan: TrainingPlan) -> String {
        plan.isOfficial ? L10n.string(plan.name) : plan.name
    }

    static func trainingPlanDayName(_ day: TrainingPlanDay, plan: TrainingPlan) -> String {
        plan.isOfficial ? L10n.string(day.name) : day.name
    }

    static func matchesSearch(source: String, localized: String, keyword: String) -> Bool {
        source.localizedCaseInsensitiveContains(keyword)
            || localized.localizedCaseInsensitiveContains(keyword)
    }
}

extension Exercise {
    var displayName: String {
        DefaultContentLocalization.exerciseName(name)
    }
}

extension WorkoutTemplate {
    var displayName: String {
        DefaultContentLocalization.templateName(self)
    }
}

extension TrainingPlan {
    var displayName: String {
        DefaultContentLocalization.trainingPlanName(self)
    }
}
