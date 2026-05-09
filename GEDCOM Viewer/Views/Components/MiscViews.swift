import SwiftUI

struct PlaceholderView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let message: String

    var body: some View {
        let colors = themeManager.colors

        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color.secondary)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(colors.background)
    }
}

struct MessageCardView: View {
    @EnvironmentObject private var themeManager: GVThemeManager
    let message: String?

    var body: some View {
        let colors = themeManager.colors

        let content = VStack(alignment: .leading, spacing: 10) {
            Text(message ?? "")
                .font(.headline)
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colors.surface)
        )

        content
    }
}

struct LoadingOverlay: View {
    @EnvironmentObject private var themeManager: GVThemeManager

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            colors.surface
                .opacity(1.0)
                .ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
        }
    }
}
