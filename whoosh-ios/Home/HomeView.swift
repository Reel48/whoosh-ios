import SwiftUI

/// The logged-in tab shell. Chat is the primary tab — it's how the community
/// has always interacted — followed by Capital, Fantasy, News, and Account.
struct HomeView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ChatHomeView().tag(0)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            CapitalView().tag(1)
                .tabItem { Label("Capital", systemImage: "bolt.fill") }
            FantasyView().tag(2)
                .tabItem { Label("Fantasy", systemImage: "football.fill") }
            NewsView().tag(3)
                .tabItem { Label("News", systemImage: "newspaper.fill") }
            NavigationStack { AccountView() }.tag(4)
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        // On-brand selected tint (green reads in light + dark; lime is too light
        // for small tab items) + a tactile tick on every tab switch.
        .tint(.whooshGreen)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    HomeView().environmentObject(AppModel())
}
