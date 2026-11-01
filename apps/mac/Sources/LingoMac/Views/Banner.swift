import SwiftUI

/// The notice line of the app (tap to dismiss); also shown on the Today and Teacher screens, where actions can fail.
struct BannerLine: View {
    @Bindable var model: AppModel
    var body: some View {
        if let b = model.banner {
            Text(b).font(Theme.F.rowMeta).foregroundStyle(Theme.C.statusDanger).padding(Theme.S.s8)
                .onTapGesture { model.banner = nil }
                .accessibilityAddTraits(.isButton).accessibilityHint("Close")
        }
    }
}
