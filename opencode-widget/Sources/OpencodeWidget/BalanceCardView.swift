import SwiftUI

struct BalanceCardView: View {
    let title: String
    let balance: Double?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let balance {
                Text(String(format: "$%.2f", balance))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else {
                Text("Set in Prefs")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
