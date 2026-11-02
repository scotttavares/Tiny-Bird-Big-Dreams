import SwiftUI

/// Home: your scripts, newest first.
struct ScriptListView: View {
    @Environment(ScriptStore.self) private var store
    @State private var path: [Script.ID] = []
    @State private var recording: Script?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(store.sorted) { script in
                    NavigationLink(value: script.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(script.displayTitle).font(.headline)
                            Text(summary(script)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button(role: .destructive) { store.delete(id: script.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .overlay {
                if store.scripts.isEmpty {
                    ContentUnavailableView {
                        Label("Write your first script", systemImage: "text.alignleft")
                    } description: {
                        Text("Type what you want to say. Talkstand scrolls it under the camera while you film.")
                    } actions: {
                        Button("New script") { newScript() }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Talkstand")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { newScript() } label: { Label("New script", systemImage: "square.and.pencil") }
                }
            }
            .navigationDestination(for: Script.ID.self) { id in
                ScriptEditorView(scriptID: id) { script in recording = script }
            }
            .fullScreenCover(item: $recording) { script in
                RecordView(script: script)
            }
        }
    }

    private func summary(_ script: Script) -> String {
        let seconds = Int(script.duration(wordsPerMinute: 140).rounded())
        let length = seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min \(seconds % 60) sec"
        return "\(script.wordCount) words · about \(length)"
    }

    private func newScript() {
        path.append(store.create().id)
    }
}
