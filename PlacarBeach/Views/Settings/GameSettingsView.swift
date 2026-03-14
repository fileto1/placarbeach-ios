import SwiftUI

struct GameSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isMatchTimerEnabled: Bool
    @Binding var isVoiceAnnouncementEnabled: Bool
    let athletes: [String]
    let matchConfigurations: [ContentViewTenis.MatchConfiguration]
    @Binding var activeConfigurationID: UUID?
    let onDeleteAthlete: (String) -> Void
    let onCreateConfiguration: (String, Bool, Int, Int, ContentViewTenis.TieBreakRule, Int, Bool) -> Void
    let onUpdateConfiguration: (UUID, String, Bool, Int, Int, ContentViewTenis.TieBreakRule, Int, Bool) -> Void
    let onDeleteConfiguration: (UUID) -> Void
    var showsCloseButton = true
    var showsMatchConfigurationSection = true
    @State private var isCreateSheetPresented = false
    @State private var editingConfigurationID: UUID?
    @State private var pendingDeletionConfiguration: ContentViewTenis.MatchConfiguration?
    @State private var pendingDeletionAthlete: String?
    @State private var newConfigurationName = ""
    @State private var newScoresGamesOnly = false
    @State private var newGamesToWinSet = 6
    @State private var newMatchSetsCount = 1
    @State private var newTieBreakRule: ContentViewTenis.TieBreakRule = .standard
    @State private var newCustomTieBreakPoints = 7
    @State private var newIsSuperTieBreakEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Geral") {
                    Toggle("Mostrar timer em tela", isOn: $isMatchTimerEnabled)
                    Toggle("Leitura de voz dos pontos", isOn: $isVoiceAnnouncementEnabled)
                }

                if showsMatchConfigurationSection {
                    Section("Configurações da partida") {
                        ForEach(matchConfigurations) { configuration in
                            HStack(spacing: 12) {
                                Button {
                                    activeConfigurationID = configuration.id
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: activeConfigurationID == configuration.id ? "checkmark.circle.fill" : "circle")
                                            .font(.title3.weight(.bold))
                                            .foregroundColor(activeConfigurationID == configuration.id ? .accentColor : .secondary)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(configuration.name)
                                                .font(.headline.weight(.bold))
                                                .foregroundColor(.primary)
                                            if configuration.scoresGamesOnly {
                                                Text("Somente pontuar games")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(.secondary)
                                            }
                                            Text("\(configuration.gamesToWinSet) games por set")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text("\(configuration.matchSetsCount) sets • Desempate \(configuration.tieBreakRule.title)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    editingConfigurationID = configuration.id
                                    newConfigurationName = configuration.name
                                    newScoresGamesOnly = configuration.scoresGamesOnly
                                    newGamesToWinSet = configuration.gamesToWinSet
                                    newMatchSetsCount = configuration.matchSetsCount
                                    newTieBreakRule = configuration.tieBreakRule
                                    newCustomTieBreakPoints = configuration.customTieBreakPoints
                                    newIsSuperTieBreakEnabled = configuration.isSuperTieBreakEnabled
                                    isCreateSheetPresented = true
                                } label: {
                                    settingsActionButton(
                                        systemName: "pencil",
                                        foregroundColor: .accentColor
                                    )
                                }
                                .buttonStyle(.plain)

                                if matchConfigurations.count > 1 {
                                    Button(role: .destructive) {
                                        pendingDeletionConfiguration = configuration
                                    } label: {
                                        settingsActionButton(
                                            systemName: "trash",
                                            foregroundColor: .red
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            editingConfigurationID = nil
                            newConfigurationName = ""
                            newScoresGamesOnly = false
                            newGamesToWinSet = 6
                            newMatchSetsCount = 1
                            newTieBreakRule = .standard
                            newCustomTieBreakPoints = 7
                            newIsSuperTieBreakEnabled = false
                            isCreateSheetPresented = true
                        } label: {
                            Label("Nova configuração", systemImage: "plus.circle.fill")
                                .font(.headline.weight(.bold))
                        }
                    }

                    Section("Atletas cadastrados") {
                        if athletes.isEmpty {
                            Text("Nenhum atleta cadastrado ainda.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(athletes, id: \.self) { athlete in
                                HStack {
                                    Text(athlete)
                                    Spacer()
                                    Button(role: .destructive) {
                                        pendingDeletionAthlete = athlete
                                    } label: {
                                        settingsActionButton(
                                            systemName: "trash",
                                            foregroundColor: .red
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Configurações")
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
            .sheet(isPresented: $isCreateSheetPresented) {
                NavigationStack {
                    Form {
                        Section(editingConfigurationID == nil ? "Nova configuração" : "Editar configuração") {
                            TextField("Nome da configuração", text: $newConfigurationName)

                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Somente pontuar Games", isOn: $newScoresGamesOnly)

                                Text("Nesse modo, não será pontuado pontos dentro dos games, mas somente os games e sets.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            stepperRow(
                                title: "Games por Set",
                                value: newGamesToWinSet,
                                canDecrement: newGamesToWinSet > 1,
                                canIncrement: newGamesToWinSet < 9,
                                onDecrement: {
                                    newGamesToWinSet = max(1, newGamesToWinSet - 1)
                                    if newGamesToWinSet < 3 {
                                        newTieBreakRule = .disabled
                                    }
                                },
                                onIncrement: {
                                    newGamesToWinSet = min(9, newGamesToWinSet + 1)
                                }
                            )

                            if !newScoresGamesOnly {
                                tieBreakSection
                            }

                            settingsSubsection(
                                title: "Sets",
                                subtitle: nil
                            ) {
                                stepperRow(
                                    title: "Número de Sets",
                                    value: newMatchSetsCount,
                                    canDecrement: newMatchSetsCount > 1,
                                    canIncrement: newMatchSetsCount < 7,
                                    onDecrement: {
                                        newMatchSetsCount = max(1, newMatchSetsCount - 2)
                                    },
                                    onIncrement: {
                                        newMatchSetsCount = min(7, newMatchSetsCount + 2)
                                    }
                                )

                                Toggle("Super Tie-break", isOn: $newIsSuperTieBreakEnabled)
                                    .disabled(newMatchSetsCount < 3)
                                    .onChange(of: newMatchSetsCount) { _, newValue in
                                        if newValue < 3 {
                                            newIsSuperTieBreakEnabled = false
                                        }
                                    }

                                if newIsSuperTieBreakEnabled {
                                    (
                                        Text("Super Tie-break: ")
                                            .fontWeight(.black) +
                                        Text(superTieBreakDescription)
                                    )
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .navigationTitle(editingConfigurationID == nil ? "Nova configuração" : "Editar configuração")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancelar") {
                                isCreateSheetPresented = false
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Salvar") {
                                if let editingConfigurationID {
                                    onUpdateConfiguration(
                                        editingConfigurationID,
                                        newConfigurationName,
                                        newScoresGamesOnly,
                                        newGamesToWinSet,
                                        newMatchSetsCount,
                                        newTieBreakRule,
                                        newCustomTieBreakPoints,
                                        newIsSuperTieBreakEnabled
                                    )
                                } else {
                                    onCreateConfiguration(
                                        newConfigurationName,
                                        newScoresGamesOnly,
                                        newGamesToWinSet,
                                        newMatchSetsCount,
                                        newTieBreakRule,
                                        newCustomTieBreakPoints,
                                        newIsSuperTieBreakEnabled
                                    )
                                }
                                self.editingConfigurationID = nil
                                isCreateSheetPresented = false
                            }
                        }
                    }
                }
            }
            .alert("Excluir item?", isPresented: isShowingDeleteAlert) {
                Button("Cancelar", role: .cancel) {
                    pendingDeletionConfiguration = nil
                    pendingDeletionAthlete = nil
                }
                Button("Excluir", role: .destructive) {
                    if let configuration = pendingDeletionConfiguration {
                        onDeleteConfiguration(configuration.id)
                    }
                    if let athlete = pendingDeletionAthlete {
                        onDeleteAthlete(athlete)
                    }
                    pendingDeletionConfiguration = nil
                    pendingDeletionAthlete = nil
                }
            } message: {
                Text(deleteConfirmationMessage)
            }
        }
    }

    private var isShowingDeleteAlert: Binding<Bool> {
        Binding(
            get: { pendingDeletionConfiguration != nil || pendingDeletionAthlete != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletionConfiguration = nil
                    pendingDeletionAthlete = nil
                }
            }
        )
    }

    private var deleteConfirmationMessage: String {
        if let pendingDeletionConfiguration {
            return "Deseja excluir a configuração \"\(pendingDeletionConfiguration.name)\"?"
        }
        if let pendingDeletionAthlete {
            return "Deseja excluir o atleta \"\(pendingDeletionAthlete)\"?"
        }
        return ""
    }

    private func settingsActionButton(systemName: String, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(foregroundColor)
            .frame(width: 32, height: 32)
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var tieBreakRuleRadioGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Regra de Desempate (Tie-break)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)

            if isTieBreakAvailable {
                HStack(spacing: 8) {
                    ForEach(
                        [
                            ContentViewTenis.TieBreakRule.standard,
                            ContentViewTenis.TieBreakRule.custom,
                            ContentViewTenis.TieBreakRule.disabled
                        ],
                        id: \.self
                    ) { rule in
                        Button {
                            newTieBreakRule = rule
                            if rule != .custom {
                                newCustomTieBreakPoints = 7
                            }
                        } label: {
                            Text(rule.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(tieBreakOptionForegroundColor(for: rule))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(tieBreakOptionBackgroundColor(for: rule))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !isTieBreakAvailable {
                Text("Disponível apenas quando Games por Set for igual ou maior que 3.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tieBreakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            tieBreakRuleRadioGroup

            if isTieBreakAvailable && newTieBreakRule == .custom {
                stepperRow(
                    title: "Pontos para Desempate",
                    value: newCustomTieBreakPoints,
                    canDecrement: newCustomTieBreakPoints > 3,
                    canIncrement: newCustomTieBreakPoints < 10,
                    onDecrement: {
                        newCustomTieBreakPoints = max(3, newCustomTieBreakPoints - 1)
                    },
                    onIncrement: {
                        newCustomTieBreakPoints = min(10, newCustomTieBreakPoints + 1)
                    }
                )
            }

            if isTieBreakAvailable {
                tieBreakRuleDescriptionView
            }
        }
        .padding(.top, 6)
    }

    private var isTieBreakAvailable: Bool {
        newGamesToWinSet >= 3
    }

    private var tieBreakRuleDescriptionView: some View {
        (
            Text(tieBreakRuleDescriptionTitle)
                .fontWeight(.black) +
            Text(" \(tieBreakRuleDescriptionBody)")
        )
        .font(.footnote)
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var tieBreakRuleDescriptionTitle: String {
        switch newTieBreakRule {
        case .standard:
            return "Padrão:"
        case .disabled:
            return "Desativado:"
        case .custom:
            return "Customizado:"
        }
    }

    private var tieBreakRuleDescriptionBody: String {
        guard isTieBreakAvailable else {
            return "Primeiro a chegar em \(newGamesToWinSet) games vence o set, sem regra de desempate."
        }

        switch newTieBreakRule {
        case .standard:
            return "Vence o primeiro a alcançar 7 pontos com 2 pontos de diferença. Se empate em 6-6, o jogo continua até uma diferença de 2 pontos seja alcançada."
        case .disabled:
            return "Primeiro a chegar em \(newGamesToWinSet) games vence o set, sem regra de desempate."
        case .custom:
            let edgeScore = max(0, newCustomTieBreakPoints - 1)
            return "Vence o primeiro a alcançar \(newCustomTieBreakPoints) pontos com 2 pontos de diferença. Se empate em \(edgeScore)-\(edgeScore), o jogo continua até uma diferença de 2 pontos seja alcançada."
        }
    }

    private var superTieBreakDescription: String {
        let tiedSets = max(1, newMatchSetsCount / 2)
        return "Até 10 pontos (vantagem de 2). Em partidas de \(newMatchSetsCount) sets, é jogado quando o placar está \(tiedSets)-\(tiedSets) em sets."
    }

    private func tieBreakOptionForegroundColor(for rule: ContentViewTenis.TieBreakRule) -> Color {
        if !isTieBreakAvailable {
            return .secondary.opacity(0.55)
        }
        return newTieBreakRule == rule ? .white : .primary
    }

    private func tieBreakOptionBackgroundColor(for rule: ContentViewTenis.TieBreakRule) -> Color {
        if !isTieBreakAvailable {
            return Color(uiColor: .secondarySystemFill)
        }
        return newTieBreakRule == rule ? .accentColor : Color(uiColor: .secondarySystemBackground)
    }

    private func settingsSubsection<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundColor(.accentColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            content()
        }
        .padding(.top, 6)
    }

    private func stepperRow(
        title: String,
        value: Int,
        canDecrement: Bool,
        canIncrement: Bool,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(.primary)

            Spacer()

            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(canDecrement ? .primary : .secondary.opacity(0.45))
                    .frame(width: 34, height: 34)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)

            Text("\(value)")
                .font(.title3.weight(.black))
                .foregroundColor(.primary)
                .frame(minWidth: 28)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(canIncrement ? .primary : .secondary.opacity(0.45))
                    .frame(width: 34, height: 34)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!canIncrement)
        }
    }
}
