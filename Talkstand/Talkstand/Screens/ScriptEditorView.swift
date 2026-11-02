import SwiftUI

/// Write or edit a script, then stand the phone up and record it.
struct ScriptEditorView: View {
    let scriptID: Script.ID
    let onRecord: (Script) -> Void

    @Environment(ScriptStore.self) private var store
    @State private var draft = Script()
    @FocusState private var bodyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $draft.title)
                .font(.title2.weight(.semibold))
                .padding(.horizontal)
                .padding(.top, 8)
            TextEditor(text: $draft.body)
                .font(.title3)
                .focused($bodyFocused)
                .padding(.horizontal, 12)
                .overlay(alignment: .topLeading) {
                    if draft.body.isEmpty {
                        Text("What do you want to say?")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 17)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                store.update(draft)
                onRecord(draft)
            } label: {
                Label("Stand it up and record", systemImage: "video")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .disabled(draft.wordCount == 0)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let script = store.script(id: scriptID) {
                draft = script
            }
            bodyFocused = draft.body.isEmpty
        }
        .onChange(of: draft) { _, newValue in store.update(newValue) }
    }
}
