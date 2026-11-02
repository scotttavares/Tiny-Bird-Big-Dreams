import SwiftUI
import UIKit

/// The home screen icons a person can pick. Ochre is the app's primary icon.
enum AppIconChoice: String, CaseIterable, Identifiable, Sendable {
    case ochre, forest, sage, rust

    var id: Self { self }
    var title: String { rawValue.capitalized }

    /// The name iOS knows the icon by; nil is the primary icon.
    var iconName: String? { self == .ochre ? nil : "AppIcon-\(title)" }
    var previewName: String { "IconPreview\(title)" }

    static func current(alternateIconName: String?) -> AppIconChoice {
        allCases.first { $0.iconName == alternateIconName } ?? .ochre
    }
}

/// Lets a person swap the home screen icon.
struct AppIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection = AppIconChoice.current(alternateIconName: UIApplication.shared.alternateIconName)
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 160), spacing: 18)], spacing: 22) {
                    ForEach(AppIconChoice.allCases) { choice in
                        iconOption(choice)
                    }
                }
                .padding(20)
            }
            .background(Theme.chrome)
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't Change the Icon", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your current icon is still in place. Please try again.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func iconOption(_ choice: AppIconChoice) -> some View {
        let isSelected = selection == choice
        return Button {
            select(choice)
        } label: {
            VStack(spacing: 8) {
                Image(choice.previewName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 1, y: 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                            .padding(-5)
                    }
                Label(choice.title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.inkText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.title) icon")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ choice: AppIconChoice) {
        guard choice != selection else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(choice.iconName)
                selection = choice
            } catch {
                failed = true
            }
        }
    }
}
