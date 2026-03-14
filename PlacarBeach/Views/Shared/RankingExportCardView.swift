import SwiftUI

struct RankingExportCardView: View {
    let summary: RankingShareSummary

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGray6),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Placar Beach")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.black)

                    Text(summary.title)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.primary)

                    Text(summary.subtitle)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)

                    HStack(spacing: 14) {
                        infoPill(systemName: "calendar", text: summary.generatedAt.formatted(date: .abbreviated, time: .shortened))
                        infoPill(systemName: "line.3.horizontal.decrease.circle.fill", text: "Filtro: \(summary.filterLabel)")
                    }
                }

                VStack(spacing: 14) {
                    ForEach(summary.entries) { entry in
                        HStack(spacing: 16) {
                            rankBadge(entry.rank)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.title)
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)

                                Text(entry.subtitle)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 10) {
                                    statPill(title: "Vitórias", value: "\(entry.wins)", tint: .green)
                                    statPill(title: "Derrotas", value: "\(entry.losses)", tint: .red)
                                    statPill(title: "Resultado", value: "\(entry.winRate)%", tint: rankTint(for: entry.rank))
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(rankTint(for: entry.rank).opacity(0.18), lineWidth: 1)
                        )
                    }
                }

                Spacer(minLength: 12)

                HStack {
                    Spacer()
                    if let image = logoUIImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 96)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 40)
        }
    }

    private func infoPill(systemName: String, text: String) -> some View {
        Label(text, systemImage: systemName)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
    }

    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(tint)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rankBadge(_ rank: Int) -> some View {
        VStack(spacing: 4) {
            Text("#\(rank)")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Image(systemName: "trophy.fill")
                .font(.system(size: 18, weight: .black))
        }
        .foregroundColor(.white)
        .frame(width: 64, height: 64)
        .background(rankTint(for: rank))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: rankTint(for: rank).opacity(0.28), radius: 12, x: 0, y: 5)
    }

    private func rankTint(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.88, green: 0.67, blue: 0.15)
        case 2: return Color(red: 0.67, green: 0.71, blue: 0.78)
        case 3: return Color(red: 0.72, green: 0.47, blue: 0.24)
        default: return Color(red: 0.14, green: 0.49, blue: 0.85)
        }
    }

    private var logoUIImage: UIImage? {
        UIImage(named: "logo")
    }
}
