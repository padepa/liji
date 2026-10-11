import SwiftData
import SwiftUI

struct WorkoutNoteEditorView: View {
    @Environment(\.trainingTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: WorkoutSession

    @State private var noteText: String

    init(session: WorkoutSession) {
        self.session = session
        _noteText = State(initialValue: session.note ?? "")
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()

            VStack(spacing: 18) {
                TextEditor(text: $noteText)
                    .scrollContentBackground(.hidden)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(14)
                    .frame(minHeight: 220)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("今天状态、动作感觉、疼痛、器械变化...")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    save()
                } label: {
                    Label("保存备注", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .trainingButtonStyle(prominent: true, tint: theme.primary)

                Spacer()
            }
            .padding(20)
        }
        .dismissKeyboardOnDownwardDrag()
        .navigationTitle("训练备注")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    HapticsService.closePanel()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        session.note = trimmed.isEmpty ? nil : trimmed

        do {
            try modelContext.save()
            HapticsService.saveSucceeded()
            dismiss()
        } catch {
            HapticsService.actionFailed()
            assertionFailure("SwiftData save failed: \(error)")
        }
    }
}
