import SwiftUI

struct ConnectionErrorWindowView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connection Errors")
                .font(.headline)

            if viewModel.connectionErrors.isEmpty {
                Text("No errors.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(viewModel.connectionErrors.enumerated()), id: \.offset) { _, message in
                            Text(message)
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                        }
                    }
                }
            }

            HStack {
                Button("Clear") {
                    viewModel.clearConnectionErrors()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
