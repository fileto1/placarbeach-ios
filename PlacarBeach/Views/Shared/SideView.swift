import SwiftUI

struct SideView: View {
    let score: String
    let teamLabel: String
    let backgroundColor: Color
    let showsTennisBall: Bool
    let tennisBallAlignment: Alignment
    let shouldFlash: Bool
    let showCelebration: Bool
    let celebrationTitle: String
    let isSetCelebration: Bool
    let isWinner: Bool
    let isInteractionEnabled: Bool
    let action: () -> Void

    @State private var scorePulse = false
    @State private var celebrationPulse = false
    @State private var celebrationPulseTask: Task<Void, Never>?
    @State private var tennisBallPulse = false
    @State private var tennisBallTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                Color.green
                    .opacity(shouldFlash ? 0.8 : 0)
                if showCelebration {
                    Color.green.opacity(isWinner ? (celebrationPulse ? 0.48 : 0.14) : 0)
                }

                VStack(spacing: 8) {
                    Text(teamLabel)
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.12, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, 12)

                    if showCelebration && isWinner {
                        Text(celebrationTitle)
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * (isSetCelebration ? 0.125 : 0.11), weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .scaleEffect(celebrationPulse ? (isSetCelebration ? 1.14 : 1.06) : (isSetCelebration ? 0.9 : 0.96))
                            .opacity(celebrationPulse ? 1 : 0.88)
                    }

                    Text(score)
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.56, weight: .black))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .scaleEffect(showCelebration && isWinner ? (celebrationPulse ? (isSetCelebration ? 1.22 : 1.08) : (isSetCelebration ? 0.82 : 0.94)) : (scorePulse ? 1.13 : 1))
                        .opacity(scorePulse ? 0.86 : 1)
                }
            }
            .overlay(alignment: tennisBallAlignment) {
                if showsTennisBall {
                    tennisBallIndicator(size: min(geometry.size.width, geometry.size.height) * 0.28)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: tennisBallAlignment)
                        .offset(x: tennisBallAlignment == .leading ? -26 : 26)
                        .scaleEffect(tennisBallPulse ? 1.06 : 0.92)
                        .offset(y: tennisBallPulse ? -10 : 10)
                        .opacity(tennisBallPulse ? 1 : 0.9)
                        .transition(.asymmetric(
                            insertion: .move(edge: tennisBallAlignment == .leading ? .leading : .trailing).combined(with: .opacity),
                            removal: .move(edge: tennisBallAlignment == .leading ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(showCelebration && isWinner ? (celebrationPulse ? (isSetCelebration ? 1.04 : 1.02) : 0.985) : 1)
            .shadow(
                color: showCelebration && isWinner ? .green.opacity(celebrationPulse ? (isSetCelebration ? 0.7 : 0.55) : 0.25) : .clear,
                radius: showCelebration && isWinner ? (celebrationPulse ? (isSetCelebration ? 28 : 20) : 8) : 0
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
            .onChange(of: showsTennisBall) { _, newValue in
                updateTennisBallLoop(isShowing: newValue)
            }
            .onAppear {
                updateCelebrationPulseLoop(isCelebrating: showCelebration, isWinner: isWinner)
                updateTennisBallLoop(isShowing: showsTennisBall)
            }
            .onDisappear {
                celebrationPulseTask?.cancel()
                celebrationPulseTask = nil
                tennisBallTask?.cancel()
                tennisBallTask = nil
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

    private func updateTennisBallLoop(isShowing: Bool) {
        tennisBallTask?.cancel()
        tennisBallTask = nil

        guard isShowing else {
            tennisBallPulse = false
            return
        }

        tennisBallPulse = false
        tennisBallTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.9)) {
                        tennisBallPulse.toggle()
                    }
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }

    private func tennisBallIndicator(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.12))
                .blur(radius: size * 0.06)
                .offset(y: size * 0.08)

            Image(systemName: "tennisball.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.52),
                            Color(red: 0.95, green: 0.9, blue: 0.12),
                            Color(red: 0.8, green: 0.74, blue: 0.02)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.3),
                        startRadius: size * 0.02,
                        endRadius: size * 0.6
                    )
                )
                .overlay {
                    Image(systemName: "tennisball.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.18))
                        .blur(radius: size * 0.03)
                        .mask(
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tennisBallPulse ? 10 : -10))
    }
}
