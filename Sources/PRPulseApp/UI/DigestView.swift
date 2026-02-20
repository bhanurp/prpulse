import SwiftUI

struct DigestView: View {
    var snapshot: DigestSnapshot

    var body: some View {
        VStack(spacing: 16) {
            Text("Weekly Digest")
                .font(.title3.bold())

            HStack {
                VStack {
                    Text("Opened")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(snapshot.openedCount)")
                        .font(.largeTitle.bold())
                }
                Spacer()
                VStack {
                    Text("Reviewed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(snapshot.reviewedCount)")
                        .font(.largeTitle.bold())
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))

            Text("Timeframe: \(snapshot.timeframeDescription)")
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }
}
