import SwiftUI

struct AthletesHistoryView: View {
    enum MatchDateFilter: String, CaseIterable {
        case today = "Hoje"
        case week = "Esta Semana"
        case month = "Este Mês"
        case all = "Todas"
    }

    @Environment(\.dismiss) private var dismiss
    let athletes: [String]
    let matchHistory: [ContentViewTenis.MatchHistoryRecord]
    let onDeleteAthlete: (String) -> Void
    let onDeleteMatch: (UUID) -> Void
    let onShareMatch: (ContentViewTenis.MatchHistoryRecord) -> Void
    var onShareAthleteRanking: (([(name: String, wins: Int, losses: Int)], String) -> Void)? = nil
    var onShareDuoRanking: (([(duo: String, wins: Int, losses: Int)], String) -> Void)? = nil
    var title = "Atletas e histórico"
    var showsCloseButton = true
    var showsAthletesSection = true
    var showsRankingsSections = true
    var showsMatchesSection = true
    var showsMatchFilters = false
    var showsRankingDateFilter = false

    @State private var pendingDeletion: PendingDeletion?
    @State private var selectedAthleteFilter = "Todos"
    @State private var selectedDateFilter: MatchDateFilter = .month

    var body: some View {
        NavigationStack {
            List {
                if showsAthletesSection {
                    Section("Atletas cadastrados") {
                        if athletes.isEmpty {
                            Text("Nenhum atleta cadastrado ainda.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(athletes, id: \.self) { athlete in
                                HStack {
                                    Text(athlete)
                                    Spacer()
                                    Button {
                                        pendingDeletion = .athlete(name: athlete)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if showsRankingsSections {
                    if showsRankingDateFilter {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    filterMenuChip(
                                        title: "Data",
                                        value: selectedDateFilter.rawValue
                                    ) {
                                        ForEach(MatchDateFilter.allCases, id: \.self) { filter in
                                            Button(filter.rawValue) {
                                                selectedDateFilter = filter
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }

                    Section {
                        if athleteRankingStats.isEmpty {
                            Text("Sem partidas registradas.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(athleteRankingStats.enumerated()), id: \.element.name) { index, stat in
                                rankingCard(
                                    title: stat.name,
                                    subtitle: "Atleta",
                                    rank: index + 1,
                                    wins: stat.wins,
                                    losses: stat.losses,
                                    accentColor: athleteAccentColor(for: index)
                                )
                            }
                        }
                    } header: {
                        rankingSectionHeader(
                            title: "Resultado por atleta",
                            subtitle: "Desempenho individual filtrado por período",
                            onShare: athleteRankingStats.isEmpty ? nil : {
                                onShareAthleteRanking?(athleteRankingStats, selectedDateFilter.rawValue)
                            }
                        )
                    }

                    Section {
                        if duoRankingStats.isEmpty {
                            Text("Sem duplas registradas.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(duoRankingStats.enumerated()), id: \.element.duo) { index, stat in
                                rankingCard(
                                    title: stat.duo,
                                    subtitle: "Dupla",
                                    rank: index + 1,
                                    wins: stat.wins,
                                    losses: stat.losses,
                                    accentColor: duoAccentColor(for: index)
                                )
                            }
                        }
                    } header: {
                        rankingSectionHeader(
                            title: "Resultado por dupla",
                            subtitle: "Ranking consolidado das parcerias",
                            onShare: duoRankingStats.isEmpty ? nil : {
                                onShareDuoRanking?(duoRankingStats, selectedDateFilter.rawValue)
                            }
                        )
                    }
                }

                if showsMatchesSection {
                    if showsMatchFilters {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    filterMenuChip(
                                        title: "Atleta",
                                        value: selectedAthleteFilter
                                    ) {
                                        Button("Todos") {
                                            selectedAthleteFilter = "Todos"
                                        }

                                        ForEach(availableAthleteFilters, id: \.self) { athlete in
                                            Button(athlete) {
                                                selectedAthleteFilter = athlete
                                            }
                                        }
                                    }

                                    filterMenuChip(
                                        title: "Data",
                                        value: selectedDateFilter.rawValue
                                    ) {
                                        ForEach(MatchDateFilter.allCases, id: \.self) { filter in
                                            Button(filter.rawValue) {
                                                selectedDateFilter = filter
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }

                    Section("Partidas") {
                        if filteredMatchHistory.isEmpty {
                            Text("Nenhuma partida finalizada.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(filteredMatchHistory) { record in
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label {
                                            Text("\(record.bluePlayers.joined(separator: " + "))  X  \(record.redPlayers.joined(separator: " + "))")
                                        } icon: {
                                            Image(systemName: "person.2.fill")
                                        }
                                        .font(.subheadline.weight(.semibold))

                                        Label {
                                            Text("Games: \(record.gamesBlue) - \(record.gamesRed)")
                                        } icon: {
                                            Image(systemName: "trophy.fill")
                                        }
                                        .font(.subheadline)

                                        Label {
                                            Text("Vencedor: \(record.winnerTeam == "blue" ? "Azul" : "Vermelho") • \(record.isSimpleMode ? "Simples" : "Duplas")")
                                        } icon: {
                                            Image(systemName: "medal.fill")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                        HStack(spacing: 8) {
                                            Label {
                                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                            } icon: {
                                                Image(systemName: "calendar")
                                            }
                                            .font(.caption2)
                                            .foregroundColor(.secondary)

                                            Spacer(minLength: 8)

                                            if let durationText = formattedDuration(record.elapsedTime) {
                                                Label {
                                                    Text(durationText)
                                                } icon: {
                                                    Image(systemName: "clock.fill")
                                                }
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    Spacer(minLength: 0)

                                    VStack(spacing: 8) {
                                        Button {
                                            onShareMatch(record)
                                        } label: {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.accentColor)
                                                .frame(width: 32, height: 32)
                                                .background(Color(uiColor: .secondarySystemFill))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            pendingDeletion = .match(id: record.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.red)
                                                .frame(width: 32, height: 32)
                                                .background(Color(uiColor: .secondarySystemFill))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fechar") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Confirmar exclusão", isPresented: isShowingDeleteAlert) {
                Button("Cancelar", role: .cancel) { pendingDeletion = nil }
                Button("Excluir", role: .destructive) {
                    confirmDeletion()
                }
            } message: {
                Text(deletionMessage)
            }
        }
    }

    private var isShowingDeleteAlert: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { show in
                if !show {
                    pendingDeletion = nil
                }
            }
        )
    }

    private var deletionMessage: String {
        guard let pendingDeletion else { return "" }
        switch pendingDeletion {
        case .athlete(let name):
            return "Deseja excluir o atleta \(name)?"
        case .match:
            return "Deseja excluir essa partida do histórico?"
        }
    }

    private func confirmDeletion() {
        guard let pendingDeletion else { return }
        switch pendingDeletion {
        case .athlete(let name):
            onDeleteAthlete(name)
        case .match(let id):
            onDeleteMatch(id)
        }
        self.pendingDeletion = nil
    }

    private enum PendingDeletion {
        case athlete(name: String)
        case match(id: UUID)
    }

    private func athleteStats() -> [(name: String, wins: Int, losses: Int)] {
        var table: [String: (wins: Int, losses: Int)] = [:]
        for record in rankingSourceHistory {
            for athlete in record.bluePlayers {
                var current = table[athlete, default: (0, 0)]
                if record.winnerTeam == "blue" {
                    current.wins += 1
                } else {
                    current.losses += 1
                }
                table[athlete] = current
            }
            for athlete in record.redPlayers {
                var current = table[athlete, default: (0, 0)]
                if record.winnerTeam == "red" {
                    current.wins += 1
                } else {
                    current.losses += 1
                }
                table[athlete] = current
            }
        }

        return table
            .map { (name: $0.key, wins: $0.value.wins, losses: $0.value.losses) }
            .sorted { lhs, rhs in
                if lhs.wins == rhs.wins { return lhs.name < rhs.name }
                return lhs.wins > rhs.wins
            }
    }

    private func duoStats() -> [(duo: String, wins: Int, losses: Int)] {
        var table: [String: (wins: Int, losses: Int)] = [:]
        for record in rankingSourceHistory {
            guard !record.isSimpleMode else { continue }

            let blueDuo = record.bluePlayers.sorted().joined(separator: " + ")
            var blueValue = table[blueDuo, default: (0, 0)]
            if record.winnerTeam == "blue" {
                blueValue.wins += 1
            } else {
                blueValue.losses += 1
            }
            table[blueDuo] = blueValue

            let redDuo = record.redPlayers.sorted().joined(separator: " + ")
            var redValue = table[redDuo, default: (0, 0)]
            if record.winnerTeam == "red" {
                redValue.wins += 1
            } else {
                redValue.losses += 1
            }
            table[redDuo] = redValue
        }

        return table
            .map { (duo: $0.key, wins: $0.value.wins, losses: $0.value.losses) }
            .sorted { lhs, rhs in
                if lhs.wins == rhs.wins { return lhs.duo < rhs.duo }
                return lhs.wins > rhs.wins
            }
    }

    private func formattedDuration(_ duration: TimeInterval?) -> String? {
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

    private var availableAthleteFilters: [String] {
        let source = athletes.isEmpty ? matchHistory.flatMap { $0.bluePlayers + $0.redPlayers } : athletes
        return Array(Set(source)).sorted()
    }

    private var filteredMatchHistory: [ContentViewTenis.MatchHistoryRecord] {
        matchHistory.filter { record in
            matchesAthleteFilter(record) && matchesDateFilter(record)
        }
    }

    private var athleteRankingStats: [(name: String, wins: Int, losses: Int)] {
        athleteStats()
    }

    private var duoRankingStats: [(duo: String, wins: Int, losses: Int)] {
        duoStats()
    }

    private var rankingSourceHistory: [ContentViewTenis.MatchHistoryRecord] {
        matchHistory.filter(matchesDateFilter)
    }

    private func matchesAthleteFilter(_ record: ContentViewTenis.MatchHistoryRecord) -> Bool {
        guard selectedAthleteFilter != "Todos" else { return true }
        return record.bluePlayers.contains(selectedAthleteFilter) || record.redPlayers.contains(selectedAthleteFilter)
    }

    private func matchesDateFilter(_ record: ContentViewTenis.MatchHistoryRecord) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch selectedDateFilter {
        case .today:
            return calendar.isDate(record.date, inSameDayAs: now)
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return true }
            return weekInterval.contains(record.date)
        case .month:
            return calendar.isDate(record.date, equalTo: now, toGranularity: .month)
        case .all:
            return true
        }
    }

    private func filterMenuChip<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func rankingCard(
        title: String,
        subtitle: String,
        rank: Int,
        wins: Int,
        losses: Int,
        accentColor: Color
    ) -> some View {
        let matches = wins + losses
        let winRate = matches == 0 ? 0 : Int((Double(wins) / Double(matches)) * 100)

        return HStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("#\(rank)")
                    .font(.caption.weight(.black))
                    .foregroundColor(.white)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)
            .background(accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: accentColor.opacity(0.24), radius: 10, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    statPill(title: "Vitórias", value: "\(wins)", tint: .green)
                    statPill(title: "Derrotas", value: "\(losses)", tint: .red)
                    statPill(title: "Resultado", value: "\(winRate)%", tint: accentColor)
                }

                Text("\(matches) partidas registradas")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundColor(tint)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func athleteAccentColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.88, green: 0.67, blue: 0.15)
        case 1: return Color(red: 0.67, green: 0.71, blue: 0.78)
        case 2: return Color(red: 0.72, green: 0.47, blue: 0.24)
        default: return Color(red: 0.14, green: 0.49, blue: 0.85)
        }
    }

    private func duoAccentColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.88, green: 0.67, blue: 0.15)
        case 1: return Color(red: 0.67, green: 0.71, blue: 0.78)
        case 2: return Color(red: 0.72, green: 0.47, blue: 0.24)
        default: return Color(red: 0.10, green: 0.58, blue: 0.52)
        }
    }

    private func rankingSectionHeader(title: String, subtitle: String, onShare: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.4)
                    .foregroundColor(.accentColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onShare {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }
}
