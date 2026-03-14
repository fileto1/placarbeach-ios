import SwiftUI

struct MatchExportCardView: View {
    let summary: MatchShareSummary

    var body: some View {
        ZStack {
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Beach Tênis")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundColor(.black)

                    Label(summary.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(spacing: 4) {
                    Text("Vencedor:")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    Text(formattedPlayers(summary.winnerPlayers))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity)

                HStack {
                    VStack(spacing: 12) {
                        scoreBubble(score: "\(summary.gamesBlue)", color: .pink)
                        playersColumn(summary.bluePlayers)
                    }

                    Spacer(minLength: 12)

                    Text("X")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.35))

                    Spacer(minLength: 12)

                    VStack(spacing: 12) {
                        scoreBubble(score: "\(summary.gamesRed)", color: .blue)
                        playersColumn(summary.redPlayers)
                    }
                }
                .padding(.horizontal, 8)

                HStack {
                    Text("Games")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(summary.gamesBlue) x \(summary.gamesRed)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(uiColor: .systemGray4), lineWidth: 2)
                )

                if let durationText = formattedDuration(summary.elapsedTime) {
                    Label(durationText, systemImage: "clock.fill")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(.black.opacity(0.75))
                        .padding(.top, -4)
                }

                Spacer(minLength: 10)

                appLogoView

                Text("Exportado por Placar Beach")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 38)
        }
    }

    func scoreBubble(score: String, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 126, height: 126)
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            .overlay(
                Text(score)
                    .font(.system(size: 62, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            )
    }

    func playersColumn(_ players: [String]) -> some View {
        VStack(spacing: 4) {
            ForEach(Array(players.enumerated()), id: \.offset) { _, player in
                Text(player)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
    }

    func formattedPlayers(_ players: [String]) -> String {
        players.joined(separator: " e ")
    }

    func formattedDuration(_ duration: TimeInterval?) -> String? {
        guard let duration else { return nil }
        let totalSeconds = max(0, Int(duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var appLogoView: some View {
        Group {
            if let image = logoUIImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
            } else {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("PB")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        )
                    Text("Placar Beach")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                }
            }
        }
    }

    var logoUIImage: UIImage? {
        UIImage(named: "logo")
    }
}
