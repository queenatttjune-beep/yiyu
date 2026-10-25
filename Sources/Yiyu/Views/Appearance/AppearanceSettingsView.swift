import SwiftUI
import YiyuCore

/// 外观与皮肤: pick a skin, adjust its colours and fonts, and watch the panel follow along.
struct AppearanceSettingsView: View {
    let model: AppearanceModel

    @State private var pendingDeletion: Skin?

    var body: some View {
        VStack(spacing: 0) {
            ForEach([model.loadProblem, model.saveError].compactMap { $0 }, id: \.self) { problem in
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.16))
            }
            SkinGallery(model: model, requestDeletion: { pendingDeletion = $0 })
            Divider()
            HStack(spacing: 0) {
                SkinEditor(model: model, requestDeletion: { pendingDeletion = $0 })
                Divider()
                SkinPreview()
                    .frame(width: 300)
            }
        }
        .frame(width: 780, height: 680)
        .confirmationDialog(
            "删除「\(pendingDeletion?.name ?? "")」？",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { skin in
            Button("删除", role: .destructive) { model.delete(skin.id) }
        } message: { _ in
            Text("删除后不能恢复。正在用的话，面板会换回默认的磁青泥金。")
        }
    }
}
