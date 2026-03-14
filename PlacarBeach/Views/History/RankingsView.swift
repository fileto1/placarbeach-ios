import SwiftUI

struct RankingsView: View {
    let matchHistory: [ContentViewTenis.MatchHistoryRecord]
    let onShareAthleteRanking: ([(name: String, wins: Int, losses: Int)], String) -> Void
    let onShareDuoRanking: ([(duo: String, wins: Int, losses: Int)], String) -> Void

    var body: some View {
        AthletesHistoryView(
            athletes: [],
            matchHistory: matchHistory,
            onDeleteAthlete: { _ in },
            onDeleteMatch: { _ in },
            onShareMatch: { _ in },
            onShareAthleteRanking: onShareAthleteRanking,
            onShareDuoRanking: onShareDuoRanking,
            title: "Classificações",
            showsCloseButton: false,
            showsAthletesSection: false,
            showsRankingsSections: true,
            showsMatchesSection: false,
            showsRankingDateFilter: true
        )
    }
}
