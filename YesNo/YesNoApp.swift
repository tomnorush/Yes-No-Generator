import SwiftUI

@main
struct YesNoApp: App {
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DecisionView()
                .environment(model)
                .preferredColorScheme(model.appearance.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: model.didEnterBackground()
            case .active: model.didBecomeActive()
            default: break
            }
        }
    }
}
