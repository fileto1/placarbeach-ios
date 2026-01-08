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

    struct GameSnapshot {
        let pointsBlue: Int
        let pointsRed: Int
        let gamesBlue: Int
        let gamesRed: Int
        let pointHistory: [String]
    }

    struct MatchResult {
        let winner: Player
        let gamesBlue: Int
        let gamesRed: Int
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
    @State private var celebrationTask: Task<Void, Never>?
    @State private var gameWonAudioPlayer: AVAudioPlayer?
    @State private var isSettingsPresented = false
    @State private var isShowingAbandonConfirmation = false
    @StateObject private var volumeButtonObserver = VolumeButtonObserver()
    @StateObject private var scoreVoiceReader = ScoreVoiceReader()
    @SceneStorage("tenis_volume_scoring_enabled") private var isVolumeScoringEnabled = true
    @SceneStorage("tenis_voice_announcement_enabled") private var isVoiceAnnouncementEnabled = true
    @SceneStorage("tenis_match_timer_enabled") private var isMatchTimerEnabled = false
    @SceneStorage("tenis_games_to_win_set") private var storedGamesToWinSet = 6
    @SceneStorage("tenis_points_blue") private var storedPointsBlue = 0
    @SceneStorage("tenis_points_red") private var storedPointsRed = 0
    @SceneStorage("tenis_games_blue") private var storedGamesBlue = 0
    @SceneStorage("tenis_games_red") private var storedGamesRed = 0
    @SceneStorage("tenis_point_history") private var storedPointHistory = ""
    @AppStorage("tenis_simple_mode_enabled") private var isSimpleModeEnabled = false
    @AppStorage("tenis_registered_athletes_json") private var storedAthletesJSON = "[]"
    @AppStorage("tenis_match_history_json") private var storedMatchHistoryJSON = "[]"
    @State private var gamesToWinSet = 6
    @State private var matchStartDate = Date()
    @State private var frozenMatchElapsedTime: TimeInterval?
    @State private var isHomeScreenVisible = true
    @State private var finishedMatchResult: MatchResult?
    @State private var bluePlayerOneName = ""
    @State private var bluePlayerTwoName = ""
    @State private var redPlayerOneName = ""
    @State private var redPlayerTwoName = ""
    @State private var currentMatchBluePlayers: [String] = []
    @State private var currentMatchRedPlayers: [String] = []
    @State private var registeredAthletes: [String] = []
    @State private var matchHistory: [MatchHistoryRecord] = []
    @State private var isAthletesHistoryPresented = false
    @State private var startValidationMessage = ""
    @State private var isShowingStartValidationAlert = false
    @State private var sharePayload: SharePayload?

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                if isHomeScreenVisible {
                    homeScreenView
                } else if let result = finishedMatchResult {
                    matchFinishedView(result: result)
                } else {
                    if isLandscape {
                        // LANDSCAPE → divisão vertical
                        HStack(spacing: 0) {
                            blueSide
                            redSide
                        }
                    } else {
                        // PORTRAIT → divisão horizontal
                        VStack(spacing: 0) {
                            blueSide
                            redSide
                        }
                    }

                    centerOverlay(isLandscape: isLandscape)
                }
            }
            .overlay(alignment: .bottom) {
                if !isHomeScreenVisible && finishedMatchResult == nil {
                    bottomBar
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            gamesToWinSet = min(8, max(1, storedGamesToWinSet))
            loadPersistedGameState()
            loadPersistedAthletes()
            loadPersistedMatchHistory()
            updateVolumeButtonBehavior()
        }
        .onDisappear {
            volumeButtonObserver.stop()
        }
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
        .onChange(of: pointHistory) { _, _ in
            persistGameState()
        }
        .onChange(of: gamesToWinSet) { _, newValue in
            let normalizedValue = min(8, max(1, newValue))
            if normalizedValue != gamesToWinSet {
                gamesToWinSet = normalizedValue
            }
            storedGamesToWinSet = normalizedValue
        }
        .onChange(of: isHomeScreenVisible) { _, _ in
            updateVolumeButtonBehavior()
        }
        .onChange(of: finishedMatchResult != nil) { _, _ in
            updateVolumeButtonBehavior()
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            GameSettingsView(
                isMatchTimerEnabled: $isMatchTimerEnabled,
                isVoiceAnnouncementEnabled: $isVoiceAnnouncementEnabled,
                gamesToWinSet: $gamesToWinSet
            )
        }
        .sheet(isPresented: $isAthletesHistoryPresented) {
            AthletesHistoryView(
                athletes: registeredAthletes,
                matchHistory: matchHistory,
                onDeleteAthlete: { athlete in
                    deleteAthlete(athlete)
                },
                onDeleteMatch: { matchID in
                    deleteMatchHistory(matchID)
                },
                onShareMatch: { record in
                    shareMatchHistoryRecord(record)
                }
            )
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: [payload.image])
        }
        .alert("Finalizar game?", isPresented: $isShowingAbandonConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Finalizar", role: .destructive) {
                abandonCurrentMatch()
            }
        } message: {
            Text("Deseja realmente finalizar o game atual e zerar o placar?")
        }
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
                        Text("Iniciar jogo")
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

                    HStack(spacing: 12) {
                        Button {
                            isSettingsPresented = true
                        } label: {
                            Text("Configurações")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color(uiColor: .secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            isAthletesHistoryPresented = true
                        } label: {
                            Text("Atletas e histórico")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color(uiColor: .secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
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
            Color(uiColor: .systemBackground).ignoresSafeArea()

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

                if isMatchTimerEnabled {
                    Text("Tempo: \(formattedElapsedTime(result.elapsedTime))")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        shareCurrentMatchResult(result)
                    } label: {
                        Text("Compartilhar partida")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        startNewMatch()
                    } label: {
                        Text("Iniciar novo jogo")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button {
                        goToHomeScreen()
                    } label: {
                        Text("Ir para início")
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
        }
    }

    // MARK: - Views reutilizáveis

    var blueSide: some View {
        SideView(
            score: displayedScore(for: .blue),
            teamLabel: displayTeamName(for: .blue),
            backgroundColor: .blue,
            shouldFlash: isBlueFlashing,
            showCelebration: isShowingGameCelebration,
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
            shouldFlash: isRedFlashing,
            showCelebration: isShowingGameCelebration,
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
        Text("GAMES")
            .font(.title2.weight(.black))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.65))
            .clipShape(Capsule())
    }

    var gamesCard: some View {
        VStack(spacing: 3) {
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
                pointHistory: pointHistory
            )
        )
    }

    func undoLastPoint() {
        guard let previousState = undoStack.popLast() else { return }

        celebrationTask?.cancel()
        isShowingGameCelebration = false
        celebrationWinner = nil
        pointsBlue = previousState.pointsBlue
        pointsRed = previousState.pointsRed
        gamesBlue = previousState.gamesBlue
        gamesRed = previousState.gamesRed
        pointHistory = previousState.pointHistory
    }

    func displayedScore(for player: Player) -> String {
        if isShowingGameCelebration {
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
        pointHistory.removeAll()
        undoStack.removeAll()
        isBlueFlashing = false
        isRedFlashing = false
        isShowingGameCelebration = false
        celebrationWinner = nil
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

        currentMatchBluePlayers = bluePlayers
        currentMatchRedPlayers = redPlayers
        registerAthletes(bluePlayers + redPlayers)
        startNewMatch()
    }

    func goToHomeScreen() {
        resetGame()
        finishedMatchResult = nil
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

    func loadPersistedGameState() {
        pointsBlue = storedPointsBlue
        pointsRed = storedPointsRed
        gamesBlue = storedGamesBlue
        gamesRed = storedGamesRed
        pointHistory = storedPointHistory.isEmpty ? [] : storedPointHistory.components(separatedBy: "\n")
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

    func persistGameState() {
        storedPointsBlue = pointsBlue
        storedPointsRed = pointsRed
        storedGamesBlue = gamesBlue
        storedGamesRed = gamesRed
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
            blueTeam: record.bluePlayers.joined(separator: " + "),
            redTeam: record.redPlayers.joined(separator: " + "),
            gamesBlue: record.gamesBlue,
            gamesRed: record.gamesRed,
            winnerText: record.winnerTeam == "blue" ? record.bluePlayers.joined(separator: " + ") : record.redPlayers.joined(separator: " + ")
        )
        exportMatchSummaryImage(summary)
    }

    func shareCurrentMatchResult(_ result: MatchResult) {
        let summary = MatchShareSummary(
            date: Date(),
            isSimpleMode: isSimpleModeEnabled,
            blueTeam: displayTeamName(for: .blue),
            redTeam: displayTeamName(for: .red),
            gamesBlue: result.gamesBlue,
            gamesRed: result.gamesRed,
            winnerText: displayTeamName(for: result.winner)
        )
        exportMatchSummaryImage(summary)
    }

    func exportMatchSummaryImage(_ summary: MatchShareSummary) {
        let card = MatchExportCardView(summary: summary)
            .frame(width: 1080, height: 1350)
            .background(Color.white)

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else { return }
        sharePayload = SharePayload(image: image)
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
        playGameWonSound()
        announceGameWinner(winner)

        let didReachSetEnd = gamesBlue >= gamesToWinSet || gamesRed >= gamesToWinSet
        if didReachSetEnd {
            finishMatch(winner: winner)
            return
        }

        startGameCelebration(winner: winner)
    }

    func finishMatch(winner: Player) {
        blueFlashTask?.cancel()
        redFlashTask?.cancel()
        celebrationTask?.cancel()
        isBlueFlashing = false
        isRedFlashing = false
        isShowingGameCelebration = false
        celebrationWinner = nil
        frozenMatchElapsedTime = max(0, Date().timeIntervalSince(matchStartDate))
        finishedMatchResult = MatchResult(
            winner: winner,
            gamesBlue: gamesBlue,
            gamesRed: gamesRed,
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
            winnerTeam: winnerTeam
        )
        matchHistory.insert(record, at: 0)
        persistMatchHistory()
    }

    func startGameCelebration(winner: Player) {
        celebrationTask?.cancel()
        celebrationWinner = winner
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

    func announceMatchFinished(winner: Player) {
        guard isVoiceAnnouncementEnabled else { return }

        let winnerText = winner == .blue ? "Time azul" : "Time vermelho"
        let text = "Partida finalizada. Vencedor: \(winnerText). Placar final de games, \(gamesBlue) a \(gamesRed)."
        scoreVoiceReader.speak(text)
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MatchShareSummary {
    let date: Date
    let isSimpleMode: Bool
    let blueTeam: String
    let redTeam: String
    let gamesBlue: Int
    let gamesRed: Int
    let winnerText: String
}

final class VolumeButtonObserver: ObservableObject {
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?

    private let audioSession = AVAudioSession.sharedInstance()
    private var volumeObservation: NSKeyValueObservation?
    private weak var volumeSlider: UISlider?
    private var hiddenVolumeView: MPVolumeView?
    private var lastVolume: Float = 0.5
    private var isAdjustingVolumeInternally = false
    private let neutralVolume: Float = 0.5

    func start() {
        configureAudioSession()
        ensureVolumeView()

        lastVolume = audioSession.outputVolume
        if lastVolume <= 0.05 || lastVolume >= 0.95 {
            setSystemVolume(neutralVolume)
            lastVolume = neutralVolume
        }

        volumeObservation?.invalidate()
        volumeObservation = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let self, let newVolume = change.newValue else { return }
            handleVolumeChange(newVolume)
        }
    }

    func stop() {
        volumeObservation?.invalidate()
        volumeObservation = nil
        onVolumeUp = nil
        onVolumeDown = nil
        volumeSlider = nil
        hiddenVolumeView?.removeFromSuperview()
        hiddenVolumeView = nil
    }

    deinit {
        stop()
    }

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: [])
        } catch {
            print("Volume observer audio session error: \(error.localizedDescription)")
        }
    }

    private func ensureVolumeView() {
        if hiddenVolumeView == nil {
            let volumeView = MPVolumeView(frame: .zero)
            volumeView.alpha = 0.01
            volumeView.isUserInteractionEnabled = false
            hiddenVolumeView = volumeView

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(volumeView)
            }
        }

        if volumeSlider == nil, let volumeView = hiddenVolumeView {
            volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first
        }
    }

    private func handleVolumeChange(_ newVolume: Float) {
        if isAdjustingVolumeInternally {
            isAdjustingVolumeInternally = false
            lastVolume = newVolume
            return
        }

        if newVolume > lastVolume {
            onVolumeUp?()
        } else if newVolume < lastVolume {
            onVolumeDown?()
        }

        lastVolume = newVolume

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.setSystemVolume(self?.neutralVolume ?? 0.5)
        }
    }

    private func setSystemVolume(_ value: Float) {
        guard let slider = volumeSlider else { return }
        isAdjustingVolumeInternally = true
        slider.setValue(value, animated: false)
        slider.sendActions(for: .touchUpInside)
    }
}

