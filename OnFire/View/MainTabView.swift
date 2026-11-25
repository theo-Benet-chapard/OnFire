import SwiftUI
enum AppTab: Hashable { case home, courses, messages, profile }

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Accueil", systemImage: "house", value: .home) {
                RechauffementVille()
            }
        }
    }
}
