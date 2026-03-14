import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MatchShareSummary {
    let date: Date
    let isSimpleMode: Bool
    let bluePlayers: [String]
    let redPlayers: [String]
    let gamesBlue: Int
    let gamesRed: Int
    let winnerPlayers: [String]
    let elapsedTime: TimeInterval?
}

struct RankingShareEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let title: String
    let subtitle: String
    let wins: Int
    let losses: Int
    let matches: Int
    let winRate: Int
}

struct RankingShareSummary {
    let title: String
    let subtitle: String
    let filterLabel: String
    let generatedAt: Date
    let entries: [RankingShareEntry]
}