struct SideView: View {

    let score: String
    let teamLabel: String
    let backgroundColor: Color
    let shouldFlash: Bool
    let showCelebration: Bool
    let isWinner: Bool
    let isInteractionEnabled: Bool
    let action: () -> Void
    @State private var scorePulse = false
    @State private var celebrationPulse = false
    @State private var celebrationPulseTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                Color.green
                    .opacity(shouldFlash ? 0.8 : 0)
                if showCelebration {
                    Color.green.opacity(isWinner ? (celebrationPulse ? 0.42 : 0.12) : 0)
                }

                VStack(spacing: 8) {
                    Text(teamLabel)
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.12, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, 12)

                    if showCelebration && isWinner {
                        Text("GAME")
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.11, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .scaleEffect(celebrationPulse ? 1.06 : 0.96)
                            .opacity(celebrationPulse ? 1 : 0.9)
                    }

                    Text(score)
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.56, weight: .black))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .scaleEffect(
                            showCelebration && isWinner
                            ? (celebrationPulse ? 1.08 : 0.94)
                            : (scorePulse ? 1.13 : 1)
                        )
                        .opacity(scorePulse ? 0.86 : 1)

                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(showCelebration && isWinner ? (celebrationPulse ? 1.02 : 0.99) : 1)
            .shadow(
                color: showCelebration && isWinner ? .green.opacity(celebrationPulse ? 0.55 : 0.25) : .clear,
                radius: showCelebration && isWinner ? (celebrationPulse ? 20 : 8) : 0
            )
            .animation(.easeInOut(duration: 0.18), value: shouldFlash)
            .animation(.spring(response: 0.35, dampingFraction: 0.62), value: scorePulse)
            .onChange(of: score) { _, _ in
                scorePulse = true
                Task {
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    await MainActor.run {
                        scorePulse = false
                    }
                }
            }
            .onChange(of: showCelebration) { _, newValue in
                updateCelebrationPulseLoop(isCelebrating: newValue, isWinner: isWinner)
            }
            .onChange(of: isWinner) { _, newValue in
                updateCelebrationPulseLoop(isCelebrating: showCelebration, isWinner: newValue)
            }
            .onAppear {
                updateCelebrationPulseLoop(isCelebrating: showCelebration, isWinner: isWinner)
            }
            .onDisappear {
                celebrationPulseTask?.cancel()
                celebrationPulseTask = nil
            }
            .onTapGesture {
                guard isInteractionEnabled else { return }
                action()
            }
        }
    }

    private func updateCelebrationPulseLoop(isCelebrating: Bool, isWinner: Bool) {
        celebrationPulseTask?.cancel()
        celebrationPulseTask = nil

        guard isCelebrating && isWinner else {
            celebrationPulse = false
            return
        }

        celebrationPulse = false
        celebrationPulseTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        celebrationPulse.toggle()
                    }
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}

