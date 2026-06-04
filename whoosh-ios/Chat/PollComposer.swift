import SwiftUI

/// Compose a poll: a question, 2–6 options, and single- vs multi-select. Opened
/// by `/poll`. Calls `onCreate(question, multi, options)` on Post.
struct PollComposer: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (_ question: String, _ multi: Bool, _ options: [String]) -> Void

    @State private var question = ""
    @State private var options: [String] = ["", ""]
    @State private var multi = false

    private var trimmedOptions: [String] {
        options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var canPost: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty && trimmedOptions.count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("Ask something…", text: $question, axis: .vertical).lineLimit(1...3)
                }
                Section("Options") {
                    ForEach(options.indices, id: \.self) { i in
                        HStack {
                            TextField("Option \(i + 1)", text: $options[i])
                            if options.count > 2 {
                                Button { options.remove(at: i) } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if options.count < 6 {
                        Button { options.append("") } label: {
                            Label("Add option", systemImage: "plus.circle.fill")
                        }
                    }
                }
                Section {
                    Toggle("Allow multiple choices", isOn: $multi)
                }
            }
            .navigationTitle("New poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        onCreate(question.trimmingCharacters(in: .whitespaces), multi, trimmedOptions)
                        dismiss()
                    }.disabled(!canPost)
                }
            }
        }
    }
}
