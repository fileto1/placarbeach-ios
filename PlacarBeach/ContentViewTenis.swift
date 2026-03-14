//
//  ContentViewTenis.swift
//  WhyNotTry
//
//  Created by Guilherme Fileto on 08/01/26.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit
import AudioToolbox

struct ContentViewTenis: View {
    enum AppTab: Hashable {
        case home
        case matches
        case rankings
        case settings
    }

    enum CelebrationKind {
        case game
        case set
    }

    enum TieBreakRule: String, Codable, CaseIterable, Hashable {
        case standard
        case disabled
        case custom

        var title: String {
            switch self {
            case .standard:
                return "Padrão"
            case .disabled:
                return "Desativado"
            case .custom:
                return "Customizado"
            }
        }
    }

    struct MatchConfiguration: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var scoresGamesOnly: Bool
        var gamesToWinSet: Int
        var matchSetsCount: Int
        var tieBreakRule: TieBreakRule
        var customTieBreakPoints: Int
        var isSuperTieBreakEnabled: Bool

        init(
            id: UUID,
            name: String,
            scoresGamesOnly: Bool = false,
            gamesToWinSet: Int,
            matchSetsCount: Int,
            tieBreakRule: TieBreakRule = .standard,
            customTieBreakPoints: Int = 7,
            isSuperTieBreakEnabled: Bool = false
        ) {
            self.id = id
            self.name = name
            self.scoresGamesOnly = scoresGamesOnly
            self.gamesToWinSet = gamesToWinSet
            self.matchSetsCount = matchSetsCount
            self.tieBreakRule = tieBreakRule
            self.customTieBreakPoints = customTieBreakPoints
            self.isSuperTieBreakEnabled = isSuperTieBreakEnabled && matchSetsCount >= 3
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case scoresGamesOnly
            case gamesToWinSet
            case matchSetsCount
            case tieBreakRule
            case customTieBreakPoints
            case isSuperTieBreakEnabled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            scoresGamesOnly = try container.decodeIfPresent(Bool.self, forKey: .scoresGamesOnly) ?? false
            gamesToWinSet = try container.decode(Int.self, forKey: .gamesToWinSet)
            matchSetsCount = try container.decode(Int.self, forKey: .matchSetsCount)
            tieBreakRule = try container.decodeIfPresent(TieBreakRule.self, forKey: .tieBreakRule) ?? .standard
            customTieBreakPoints = min(10, max(1, try container.decodeIfPresent(Int.self, forKey: .customTieBreakPoints) ?? 7))
            let storedSuperTieBreak = try container.decodeIfPresent(Bool.self, forKey: .isSuperTieBreakEnabled) ?? false
            isSuperTieBreakEnabled = storedSuperTieBreak && matchSetsCount >= 3
        }
    }

    struct GameSnapshot {
        let pointsBlue: Int
        let pointsRed: Int
        let gamesBlue: Int
        let gamesRed: Int
        let setsBlue: Int
        let setsRed: Int
        let pointHistory: [String]
    }

    struct MatchResult {
        let winner: Player
        let gamesBlue: Int
        let gamesRed: Int
        let setsBlue: Int
        let setsRed: Int
        let elapsedTime: TimeInterval
    }

    struct MatchHistoryRecord: Codable, Identifiable {
        let id: UUID
        let date: Date
        let isSimpleMode: Bool
        let bluePlayers: [String]
        let redPlayers: [String]
        let gamesBlue: Int
        let gamesRed: Int
        let winnerTeam: String
        let elapsedTime: TimeInterval?
    }

    @State private var pointsBlue = 0
    @State private var pointsRed = 0
    @State private var gamesBlue = 0
    @State private var gamesRed = 0
    @State private var pointHistory: [String] = []
    @State private var undoStack: [GameSnapshot] = []
    @State private var isBlueFlashing = false
    @State private var isRedFlashing = false
    @State private var blueFlashTask: Task<Void, Never>?
    @State private var redFlashTask: Task<Void, Never>?
    @State private var isShowingGameCelebration = false
    @State private var celebrationWinner: Player?
    @State private var celebrationKind: CelebrationKind = .game
    @State private var celebrationTask: Task<Void, Never>?
    @State private var gameWonAudioPlayer: AVAudioPlayer?
    @State private var isSettingsPresented = false
    @State private var isShowingAbandonConfirmation = false
    @State private var selectedTab: AppTab = .home
    @State private var pendingMatchDismissTab: AppTab?
    @StateObject private var volumeButtonObserver = VolumeButtonObserver()
    @StateObject private var scoreVoiceReader = ScoreVoiceReader()
    @SceneStorage("tenis_volume_scoring_enabled") private var isVolumeScoringEnabled = true
    @SceneStorage("tenis_voice_announcement_enabled") private var isVoiceAnnouncementEnabled = true
    @SceneStorage("tenis_match_timer_enabled") private var isMatchTimerEnabled = false
    @SceneStorage("tenis_games_to_win_set") private var storedGamesToWinSet = 6
    @SceneStorage("tenis_match_sets_count") private var storedMatchSetsCount = 1
    @SceneStorage("tenis_points_blue") private var storedPointsBlue = 0
    @SceneStorage("tenis_points_red") private var storedPointsRed = 0
    @SceneStorage("tenis_games_blue") private var storedGamesBlue = 0
    @SceneStorage("tenis_games_red") private var storedGamesRed = 0
    @SceneStorage("tenis_sets_blue") private var storedSetsBlue = 0
    @SceneStorage("tenis_sets_red") private var storedSetsRed = 0
    @SceneStorage("tenis_point_history") private var storedPointHistory = ""
    @AppStorage("tenis_simple_mode_enabled") private var isSimpleModeEnabled = false
    @AppStorage("tenis_registered_athletes_json") private var storedAthletesJSON = "[]"
    @AppStorage("tenis_match_history_json") private var storedMatchHistoryJSON = "[]"
    @AppStorage("tenis_match_configurations_json") private var storedMatchConfigurationsJSON = ""
    @AppStorage("tenis_active_match_configuration_id") private var storedActiveMatchConfigurationID = ""
    @AppStorage("tenis_last_blue_player_one_name") private var storedBluePlayerOneName = ""
    @AppStorage("tenis_last_blue_player_two_name") private var storedBluePlayerTwoName = ""
    @AppStorage("tenis_last_red_player_one_name") private var storedRedPlayerOneName = ""
    @AppStorage("tenis_last_red_player_two_name") private var storedRedPlayerTwoName = ""
    @AppStorage("tenis_switch_sides_enabled") private var isSwitchSidesEnabled = false
    @State private var gamesToWinSet = 6
    @State private var matchSetsCount = 1
    @State private var matchStartDate = Date()
    @State private var frozenMatchElapsedTime: TimeInterval?
    @State private var isHomeScreenVisible = true
    @State private var finishedMatchResult: MatchResult?
    @State private var bluePlayerOneName = ""
    @State private var bluePlayerTwoName = ""
    @State private var redPlayerOneName = ""
    @State private var redPlayerTwoName = ""
    @State private var setsBlue = 0
    @State private var setsRed = 0
    @State private var currentMatchBluePlayers: [String] = []
    @State private var currentMatchRedPlayers: [String] = []
    @State private var registeredAthletes: [String] = []
    @State private var matchHistory: [MatchHistoryRecord] = []
    @State private var matchConfigurations: [MatchConfiguration] = []
    @State private var selectedMatchConfigurationID: UUID?
    @State private var startValidationMessage = ""
    @State private var isShowingStartValidationAlert = false
    @State private var tennisBallSide: Player = .blue

    var body: some View {
        alertWrappedView
    }

    var alertWrappedView: some View {
        sheetWrappedView
            .alert("Finalizar partida?", isPresented: $isShowingAbandonConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Finalizar", role: .destructive) {
                    abandonCurrentMatch()
                }
            } message: {
                Text("Deseja realmente finalizar a partida e sair?")
            }
    }

    var sheetWrappedView: some View {
        lifecycleWrappedView
            .sheet(isPresented: $isSettingsPresented) {
                GameSettingsView(
                    isMatchTimerEnabled: $isMatchTimerEnabled,
                    isVoiceAnnouncementEnabled: $isVoiceAnnouncementEnabled,
                    athletes: registeredAthletes,
                    matchConfigurations: matchConfigurations,
                    activeConfigurationID: $selectedMatchConfigurationID,
                    onDeleteAthlete: { athlete in
                        deleteAthlete(athlete)
                    },
                    onCreateConfiguration: { name, scoresGamesOnly, games, sets, tieBreakRule, customTieBreakPoints, isSuperTieBreakEnabled in
                        createMatchConfiguration(
                            name: name,
                            scoresGamesOnly: scoresGamesOnly,
                            gamesToWinSet: games,
                            matchSetsCount: sets,
                            tieBreakRule: tieBreakRule,
                            customTieBreakPoints: customTieBreakPoints,
                            isSuperTieBreakEnabled: isSuperTieBreakEnabled
                        )
                    },
                    onUpdateConfiguration: { configurationID, name, scoresGamesOnly, games, sets, tieBreakRule, customTieBreakPoints, isSuperTieBreakEnabled in
                        updateMatchConfiguration(
                            configurationID,
                            name: name,
                            scoresGamesOnly: scoresGamesOnly,
                            gamesToWinSet: games,
                            matchSetsCount: sets,
                            tieBreakRule: tieBreakRule,
                            customTieBreakPoints: customTieBreakPoints,
                            isSuperTieBreakEnabled: isSuperTieBreakEnabled
                        )
                    },
                    onDeleteConfiguration: { configurationID in
                        deleteMatchConfiguration(configurationID)
                    },
                    showsMatchConfigurationSection: false
                )
            }
            .fullScreenCover(isPresented: matchRouteBinding) {
                matchRouteView
            }
    }

    var lifecycleWrappedView: some View {
        statePersistenceView
        .onAppear {
            gamesToWinSet = min(8, max(1, storedGamesToWinSet))
            matchSetsCount = normalizedMatchSetsCount(storedMatchSetsCount)
            loadPersistedGameState()
            loadPersistedAthletes()
            loadPersistedMatchHistory()
            loadPersistedMatchConfigurations()
            loadPersistedLastPlayers()
            updateVolumeButtonBehavior()
        }
        .onDisappear {
            volumeButtonObserver.stop()
        }
    }

    var statePersistenceView: some View {
        playerPersistenceView
        .onChange(of: isVolumeScoringEnabled) { _, _ in
            updateVolumeButtonBehavior()
        }
        .onChange(of: isVoiceAnnouncementEnabled) { _, isEnabled in
            if !isEnabled {
                scoreVoiceReader.stopSpeaking()
            }
        }
        .onChange(of: pointsBlue) { _, _ in
            persistGameState()
        }
        .onChange(of: pointsRed) { _, _ in
            persistGameState()
        }
        .onChange(of: gamesBlue) { _, _ in
            persistGameState()
        }
        .onChange(of: gamesRed) { _, _ in
            persistGameState()
        }
        .onChange(of: setsBlue) { _, _ in
            persistGameState()
        }
        .onChange(of: setsRed) { _, _ in
            persistGameState()
        }
        .onChange(of: pointHistory) { _, _ in
            persistGameState()
        }
    }

    var playerPersistenceView: some View {
        settingsPersistenceView
        .onChange(of: selectedMatchConfigurationID) { _, newValue in
            guard let newValue else { return }
            activateMatchConfiguration(newValue)
        }
        .onChange(of: gamesToWinSet) { _, newValue in
            let normalizedValue = min(8, max(1, newValue))
            if normalizedValue != gamesToWinSet {
                gamesToWinSet = normalizedValue
            }
            storedGamesToWinSet = normalizedValue
        }
        .onChange(of: matchSetsCount) { _, newValue in
            let normalizedValue = normalizedMatchSetsCount(newValue)
            if normalizedValue != matchSetsCount {
                matchSetsCount = normalizedValue
            }
            storedMatchSetsCount = normalizedValue
        }
        .onChange(of: bluePlayerOneName) { _, newValue in
            storedBluePlayerOneName = newValue
        }
        .onChange(of: bluePlayerTwoName) { _, newValue in
            storedBluePlayerTwoName = newValue
        }
        .onChange(of: redPlayerOneName) { _, newValue in
            storedRedPlayerOneName = newValue
        }
        .onChange(of: redPlayerTwoName) { _, newValue in
            storedRedPlayerTwoName = newValue
        }
    }

    var settingsPersistenceView: some View {
        rootContentView
            .onChange(of: isHomeScreenVisible) { _, _ in
                updateVolumeButtonBehavior()
            }
            .onChange(of: finishedMatchResult != nil) { _, _ in
                updateVolumeButtonBehavior()
            }
    }

    var rootContentView: some View {
        mainTabView
    }

    var matchRouteBinding: Binding<Bool> {
        Binding(
            get: { !isHomeScreenVisible },
            set: { isPresented in
                if !isPresented {
                    let destination = pendingMatchDismissTab ?? .home
                    pendingMatchDismissTab = nil
                    resetGame()
                    finishedMatchResult = nil
                    isHomeScreenVisible = true
                    selectedTab = destination
                }
            }
        )
    }

    var matchRouteView: some View {
        Group {
            if let result = finishedMatchResult {
                matchFinishedView(result: result)
            } else {
                activeMatchView
            }
        }
    }

    var activeMatchView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                if isLandscape {
                    HStack(spacing: 0) {
                        blueSide
                        redSide
                    }
                } else {
                    VStack(spacing: 0) {
                        blueSide
                        redSide
                    }
                }

                centerOverlay(isLandscape: isLandscape)
            }
            .overlay(alignment: .bottom) {
                bottomBar
            }
            .ignoresSafeArea()
        }
    }

    var mainTabView: some View {
        TabView(selection: $selectedTab) {
            homeRouteView
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            matchesRouteView
                .tabItem {
                    Label("Partidas", systemImage: "figure.tennis")
                }
                .tag(AppTab.matches)

            rankingsRouteView
                .tabItem {
                    Label("Classificações", systemImage: "trophy.fill")
                }
                .tag(AppTab.rankings)

            settingsRouteView
                .tabItem {
                    Label("Configurações", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(.accentColor)
    }

    var homeRouteView: some View {
        homeScreenView
    }

    var matchesRouteView: some View {
        AthletesHistoryView(
            athletes: registeredAthletes,
            matchHistory: matchHistory,
            onDeleteAthlete: { _ in },
            onDeleteMatch: { matchID in
                deleteMatchHistory(matchID)
            },
            onShareMatch: { record in
                shareMatchHistoryRecord(record)
            },
            title: "Partidas",
            showsCloseButton: false,
            showsAthletesSection: false,
            showsRankingsSections: false,
            showsMatchesSection: true,
            showsMatchFilters: true
        )
    }

    var rankingsRouteView: some View {
        RankingsView(
            matchHistory: matchHistory,
            onShareAthleteRanking: { stats, filterLabel in
                shareAthleteRanking(stats, filterLabel: filterLabel)
            },
            onShareDuoRanking: { stats, filterLabel in
                shareDuoRanking(stats, filterLabel: filterLabel)
            }
        )
    }

    var settingsRouteView: some View {
        GameSettingsView(
            isMatchTimerEnabled: $isMatchTimerEnabled,
            isVoiceAnnouncementEnabled: $isVoiceAnnouncementEnabled,
            athletes: registeredAthletes,
            matchConfigurations: matchConfigurations,
            activeConfigurationID: $selectedMatchConfigurationID,
            onDeleteAthlete: { athlete in
                deleteAthlete(athlete)
            },
            onCreateConfiguration: { name, scoresGamesOnly, games, sets, tieBreakRule, customTieBreakPoints, isSuperTieBreakEnabled in
                createMatchConfiguration(
                    name: name,
                    scoresGamesOnly: scoresGamesOnly,
                    gamesToWinSet: games,
                    matchSetsCount: sets,
                    tieBreakRule: tieBreakRule,
                    customTieBreakPoints: customTieBreakPoints,
                    isSuperTieBreakEnabled: isSuperTieBreakEnabled
                )
            },
            onUpdateConfiguration: { configurationID, name, scoresGamesOnly, games, sets, tieBreakRule, customTieBreakPoints, isSuperTieBreakEnabled in
                updateMatchConfiguration(
                    configurationID,
                    name: name,
                    scoresGamesOnly: scoresGamesOnly,
                    gamesToWinSet: games,
                    matchSetsCount: sets,
                    tieBreakRule: tieBreakRule,
                    customTieBreakPoints: customTieBreakPoints,
                    isSuperTieBreakEnabled: isSuperTieBreakEnabled
                )
            },
            onDeleteConfiguration: { configurationID in
                deleteMatchConfiguration(configurationID)
            },
            showsCloseButton: false,
            showsMatchConfigurationSection: true
        )
    }

    var isMatchRunning: Bool {
        !isHomeScreenVisible && finishedMatchResult == nil
    }

    var activeMatchConfiguration: MatchConfiguration? {
        guard let selectedMatchConfigurationID else { return matchConfigurations.first }
        return matchConfigurations.first(where: { $0.id == selectedMatchConfigurationID }) ?? matchConfigurations.first
    }

    var homeScreenView: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("Nova Partida")
                        .font(.largeTitle.weight(.black))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !matchConfigurations.isEmpty {
                        Menu {
                            ForEach(matchConfigurations) { configuration in
                                Button {
                                    selectedMatchConfigurationID = configuration.id
                                } label: {
                                    if selectedMatchConfigurationID == configuration.id {
                                        Label(configuration.name, systemImage: "checkmark")
                                    } else {
                                        Text(configuration.name)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Configuração da partida")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.secondary)
                                    Text(activeMatchConfiguration?.name ?? "Selecionar")
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.primary)
                                    if let activeMatchConfiguration {
                                        Text("\(activeMatchConfiguration.gamesToWinSet) games por set • \(activeMatchConfiguration.matchSetsCount) sets")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.secondary)

                                        if activeMatchConfiguration.scoresGamesOnly {
                                            HStack(alignment: .top, spacing: 10) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.caption.weight(.black))
                                                    .foregroundColor(.orange)
                                                    .padding(.top, 2)

                                                (
                                                    Text("Somente pontuar Games: ")
                                                        .fontWeight(.black)
                                                        .foregroundColor(.orange) +
                                                    Text("esta configuração não contabiliza pontos dentro dos games. A partida irá registrar somente games e sets.")
                                                        .foregroundColor(.primary.opacity(0.78))
                                                )
                                                .font(.caption)
                                                .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color.orange.opacity(0.12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .padding(.top, 4)
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Times mudam de Lado", isOn: $isSwitchSidesEnabled)
                            .font(.headline.weight(.semibold))

                        Text("Mudança de lado a cada 4 games. Em tie-break e super tie-break, a cada 6 pontos.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Toggle("Modo simples (1x1)", isOn: $isSimpleModeEnabled)
                        .font(.headline.weight(.semibold))
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(spacing: 12) {
                        teamSetupCard(team: "Time Azul", accent: .blue) {
                            playerInputRow(
                                title: "Jogador 1",
                                text: $bluePlayerOneName,
                                athletes: registeredAthletes
                            )
                            if !isSimpleModeEnabled {
                                playerInputRow(
                                    title: "Jogador 2",
                                    text: $bluePlayerTwoName,
                                    athletes: registeredAthletes
                                )
                            }
                        }

                        teamSetupCard(team: "Time Vermelho", accent: .red) {
                            playerInputRow(
                                title: "Jogador 1",
                                text: $redPlayerOneName,
                                athletes: registeredAthletes
                            )
                            if !isSimpleModeEnabled {
                                playerInputRow(
                                    title: "Jogador 2",
                                    text: $redPlayerTwoName,
                                    athletes: registeredAthletes
                                )
                            }
                        }
                    }

                    Button {
                        dismissKeyboard()
                        startConfiguredMatchFromHome()
                    } label: {
                        Label("Iniciar jogo", systemImage: "play.fill")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .contentShape(Rectangle())
                    .alert("Preencha os jogadores", isPresented: $isShowingStartValidationAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(startValidationMessage)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 22)
            }
            .allowsHitTesting(true)
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 10)
        }
        .zIndex(100)
    }

    func teamSetupCard(team: String, accent: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(team)
                .font(.headline.weight(.black))
                .foregroundColor(accent)
                .padding(.horizontal, 2)

            VStack(spacing: 10) {
                content()
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.6), lineWidth: 1.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var timerCard: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timelineContext in
            let elapsed = max(0, frozenMatchElapsedTime ?? timelineContext.date.timeIntervalSince(matchStartDate))
            Text(formattedElapsedTime(elapsed))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.72))
                .clipShape(Capsule())
        }
    }

    func playerInputRow(title: String, text: Binding<String>, athletes: [String]) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 78, alignment: .leading)

            TextField("Nome do atleta", text: text)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Menu {
                ForEach(athletes, id: \.self) { athlete in
                    Button(athlete) {
                        text.wrappedValue = athlete
                    }
                }
            } label: {
                Image(systemName: "person.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(Circle())
            }
            .disabled(athletes.isEmpty)
            .opacity(athletes.isEmpty ? 0.45 : 1)
        }
    }

    func matchFinishedView(result: MatchResult) -> some View {
        ZStack {
            Color(uiColor: .systemBackground)

            VStack(spacing: 20) {
                Text("JOGO FINALIZADO")
                    .font(.title.weight(.black))
                    .foregroundColor(.primary)

                Text("Vencedor: \(displayTeamName(for: result.winner))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)

                Text("\(displayTeamName(for: .blue))  X  \(displayTeamName(for: .red))")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Games: \(result.gamesBlue) - \(result.gamesRed)")
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(.primary)

                if matchSetsCount > 1 {
                    VStack(spacing: 10) {
                        Text("PLACAR DE SETS")
                            .font(.caption.weight(.black))
                            .tracking(1.6)
                            .foregroundColor(.secondary)

                        HStack(spacing: 20) {
                            resultBadge(value: "\(result.setsBlue)", tint: .blue, emphasized: result.winner == .blue)
                            Text("X")
                                .font(.title.weight(.black))
                                .foregroundColor(.secondary.opacity(0.7))
                            resultBadge(value: "\(result.setsRed)", tint: .red, emphasized: result.winner == .red)
                        }
                    }
                }

                if isMatchTimerEnabled {
                    Text("Tempo: \(formattedElapsedTime(result.elapsedTime))")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        shareCurrentMatchResult(result)
                    } label: {
                        Label("Compartilhar partida", systemImage: "square.and.arrow.up.fill")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        startNewMatch()
                    } label: {
                        Label("Iniciar novo jogo", systemImage: "play.circle.fill")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button {
                        goToHomeScreen()
                    } label: {
                        Label("Ir para início", systemImage: "house.fill")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color(uiColor: .secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        goToHistoryScreen()
                    } label: {
                        Label("Ir para histórico", systemImage: "clock.arrow.circlepath")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color(uiColor: .secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.top, 12)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 22)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func resultBadge(value: String, tint: Color, emphasized: Bool) -> some View {
        Text(value)
            .font(.system(size: 38, weight: .black, design: .rounded))
            .foregroundColor(emphasized ? .white : tint)
            .frame(width: 72, height: 72)
            .background(
                Circle()
                    .fill(emphasized ? tint : tint.opacity(0.12))
            )
            .overlay(
                Circle()
                    .stroke(tint.opacity(emphasized ? 0 : 0.35), lineWidth: 2)
            )
            .shadow(color: emphasized ? tint.opacity(0.35) : .clear, radius: 10, x: 0, y: 4)
    }

    // MARK: - Views reutilizáveis

    var blueSide: some View {
        SideView(
            score: displayedScore(for: .blue),
            teamLabel: displayTeamName(for: .blue),
            backgroundColor: .blue,
            showsTennisBall: tennisBallSide == .blue,
            tennisBallAlignment: .leading,
            shouldFlash: isBlueFlashing,
            showCelebration: isShowingGameCelebration,
            celebrationTitle: celebrationKind == .set ? "SET" : "GAME",
            isSetCelebration: celebrationKind == .set,
            isWinner: celebrationWinner == .blue,
            isInteractionEnabled: !isShowingGameCelebration,
            action: { addPoint(for: .blue) }
        )
    }

    var redSide: some View {
        SideView(
            score: displayedScore(for: .red),
            teamLabel: displayTeamName(for: .red),
            backgroundColor: .red,
            showsTennisBall: tennisBallSide == .red,
            tennisBallAlignment: .trailing,
            shouldFlash: isRedFlashing,
            showCelebration: isShowingGameCelebration,
            celebrationTitle: celebrationKind == .set ? "SET" : "GAME",
            isSetCelebration: celebrationKind == .set,
            isWinner: celebrationWinner == .red,
            isInteractionEnabled: !isShowingGameCelebration,
            action: { addPoint(for: .red) }
        )
    }

    func centerOverlay(isLandscape: Bool) -> some View {
        Group {
            if isShowingGameCelebration {
                celebrationGamesIndicator
            } else if isLandscape {
                ZStack {
                    VStack(spacing: 0) {
                        gamesCard
                        Spacer()
                        if !pointHistory.isEmpty {
                            historyCard
                        }
                    }

                    if isMatchTimerEnabled {
                        timerCard
                    }
                }
                .frame(maxHeight: .infinity)
                .frame(width: 150)
                .padding(.top, 20)
                .padding(.bottom, 74)
            } else {
                ZStack {
                    HStack(spacing: 10) {
                        if !pointHistory.isEmpty {
                            historyCard
                        }
                        Spacer()
                        portraitGamesCard
                    }

                    if isMatchTimerEnabled {
                        timerCard
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
            }
        }
    }

    var celebrationGamesIndicator: some View {
        VStack(spacing: 6) {
            Text(celebrationKind == .set ? "SETS" : "GAMES")
                .font(.title2.weight(.black))
                .foregroundColor(.white)

            if celebrationKind == .set && matchSetsCount > 1 {
                Text("\(setsBlue) - \(setsRed)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.green)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.72))
        .clipShape(Capsule())
    }

    var gamesCard: some View {
        VStack(spacing: 3) {
            if matchSetsCount > 1 {
                Text("SETS \(setsBlue) - \(setsRed)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.82))
            }

            Text("GAMES")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))

            Text("\(gamesBlue) - \(gamesRed)")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 78)
        .padding(8)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var historyCard: some View {
        VStack(spacing: 2) {
            ForEach(Array(pointHistory.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: 100, minHeight: 78)
        .padding(8)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var portraitGamesCard: some View {
        VStack(spacing: 0) {
            if matchSetsCount > 1 {
                Text("SETS \(setsBlue) - \(setsRed)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.82))
                    .padding(.top, 4)
            }

            Text("\(gamesBlue)")
                .font(.system(size: 64, weight: .black))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("-")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.92))
                .frame(height: 30)

            Text("\(gamesRed)")
                .font(.system(size: 64, weight: .black))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 108, height: 168)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var bottomBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black.opacity(0.7))
                .frame(height: 68)

            Button {
                undoLastPoint()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 5)
            }
            .disabled(undoStack.isEmpty)
            .opacity(undoStack.isEmpty ? 0.8 : 1)
            .offset(y: -2)
            .zIndex(3)

            HStack {
                Toggle("", isOn: $isVolumeScoringEnabled)
                    .labelsHidden()
                .toggleStyle(.switch)
                .tint(.orange)

                Spacer()
                HStack(spacing: 12) {
                    Button {
                        isShowingAbandonConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Circle())
                    }

                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .zIndex(20)
    }

    // MARK: - Lógica do jogo

    enum Player {
        case blue
        case red
    }

    func addPoint(for player: Player) {
        guard !isShowingGameCelebration else { return }
        guard !isHomeScreenVisible else { return }
        guard finishedMatchResult == nil else { return }

        triggerFlash(for: player)
        pushUndoSnapshot()
        playPointSound()

        switch player {
        case .blue:
            pointsBlue += 1
        case .red:
            pointsRed += 1
        }

        if pointsBlue == 4 {
            finishGame(winner: .blue)
            return
        }

        if pointsRed == 4 {
            finishGame(winner: .red)
            return
        }

        appendHistory("\(tennisScoreText(for: pointsBlue)) - \(tennisScoreText(for: pointsRed))")
        announceCurrentPointScore()
    }

    func triggerFlash(for player: Player) {
        switch player {
        case .blue:
            blueFlashTask?.cancel()
            redFlashTask?.cancel()
            isRedFlashing = false
            withAnimation(.easeIn(duration: 0.08)) {
                isBlueFlashing = true
            }

            blueFlashTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isBlueFlashing = false
                    }
                }
            }

        case .red:
            redFlashTask?.cancel()
            blueFlashTask?.cancel()
            isBlueFlashing = false
            withAnimation(.easeIn(duration: 0.08)) {
                isRedFlashing = true
            }

            redFlashTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isRedFlashing = false
                    }
                }
            }
        }
    }

    func pushUndoSnapshot() {
        undoStack.append(
            GameSnapshot(
                pointsBlue: pointsBlue,
                pointsRed: pointsRed,
                gamesBlue: gamesBlue,
                gamesRed: gamesRed,
                setsBlue: setsBlue,
                setsRed: setsRed,
                pointHistory: pointHistory
            )
        )
    }

    func undoLastPoint() {
        guard let previousState = undoStack.popLast() else { return }

        celebrationTask?.cancel()
        isShowingGameCelebration = false
        celebrationWinner = nil
        celebrationKind = .game
        pointsBlue = previousState.pointsBlue
        pointsRed = previousState.pointsRed
        gamesBlue = previousState.gamesBlue
        gamesRed = previousState.gamesRed
        setsBlue = previousState.setsBlue
        setsRed = previousState.setsRed
        pointHistory = previousState.pointHistory
    }

    func displayedScore(for player: Player) -> String {
        if isShowingGameCelebration {
            if celebrationKind == .set {
                return player == .blue ? "\(setsBlue)" : "\(setsRed)"
            }
            return player == .blue ? "\(gamesBlue)" : "\(gamesRed)"
        }

        return player == .blue ? tennisScoreText(for: pointsBlue) : tennisScoreText(for: pointsRed)
    }

    func tennisScoreText(for points: Int) -> String {
        switch points {
        case 1:
            return "15"
        case 2:
            return "30"
        case 3:
            return "40"
        default:
            return "0"
        }
    }

    func appendHistory(_ item: String) {
        pointHistory.append(item)

        if pointHistory.count > 3 {
            pointHistory.removeFirst(pointHistory.count - 3)
        }
    }

    func resetGame() {
        blueFlashTask?.cancel()
        redFlashTask?.cancel()
        celebrationTask?.cancel()

        pointsBlue = 0
        pointsRed = 0
        gamesBlue = 0
        gamesRed = 0
        setsBlue = 0
        setsRed = 0
        pointHistory.removeAll()
        undoStack.removeAll()
        isBlueFlashing = false
        isRedFlashing = false
        isShowingGameCelebration = false
        celebrationWinner = nil
        celebrationKind = .game
        tennisBallSide = .blue
        matchStartDate = Date()
        frozenMatchElapsedTime = nil
        scoreVoiceReader.stopSpeaking()
    }

    func abandonCurrentMatch() {
        goToHomeScreen()
    }

    func startNewMatch() {
        resetGame()
        finishedMatchResult = nil
        isHomeScreenVisible = false
    }

    func startConfiguredMatchFromHome() {
        let bluePlayers = resolvedPlayers(playerOne: bluePlayerOneName, playerTwo: bluePlayerTwoName)
        let redPlayers = resolvedPlayers(playerOne: redPlayerOneName, playerTwo: redPlayerTwoName)
        let expectedPlayersPerTeam = isSimpleModeEnabled ? 1 : 2

        guard bluePlayers.count == expectedPlayersPerTeam else {
            startValidationMessage = isSimpleModeEnabled ? "Preencha o jogador Azul." : "Preencha os 2 jogadores do time Azul."
            isShowingStartValidationAlert = true
            return
        }

        guard redPlayers.count == expectedPlayersPerTeam else {
            startValidationMessage = isSimpleModeEnabled ? "Preencha o jogador Vermelho." : "Preencha os 2 jogadores do time Vermelho."
            isShowingStartValidationAlert = true
            return
        }

        if let repeatedPlayer = firstRepeatedPlayer(in: bluePlayers + redPlayers) {
            startValidationMessage = "Não é permitido repetir jogador. Nome duplicado: \(repeatedPlayer)."
            isShowingStartValidationAlert = true
            return
        }

        currentMatchBluePlayers = bluePlayers
        currentMatchRedPlayers = redPlayers
        if let selectedMatchConfigurationID {
            activateMatchConfiguration(selectedMatchConfigurationID)
        }
        registerAthletes(bluePlayers + redPlayers)
        startNewMatch()
    }

    func goToHomeScreen() {
        pendingMatchDismissTab = .home
        isHomeScreenVisible = true
    }

    func goToHistoryScreen() {
        pendingMatchDismissTab = .matches
        isHomeScreenVisible = true
    }

    func resolvedPlayers(playerOne: String, playerTwo: String) -> [String] {
        let normalizedOne = playerOne.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTwo = playerTwo.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSimpleModeEnabled {
            return normalizedOne.isEmpty ? [] : [normalizedOne]
        }
        return [normalizedOne, normalizedTwo].filter { !$0.isEmpty }
    }

    func firstRepeatedPlayer(in players: [String]) -> String? {
        var seen: [String: String] = [:]
        for player in players {
            let key = player.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if let existing = seen[key] {
                return existing
            }
            seen[key] = player
        }
        return nil
    }

    func loadPersistedGameState() {
        pointsBlue = storedPointsBlue
        pointsRed = storedPointsRed
        gamesBlue = storedGamesBlue
        gamesRed = storedGamesRed
        setsBlue = storedSetsBlue
        setsRed = storedSetsRed
        pointHistory = storedPointHistory.isEmpty ? [] : storedPointHistory.components(separatedBy: "\n")
    }

    func loadPersistedLastPlayers() {
        bluePlayerOneName = storedBluePlayerOneName
        bluePlayerTwoName = storedBluePlayerTwoName
        redPlayerOneName = storedRedPlayerOneName
        redPlayerTwoName = storedRedPlayerTwoName
    }

    func loadPersistedAthletes() {
        guard let data = storedAthletesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            registeredAthletes = []
            return
        }
        registeredAthletes = decoded
    }

    func loadPersistedMatchHistory() {
        guard let data = storedMatchHistoryJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([MatchHistoryRecord].self, from: data) else {
            matchHistory = []
            return
        }
        matchHistory = decoded.sorted { $0.date > $1.date }
    }

    func loadPersistedMatchConfigurations() {
        let fallback = MatchConfiguration(
            id: UUID(),
            name: "Padrão",
            gamesToWinSet: min(8, max(1, storedGamesToWinSet)),
            matchSetsCount: normalizedMatchSetsCount(storedMatchSetsCount),
            tieBreakRule: .standard,
            customTieBreakPoints: 7,
            isSuperTieBreakEnabled: false
        )

        if let data = storedMatchConfigurationsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([MatchConfiguration].self, from: data),
           !decoded.isEmpty {
            matchConfigurations = decoded
        } else {
            matchConfigurations = [fallback]
            persistMatchConfigurations()
        }

        if let activeID = UUID(uuidString: storedActiveMatchConfigurationID),
           matchConfigurations.contains(where: { $0.id == activeID }) {
            selectedMatchConfigurationID = activeID
        } else {
            selectedMatchConfigurationID = matchConfigurations.first?.id
        }

        if let selectedMatchConfigurationID {
            activateMatchConfiguration(selectedMatchConfigurationID)
        }
    }

    func persistGameState() {
        storedPointsBlue = pointsBlue
        storedPointsRed = pointsRed
        storedGamesBlue = gamesBlue
        storedGamesRed = gamesRed
        storedSetsBlue = setsBlue
        storedSetsRed = setsRed
        storedPointHistory = pointHistory.joined(separator: "\n")
    }

    func persistAthletes() {
        guard let data = try? JSONEncoder().encode(registeredAthletes),
              let encoded = String(data: data, encoding: .utf8) else { return }
        storedAthletesJSON = encoded
    }

    func persistMatchHistory() {
        guard let data = try? JSONEncoder().encode(matchHistory),
              let encoded = String(data: data, encoding: .utf8) else { return }
        storedMatchHistoryJSON = encoded
    }

    func persistMatchConfigurations() {
        guard let data = try? JSONEncoder().encode(matchConfigurations),
              let encoded = String(data: data, encoding: .utf8) else { return }
        storedMatchConfigurationsJSON = encoded
        storedActiveMatchConfigurationID = selectedMatchConfigurationID?.uuidString ?? ""
    }

    func activateMatchConfiguration(_ configurationID: UUID) {
        guard let configuration = matchConfigurations.first(where: { $0.id == configurationID }) else { return }
        selectedMatchConfigurationID = configurationID
        gamesToWinSet = configuration.gamesToWinSet
        matchSetsCount = configuration.matchSetsCount
        storedActiveMatchConfigurationID = configurationID.uuidString
    }

    func createMatchConfiguration(
        name: String,
        scoresGamesOnly: Bool,
        gamesToWinSet: Int,
        matchSetsCount: Int,
        tieBreakRule: TieBreakRule,
        customTieBreakPoints: Int,
        isSuperTieBreakEnabled: Bool
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSets = normalizedMatchSetsCount(matchSetsCount)
        let configuration = MatchConfiguration(
            id: UUID(),
            name: trimmedName.isEmpty ? "Configuração \(matchConfigurations.count + 1)" : trimmedName,
            scoresGamesOnly: scoresGamesOnly,
            gamesToWinSet: min(9, max(1, gamesToWinSet)),
            matchSetsCount: normalizedSets,
            tieBreakRule: scoresGamesOnly ? .disabled : tieBreakRule,
            customTieBreakPoints: min(10, max(1, customTieBreakPoints)),
            isSuperTieBreakEnabled: isSuperTieBreakEnabled && normalizedSets >= 3
        )
        matchConfigurations.append(configuration)
        selectedMatchConfigurationID = configuration.id
        activateMatchConfiguration(configuration.id)
        persistMatchConfigurations()
    }

    func updateMatchConfiguration(
        _ configurationID: UUID,
        name: String,
        scoresGamesOnly: Bool,
        gamesToWinSet: Int,
        matchSetsCount: Int,
        tieBreakRule: TieBreakRule,
        customTieBreakPoints: Int,
        isSuperTieBreakEnabled: Bool
    ) {
        guard let index = matchConfigurations.firstIndex(where: { $0.id == configurationID }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSets = normalizedMatchSetsCount(matchSetsCount)
        matchConfigurations[index].name = trimmedName.isEmpty ? matchConfigurations[index].name : trimmedName
        matchConfigurations[index].scoresGamesOnly = scoresGamesOnly
        matchConfigurations[index].gamesToWinSet = min(9, max(1, gamesToWinSet))
        matchConfigurations[index].matchSetsCount = normalizedSets
        matchConfigurations[index].tieBreakRule = scoresGamesOnly ? .disabled : tieBreakRule
        matchConfigurations[index].customTieBreakPoints = min(10, max(1, customTieBreakPoints))
        matchConfigurations[index].isSuperTieBreakEnabled = isSuperTieBreakEnabled && normalizedSets >= 3

        if selectedMatchConfigurationID == configurationID {
            activateMatchConfiguration(configurationID)
        }
        persistMatchConfigurations()
    }

    func deleteMatchConfiguration(_ configurationID: UUID) {
        guard matchConfigurations.count > 1 else { return }
        matchConfigurations.removeAll { $0.id == configurationID }

        if !matchConfigurations.contains(where: { $0.id == selectedMatchConfigurationID }) {
            selectedMatchConfigurationID = matchConfigurations.first?.id
        }

        if let selectedMatchConfigurationID {
            activateMatchConfiguration(selectedMatchConfigurationID)
        }
        persistMatchConfigurations()
    }

    func registerAthletes(_ athletes: [String]) {
        var snapshot = registeredAthletes
        for athlete in athletes {
            let normalized = athlete.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            if !snapshot.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                snapshot.append(normalized)
            }
        }
        registeredAthletes = snapshot.sorted()
        persistAthletes()
    }

    func deleteAthlete(_ athlete: String) {
        registeredAthletes.removeAll { $0 == athlete }
        persistAthletes()
    }

    func deleteMatchHistory(_ matchID: UUID) {
        matchHistory.removeAll { $0.id == matchID }
        persistMatchHistory()
    }

    func shareMatchHistoryRecord(_ record: MatchHistoryRecord) {
        let summary = MatchShareSummary(
            date: record.date,
            isSimpleMode: record.isSimpleMode,
            bluePlayers: record.bluePlayers,
            redPlayers: record.redPlayers,
            gamesBlue: record.gamesBlue,
            gamesRed: record.gamesRed,
            winnerPlayers: record.winnerTeam == "blue" ? record.bluePlayers : record.redPlayers,
            elapsedTime: record.elapsedTime
        )
        shareExportedSummary(summary)
    }

    func shareCurrentMatchResult(_ result: MatchResult) {
        let bluePlayers = currentMatchBluePlayers.isEmpty ? ["Time Azul"] : currentMatchBluePlayers
        let redPlayers = currentMatchRedPlayers.isEmpty ? ["Time Vermelho"] : currentMatchRedPlayers
        let summary = MatchShareSummary(
            date: Date(),
            isSimpleMode: isSimpleModeEnabled,
            bluePlayers: bluePlayers,
            redPlayers: redPlayers,
            gamesBlue: result.gamesBlue,
            gamesRed: result.gamesRed,
            winnerPlayers: result.winner == .blue ? bluePlayers : redPlayers,
            elapsedTime: result.elapsedTime
        )
        shareExportedSummary(summary)
    }

    func shareExportedSummary(_ summary: MatchShareSummary) {
        guard let image = exportMatchSummaryImage(summary) else { return }
        presentShareSheet(image: image)
    }

    func shareAthleteRanking(_ stats: [(name: String, wins: Int, losses: Int)], filterLabel: String) {
        let entries = stats.enumerated().map { index, stat in
            let matches = stat.wins + stat.losses
            let winRate = matches == 0 ? 0 : Int((Double(stat.wins) / Double(matches)) * 100)
            return RankingShareEntry(
                rank: index + 1,
                title: stat.name,
                subtitle: "Atleta",
                wins: stat.wins,
                losses: stat.losses,
                matches: matches,
                winRate: winRate
            )
        }

        let summary = RankingShareSummary(
            title: "Resultado por atleta",
            subtitle: "Desempenho individual",
            filterLabel: filterLabel,
            generatedAt: Date(),
            entries: entries
        )
        shareRankingSummary(summary)
    }

    func shareDuoRanking(_ stats: [(duo: String, wins: Int, losses: Int)], filterLabel: String) {
        let entries = stats.enumerated().map { index, stat in
            let matches = stat.wins + stat.losses
            let winRate = matches == 0 ? 0 : Int((Double(stat.wins) / Double(matches)) * 100)
            return RankingShareEntry(
                rank: index + 1,
                title: stat.duo,
                subtitle: "Dupla",
                wins: stat.wins,
                losses: stat.losses,
                matches: matches,
                winRate: winRate
            )
        }

        let summary = RankingShareSummary(
            title: "Resultado por dupla",
            subtitle: "Desempenho das parcerias",
            filterLabel: filterLabel,
            generatedAt: Date(),
            entries: entries
        )
        shareRankingSummary(summary)
    }

    func shareRankingSummary(_ summary: RankingShareSummary) {
        guard let image = exportRankingSummaryImage(summary) else { return }
        presentShareSheet(image: image)
    }

    func exportMatchSummaryImage(_ summary: MatchShareSummary) -> UIImage? {
        let card = MatchExportCardView(summary: summary)
            .frame(width: 1080, height: 1350)
            .background(Color.white)

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale

        return renderer.uiImage
    }

    func exportRankingSummaryImage(_ summary: RankingShareSummary) -> UIImage? {
        let card = RankingExportCardView(summary: summary)
            .frame(width: 1080, height: 1350)
            .background(Color.white)

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale

        return renderer.uiImage
    }

    func presentShareSheet(image: UIImage) {
        guard let presenter = topMostViewController() else { return }
        let activityController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activityController, animated: true)
    }

    func topMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    func playPointSound() {
        AudioServicesPlaySystemSound(1104)
    }

    func playGameWonSound() {
        if let url = victorySoundURL() {
            do {
                gameWonAudioPlayer = try AVAudioPlayer(contentsOf: url)
                gameWonAudioPlayer?.prepareToPlay()
                gameWonAudioPlayer?.volume = 1.0
                gameWonAudioPlayer?.play()
                return
            } catch {
                print("Victory sound error: \(error.localizedDescription)")
            }
        }

        AudioServicesPlaySystemSound(1025)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func finishGame(winner: Player) {
        switch winner {
        case .blue:
            gamesBlue += 1
            appendHistory("GAME AZUL")
        case .red:
            gamesRed += 1
            appendHistory("GAME VERMELHO")
        }

        pointsBlue = 0
        pointsRed = 0
        toggleTennisBallSide()
        playGameWonSound()
        announceGameWinner(winner)

        let didReachSetEnd = gamesBlue >= gamesToWinSet || gamesRed >= gamesToWinSet
        if didReachSetEnd {
            finishSet(winner: winner)
            return
        }

        startGameCelebration(winner: winner)
    }

    func finishSet(winner: Player) {
        switch winner {
        case .blue:
            setsBlue += 1
            appendHistory("SET AZUL")
        case .red:
            setsRed += 1
            appendHistory("SET VERMELHO")
        }

        let didReachMatchEnd = setsBlue >= setsNeededToWinMatch || setsRed >= setsNeededToWinMatch
        if didReachMatchEnd {
            finishMatch(winner: winner)
            return
        }

        announceSetWinner(winner)
        startGameCelebration(winner: winner, kind: .set) {
            gamesBlue = 0
            gamesRed = 0
            pointsBlue = 0
            pointsRed = 0
        }
    }

    func finishMatch(winner: Player) {
        blueFlashTask?.cancel()
        redFlashTask?.cancel()
        celebrationTask?.cancel()
        isBlueFlashing = false
        isRedFlashing = false
        isShowingGameCelebration = false
        celebrationWinner = nil
        celebrationKind = .game
        frozenMatchElapsedTime = max(0, Date().timeIntervalSince(matchStartDate))
        finishedMatchResult = MatchResult(
            winner: winner,
            gamesBlue: gamesBlue,
            gamesRed: gamesRed,
            setsBlue: setsBlue,
            setsRed: setsRed,
            elapsedTime: frozenMatchElapsedTime ?? 0
        )
        appendMatchHistory(winner: winner)
        announceMatchFinished(winner: winner)
    }

    func appendMatchHistory(winner: Player) {
        let winnerTeam = winner == .blue ? "blue" : "red"
        let bluePlayers = currentMatchBluePlayers.isEmpty ? ["Time Azul"] : currentMatchBluePlayers
        let redPlayers = currentMatchRedPlayers.isEmpty ? ["Time Vermelho"] : currentMatchRedPlayers
        let record = MatchHistoryRecord(
            id: UUID(),
            date: Date(),
            isSimpleMode: isSimpleModeEnabled,
            bluePlayers: bluePlayers,
            redPlayers: redPlayers,
            gamesBlue: gamesBlue,
            gamesRed: gamesRed,
            winnerTeam: winnerTeam,
            elapsedTime: frozenMatchElapsedTime
        )
        matchHistory.insert(record, at: 0)
        persistMatchHistory()
    }

    func startGameCelebration(winner: Player, kind: CelebrationKind = .game, completion: (() -> Void)? = nil) {
        celebrationTask?.cancel()
        celebrationWinner = winner
        celebrationKind = kind
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingGameCelebration = true
        }

        celebrationTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isShowingGameCelebration = false
                }
                celebrationWinner = nil
                celebrationKind = .game
                completion?()
            }
        }
    }

    func victorySoundURL() -> URL? {
        let soundNames = ["victory_applause", "applause_victory", "applause", "victory"]
        let extensions = ["m4a", "mp3", "wav", "aiff", "caf"]

        for name in soundNames {
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }

        return nil
    }

    var setsNeededToWinMatch: Int {
        (matchSetsCount / 2) + 1
    }

    func normalizedMatchSetsCount(_ value: Int) -> Int {
        [1, 3, 5, 7].contains(value) ? value : 1
    }

    func toggleTennisBallSide() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            tennisBallSide = tennisBallSide == .blue ? .red : .blue
        }
    }

    func updateVolumeButtonBehavior() {
        let isMatchRunning = !isHomeScreenVisible && finishedMatchResult == nil
        guard isVolumeScoringEnabled && isMatchRunning else {
            volumeButtonObserver.stop()
            return
        }

        volumeButtonObserver.onVolumeUp = {
            addPoint(for: .blue)
        }
        volumeButtonObserver.onVolumeDown = {
            addPoint(for: .red)
        }
        volumeButtonObserver.start()
    }

    func formattedElapsedTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(timeInterval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func displayTeamName(for player: Player) -> String {
        let players = player == .blue ? currentMatchBluePlayers : currentMatchRedPlayers
        if players.isEmpty {
            return player == .blue ? "Time Azul" : "Time Vermelho"
        }

        if players.count >= 2 {
            return players.map { player in
                let trimmed = player.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let first = trimmed.first else { return "" }
                return String(first).uppercased()
            }
            .joined(separator: "  ")
        }

        let firstName = players[0].split(separator: " ").first.map(String.init) ?? players[0]
        if firstName.count <= 10 {
            return firstName
        }

        guard let initial = firstName.first else { return firstName }
        return String(initial).uppercased()
    }

    func announceCurrentPointScore() {
        guard isVoiceAnnouncementEnabled else { return }

        let blueScore = tennisScoreText(for: pointsBlue)
        let redScore = tennisScoreText(for: pointsRed)
        let text = "Azul \(blueScore). Vermelho \(redScore)."
        scoreVoiceReader.speak(text)
    }

    func announceGameWinner(_ winner: Player) {
        guard isVoiceAnnouncementEnabled else { return }

        let winnerText = winner == .blue ? "Time azul" : "Time vermelho"
        let text = "Game \(winnerText). Placar de games, \(gamesBlue) a \(gamesRed)."
        scoreVoiceReader.speak(text)
    }

    func announceSetWinner(_ winner: Player) {
        guard isVoiceAnnouncementEnabled else { return }

        let winnerText = winner == .blue ? "Time azul" : "Time vermelho"
        let text = "Set \(winnerText). Placar de sets, \(setsBlue) a \(setsRed)."
        scoreVoiceReader.speak(text)
    }

    func announceMatchFinished(winner: Player) {
        guard isVoiceAnnouncementEnabled else { return }

        let winnerText = winner == .blue ? "Time azul" : "Time vermelho"
        let text: String
        if matchSetsCount > 1 {
            text = "Partida finalizada. Vencedor: \(winnerText). Placar final de sets, \(setsBlue) a \(setsRed). Último set em games, \(gamesBlue) a \(gamesRed)."
        } else {
            text = "Partida finalizada. Vencedor: \(winnerText). Placar final de games, \(gamesBlue) a \(gamesRed)."
        }
        scoreVoiceReader.speak(text)
    }
}

#Preview {
    ContentViewTenis()
}