struct GameSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isMatchTimerEnabled: Bool
    @Binding var isVoiceAnnouncementEnabled: Bool
    @Binding var gamesToWinSet: Int
    @State private var isGamesPickerPresented = false
    @State private var pickerValue = 6

    var body: some View {
        NavigationStack {
            Form {
                Section("Partida") {
                    Toggle("Mostrar timer em tela", isOn: $isMatchTimerEnabled)
                    Toggle("Leitura de voz dos pontos", isOn: $isVoiceAnnouncementEnabled)

                    Button {
                        pickerValue = min(8, max(1, gamesToWinSet))
                        isGamesPickerPresented = true
                    } label: {
                        HStack {
                            Text("Games para fechar set")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(gamesToWinSet)")
                                .font(.title3.weight(.black))
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                gamesToWinSet = min(8, max(1, gamesToWinSet))
                pickerValue = gamesToWinSet
            }
            .sheet(isPresented: $isGamesPickerPresented) {
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Text("Games Para Fechar Set")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        Text("Deslize para cima ou para baixo")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 8)

                    Text("\(pickerValue)")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)

                    Picker("Games para fechar set", selection: $pickerValue) {
                        ForEach(1...8, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipped()

                    HStack(spacing: 12) {
                        Button {
                            isGamesPickerPresented = false
                        } label: {
                            Text("Cancelar")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color(uiColor: .secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            gamesToWinSet = pickerValue
                            isGamesPickerPresented = false
                        } label: {
                            Text("OK")
                                .font(.headline.weight(.black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .background(Color(uiColor: .systemBackground))
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct AthletesHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let athletes: [String]
    let matchHistory: [ContentViewTenis.MatchHistoryRecord]
    let onDeleteAthlete: (String) -> Void
    let onDeleteMatch: (UUID) -> Void
    let onShareMatch: (ContentViewTenis.MatchHistoryRecord) -> Void
    @State private var pendingDeletion: PendingDeletion?

    var body: some View {
        NavigationStack {
            List {
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

                Section("Histórico por atleta") {
                    let stats = athleteStats()
                    if stats.isEmpty {
                        Text("Sem partidas registradas.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(stats, id: \.name) { stat in
                            HStack {
                                Text(stat.name)
                                Spacer()
                                Text("V \(stat.wins)  •  D \(stat.losses)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Histórico por dupla") {
                    let stats = duoStats()
                    if stats.isEmpty {
                        Text("Sem duplas registradas.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(stats, id: \.duo) { stat in
                            HStack {
                                Text(stat.duo)
                                Spacer()
                                Text("V \(stat.wins)  •  D \(stat.losses)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Partidas") {
                    if matchHistory.isEmpty {
                        Text("Nenhuma partida finalizada.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(matchHistory) { record in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(record.bluePlayers.joined(separator: " + "))  X  \(record.redPlayers.joined(separator: " + "))")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Games: \(record.gamesBlue) - \(record.gamesRed)")
                                        .font(.subheadline)
                                    Text("Vencedor: \(record.winnerTeam == "blue" ? "Azul" : "Vermelho") • \(record.isSimpleMode ? "Simples" : "Duplas")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer(minLength: 0)
                                Button {
                                    onShareMatch(record)
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    pendingDeletion = .match(id: record.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Atletas e histórico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
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
        for record in matchHistory {
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
        for record in matchHistory {
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
}

struct MatchExportCardView: View {
    let summary: MatchShareSummary

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, Color(uiColor: .systemGray6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .center) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.accentColor)
                                .frame(width: 64, height: 64)
                            Text("PB")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Placar Beach")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Resumo da partida")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 14) {
                    exportLine(title: "Data", value: summary.date.formatted(date: .abbreviated, time: .shortened))
                    exportLine(title: "Modo", value: summary.isSimpleMode ? "Simples (1x1)" : "Duplas (2x2)")
                    exportLine(title: "Time Azul", value: summary.blueTeam)
                    exportLine(title: "Time Vermelho", value: summary.redTeam)
                    exportLine(title: "Games", value: "\(summary.gamesBlue) x \(summary.gamesRed)")
                    exportLine(title: "Vencedor", value: summary.winnerText)
                }
                .padding(22)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                )

                Spacer()
            }
            .padding(34)
        }
    }

    func exportLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

final class ScoreVoiceReader: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        stopSpeaking()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }
}

#Preview {
    ContentViewTenis()
}
