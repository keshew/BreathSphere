import SwiftUI
import AVFoundation // Для фоновой музыки
import UserNotifications // Для уведомлений

// Модель для режимов дыхания
enum BreathingMode: String, CaseIterable {
    case sleep = "Sleep"
    case focus = "Focus"
    case relax = "Relax"
    
    var cycle: (inhale: Double, hold: Double, exhale: Double, holdAfterExhale: Double) {
        switch self {
        case .sleep: return (4, 7, 8, 0) // 4-7-8
        case .focus: return (3, 3, 3, 3) // 3-3-3-3
        case .relax: return (5, 0, 5, 0) // 5-5 (без задержек)
        }
    }
    
    var icon: String {
        switch self {
        case .sleep: return "moon.stars"
        case .focus: return "bolt"
        case .relax: return "leaf"
        }
    }
}

// Модель для тем
enum ThemeColor: String, CaseIterable {
    case pink = "Pink"
    case blue = "Blue"
    case green = "Green"
    
    var gradient: [Color] {
        switch self {
        case .pink: return [Color(hex: "#FF4FBF"), Color(hex: "#B84FFF")]
        case .blue: return [Color(hex: "#4FBFFF"), Color(hex: "#4F84FF")]
        case .green: return [Color(hex: "#4FFF84"), Color(hex: "#84FFB8")]
        }
    }
    
    var accent: Color {
        switch self {
        case .pink: return Color(hex: "#4FFFE0")
        case .blue: return Color(hex: "#FFE04F")
        case .green: return Color(hex: "#E04FFF")
        }
    }
}

// Расширение для Color с HEX
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// Модель для статистики
struct Session: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let duration: Int // в минутах
    let mode: BreathingMode.RawValue
}

class StatsManager: ObservableObject {
    @Published var sessions: [Session] = []
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "sessions") {
            if let decoded = try? JSONDecoder().decode([Session].self, from: data) {
                sessions = decoded
            }
        }
    }
    
    func addSession(duration: Int, mode: BreathingMode) {
        let session = Session(date: Date(), duration: duration, mode: mode.rawValue)
        sessions.append(session)
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "sessions")
        }
    }
    
    func weeklyStats() -> (count: Int, totalMinutes: Int) {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let weeklySessions = sessions.filter { $0.date >= weekAgo }
        return (weeklySessions.count, weeklySessions.reduce(0) { $0 + $1.duration })
    }
    
    func sessionsByDay() -> [Date: Int] {
        var dict: [Date: Int] = [:]
        for session in sessions {
            let day = Calendar.current.startOfDay(for: session.date)
            dict[day, default: 0] += session.duration
        }
        return dict
    }
}

// Настройки
class Settings: ObservableObject {
    @Published var theme: ThemeColor = .pink {
        didSet { save() }
    }
    @Published var backgroundMusic: String? = nil { // "waves", "forest", "white_noise"
        didSet { save() }
    }
    @Published var notificationsTime: Date? = nil {
        didSet { save() }
    }
    
    init() {
        let defaults = UserDefaults.standard
        if let themeRaw = defaults.string(forKey: "theme"), let theme = ThemeColor(rawValue: themeRaw) {
            self.theme = theme
        }
        backgroundMusic = defaults.string(forKey: "backgroundMusic")
        if let timeData = defaults.object(forKey: "notificationsTime") as? Date {
            notificationsTime = timeData
        }
    }
    
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(backgroundMusic, forKey: "backgroundMusic")
        defaults.set(notificationsTime, forKey: "notificationsTime")
    }
}

// Фоновые частицы с анимацией движения
struct ParticlesView: View {
    @State private var positions: [CGPoint] = Array(repeating: .zero, count: 50)
    @State private var opacities: [Double] = Array(repeating: 0.0, count: 50)
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<50, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(opacities[index]))
                    .frame(width: CGFloat.random(in: 1...4), height: CGFloat.random(in: 1...4))
                    .position(positions[index])
            }
        }
        .ignoresSafeArea()
        .onAppear {
            let geoSize = UIScreen.main.bounds
            for i in 0..<50 {
                positions[i] = CGPoint(x: CGFloat.random(in: 0...geoSize.width), y: CGFloat.random(in: 0...geoSize.height))
                opacities[i] = Double.random(in: 0.3...0.8)
            }
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                DispatchQueue.main.async {
                    for i in 0..<50 {
                        positions[i].y += CGFloat.random(in: -2...2)
                        positions[i].x += CGFloat.random(in: -2...2)
                        if positions[i].x < 0 || positions[i].x > geoSize.width || positions[i].y < 0 || positions[i].y > geoSize.height {
                            positions[i] = CGPoint(x: CGFloat.random(in: 0...geoSize.width), y: CGFloat.random(in: 0...geoSize.height))
                        }
                        opacities[i] = Double.random(in: 0.3...0.8)
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// Главный шар с улучшенной анимацией и "жидкой" текстурой
struct BreathingSphere: View {
    @Binding var isAnimating: Bool
    @Binding var phase: String
    let theme: ThemeColor
    let cycle: (inhale: Double, hold: Double, exhale: Double, holdAfterExhale: Double)
    
    @State private var scale: CGFloat = 1.0
    @State private var brightness: Double = 0.0
    @State private var opacity: Double = 0.8
    @State private var rotation: Double = 0.0
    @State private var glow: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: theme.gradient + [theme.gradient[0].opacity(0.3)]), center: .center, startRadius: 0, endRadius: 250))
                .blur(radius: 15) // Усиленная жидкая текстура
                .frame(width: 340, height: 340)
                .scaleEffect(scale)
                .brightness(brightness)
                .opacity(opacity)
                .rotationEffect(.degrees(rotation))
                .overlay(
                    Circle()
                        .stroke(theme.accent.opacity(0.4), lineWidth: 3)
                        .blur(radius: 8)
                )
                .shadow(color: theme.accent.opacity(glow), radius: 40, x: 0, y: 0)
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                startBreathingCycle()
            } else {
                stopBreathingCycle()
            }
        }
    }
    
    private func startBreathingCycle() {
        inhale()
    }
    
    private func stopBreathingCycle() {
        withAnimation(.easeInOut) {
            scale = 1.0
            brightness = 0.0
            opacity = 0.8
            rotation = 0.0
            glow = 0.0
        }
        phase = ""
    }
    
    private func inhale() {
        guard isAnimating else { return }
        phase = "Inhale"
        withAnimation(.easeInOut(duration: cycle.inhale)) {
            scale = 1.5
            brightness = 0.25
            rotation += 8
            glow = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + cycle.inhale) {
            hold()
        }
    }
    
    private func hold() {
        guard isAnimating else { return }
        if cycle.hold > 0 {
            phase = "Hold"
            withAnimation(.easeInOut(duration: cycle.hold / 2).repeatForever(autoreverses: true)) {
                scale = 1.48
                glow = 0.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + cycle.hold) {
                exhale()
            }
        } else {
            exhale()
        }
    }
    
    private func exhale() {
        guard isAnimating else { return }
        phase = "Exhale"
        withAnimation(.easeInOut(duration: cycle.exhale)) {
            scale = 1.0
            brightness = -0.15
            rotation -= 8
            glow = 0.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + cycle.exhale) {
            holdAfterExhale()
        }
    }
    
    private func holdAfterExhale() {
        guard isAnimating else { return }
        if cycle.holdAfterExhale > 0 {
            phase = "Hold"
            withAnimation(.easeInOut(duration: cycle.holdAfterExhale / 2).repeatForever(autoreverses: true)) {
                scale = 1.05
                glow = 0.4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + cycle.holdAfterExhale) {
                inhale()
            }
        } else {
            inhale()
        }
    }
}

// Экран Home с улучшениями
struct HomeView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var stats: StatsManager
    @Binding var selectedMode: BreathingMode
    @State private var selectedDuration: Int = 5
    let durations = [1, 3, 5, 10, 20]
    
    @State private var isSessionActive = false
    @State private var remainingTime: Int = 300 // секунды
    @State private var timer: Timer?
    @State private var phase = ""
    @State private var showCompletion = false
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        ZStack {
            background
            VStack(spacing: 25) {
                if stats.sessions.isEmpty {
                    Text("Tap Start to begin your first breathing session")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(20)
                        .background(Color.black.opacity(0.25).blur(radius: 10))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: settings.theme.accent.opacity(0.3), radius: 10)
                } else {
                    Text(phase)
                        .foregroundColor(.white)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .opacity(isSessionActive ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5), value: phase)
                }
                
                BreathingSphere(isAnimating: $isSessionActive, phase: $phase, theme: settings.theme, cycle: selectedMode.cycle)
                    .padding(.bottom, 30)
                
                Text(timeString(from: remainingTime))
                    .foregroundColor(.white)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .padding(12)
                    .background(settings.theme.gradient[0].opacity(0.3))
                    .clipShape(Capsule())
                    .shadow(color: settings.theme.accent.opacity(0.5), radius: 5)
                
                if !isSessionActive {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(durations, id: \.self) { dur in
                                Button(action: {
                                    selectedDuration = dur
                                    remainingTime = dur * 60
                                }) {
                                    Text("\(dur) min")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 25)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(gradient: Gradient(colors: settings.theme.gradient), startPoint: .topLeading, endPoint: .bottomTrailing)
                                                .opacity(selectedDuration == dur ? 1 : 0.6)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 25))
                                        .shadow(color: settings.theme.accent.opacity(0.5), radius: 8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 60)
                }
                
                Button(action: toggleSession) {
                    Text(isSessionActive ? "Pause" : "Start")
                        .foregroundColor(.white)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(25)
                        .background(
                            RadialGradient(gradient: Gradient(colors: [settings.theme.accent, settings.theme.accent.opacity(0.5)]), center: .center, startRadius: 0, endRadius: 60)
                        )
                        .clipShape(Circle())
                        .shadow(color: settings.theme.accent, radius: 15)
                        .scaleEffect(isSessionActive ? 1.15 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isSessionActive)
                }
                
                if showCompletion {
                    Text("Session Complete ✨")
                        .foregroundColor(.white)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .padding(20)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation {
                                    showCompletion = false
                                }
                            }
                        }
                }
            }
            .padding()
        }
        .onDisappear { stopSession() }
    }
    
    private var background: some View {
        LinearGradient(gradient: Gradient(colors: [Color(hex: "#0D0D1A"), Color(hex: "#1A0D2E"), Color(hex: "#2B0D4F")]), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .overlay(ParticlesView().blendMode(.screen).opacity(0.8))
    }
    
    private func toggleSession() {
        isSessionActive.toggle()
        if isSessionActive {
            startTimer()
            playBackgroundMusic()
        } else {
            pauseTimer()
            pauseBackgroundMusic()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                endSession()
            }
        }
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func stopSession() {
        pauseTimer()
        stopBackgroundMusic()
        isSessionActive = false
    }
    
    private func endSession() {
        pauseTimer()
        isSessionActive = false
        withAnimation(.spring()) {
            showCompletion = true
        }
        stats.addSession(duration: selectedDuration, mode: selectedMode)
        stopBackgroundMusic()
    }
    
    private func timeString(from seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        return String(format: "%02d:%02d", min, sec)
    }
    
    private func playBackgroundMusic() {
        guard let music = settings.backgroundMusic, let url = Bundle.main.url(forResource: music, withExtension: "mp3") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
        } catch {
            print("Error playing music: \(error)")
        }
    }
    
    private func pauseBackgroundMusic() {
        audioPlayer?.pause()
    }
    
    private func stopBackgroundMusic() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// Экран Modes с улучшениями
struct ModesView: View {
    @ObservedObject var settings: Settings
    @Binding var selectedMode: BreathingMode
    
    var body: some View {
        ZStack {
            background
            VStack(spacing: 40) {
                Text("Choose Mode")
                    .foregroundColor(.white)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .shadow(color: settings.theme.accent.opacity(0.3), radius: 5)
                
                ForEach(BreathingMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMode = mode
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(RadialGradient(gradient: Gradient(colors: settings.theme.gradient), center: .center, startRadius: 0, endRadius: 120))
                                .frame(width: 180, height: 180)
                                .shadow(color: selectedMode == mode ? settings.theme.accent.opacity(0.9) : .clear, radius: 20)
                                .scaleEffect(selectedMode == mode ? 1.15 : 1.0)
                            
                            Image(systemName: mode.icon)
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 5)
                            
                            Text(mode.rawValue)
                                .foregroundColor(.white)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .offset(y: 90)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedMode)
                }
            }
            .padding()
        }
    }
    
    private var background: some View {
        LinearGradient(gradient: Gradient(colors: [Color(hex: "#0D0D1A"), Color(hex: "#1A0D2E"), Color(hex: "#2B0D4F")]), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .overlay(ParticlesView().blendMode(.screen).opacity(0.8))
    }
}

// Экран Statistics с улучшениями
struct StatisticsView: View {
    @ObservedObject var stats: StatsManager
    @ObservedObject var settings: Settings
    
    var body: some View {
        ZStack {
            background
            if stats.sessions.isEmpty {
                Text("Your progress will appear here after your first session")
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .background(Color.black.opacity(0.25).blur(radius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: settings.theme.accent.opacity(0.3), radius: 10)
            } else {
                ScrollView {
                    VStack(spacing: 40) {
                        Text("Your Practice")
                            .foregroundColor(.white)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .shadow(color: settings.theme.accent.opacity(0.3), radius: 5)
                        
                        CalendarBubbleView(sessionsByDay: stats.sessionsByDay(), theme: settings.theme)
                            .padding()
                        
                        let weekly = stats.weeklyStats()
                        HStack(spacing: 20) {
                            StatCard(title: "Sessions", value: "\(weekly.count)", icon: "play.circle.fill", theme: settings.theme)
                            StatCard(title: "Minutes", value: "\(weekly.totalMinutes)", icon: "clock.fill", theme: settings.theme)
                        }
                        
                        BubbleChartView(totalTime: weekly.totalMinutes, theme: settings.theme)
                            .frame(height: 300)
                    }
                    .padding()
                }
            }
        }
    }
    
    private var background: some View {
        LinearGradient(gradient: Gradient(colors: [Color(hex: "#0D0D1A"), Color(hex: "#1A0D2E"), Color(hex: "#2B0D4F")]), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .overlay(ParticlesView().blendMode(.screen).opacity(0.8))
    }
}

// Карточка статистики
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let theme: ThemeColor
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(theme.accent)
            Text(value)
                .foregroundColor(.white)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(title)
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 16, design: .rounded))
        }
        .frame(width: 160, height: 140)
        .background(Color.black.opacity(0.35).blur(radius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: theme.accent.opacity(0.4), radius: 15)
    }
}

// Календарь с пузырями, исправленный
struct CalendarBubbleView: View {
    let sessionsByDay: [Date: Int]
    let theme: ThemeColor
    
    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)!.count
        let weekdayOfFirst = calendar.component(.weekday, from: startOfMonth) - 1
        let totalCells = weekdayOfFirst + daysInMonth
        let trailing = (7 - (totalCells % 7)) % 7
        
        VStack(spacing: 15) {
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 7), spacing: 15) {
                ForEach(0..<weekdayOfFirst, id: \.self) { _ in
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 45, height: 45)
                }
                
                ForEach(1...daysInMonth, id: \.self) { dayNum in
                    let day = calendar.date(byAdding: .day, value: dayNum - 1, to: startOfMonth)!
                    let startDay = calendar.startOfDay(for: day) // Убедимся, что ключ правильный
                    let duration = sessionsByDay[startDay] ?? 0
                    let size: CGFloat = duration > 0 ? CGFloat(min(Double(duration) * 1.5, 45)) : 25
                    let color: Color = duration > 0 ? theme.gradient[0] : .gray.opacity(0.4)
                    
                    Circle()
                        .fill(color)
                        .frame(width: size, height: size)
                        .shadow(color: color.opacity(0.6), radius: 8)
                        .overlay {
                            if duration == 0 {
                                Text("\(dayNum)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .scaleEffect(duration > 0 ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: duration)
                }
                
                ForEach(0..<trailing, id: \.self) { _ in
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 45, height: 45)
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.25).blur(radius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: theme.accent.opacity(0.3), radius: 15)
    }
}

// Bubble chart с анимацией
struct BubbleChartView: View {
    let totalTime: Int
    let theme: ThemeColor
    @State private var bubbles: [(size: CGFloat, position: CGPoint, color: Color, offset: CGFloat)] = []
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<bubbles.count, id: \.self) { index in
                Circle()
                    .fill(bubbles[index].color.opacity(0.85))
                    .frame(width: bubbles[index].size, height: bubbles[index].size)
                    .position(bubbles[index].position)
                    .offset(y: sin(Date().timeIntervalSince1970 * 2 + Double(index)) * bubbles[index].offset)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: UUID())
            }
        }
        .onAppear {
            generateBubbles(geometrySize: CGSize(width: 350, height: 300))
        }
    }
    
    private func generateBubbles(geometrySize: CGSize) {
        bubbles = []
        let count = min(totalTime / 5, 40)
        for i in 0..<count {
            let size = CGFloat.random(in: 20...60)
            let position = CGPoint(x: CGFloat.random(in: 0...geometrySize.width), y: CGFloat.random(in: 0...geometrySize.height))
            let color = theme.gradient.randomElement()!
            let offset = CGFloat.random(in: 5...15)
            bubbles.append((size, position, color, offset))
        }
    }
}

// Экран Profile & Settings с улучшениями
struct ProfileView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var stats: StatsManager
    
    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 40) {
                    // Аватар
                    ZStack {
                        Circle()
                            .fill(RadialGradient(gradient: Gradient(colors: settings.theme.gradient), center: .center, startRadius: 0, endRadius: 120))
                            .frame(width: 140, height: 140)
                            .shadow(color: settings.theme.accent.opacity(0.6), radius: 25)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    
                    Text("Customize Your Practice")
                        .foregroundColor(.white)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .shadow(color: settings.theme.accent.opacity(0.3), radius: 5)
                    
                    // Выбор темы
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Theme")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 18, design: .rounded))
                        Picker("Theme", selection: $settings.theme) {
                            ForEach(ThemeColor.allCases, id: \.self) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .colorMultiply(settings.theme.accent)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.25).blur(radius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: settings.theme.accent.opacity(0.3), radius: 10)
                    
                    // Фоновая музыка
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Background Music")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 18, design: .rounded))
                        Picker("Music", selection: $settings.backgroundMusic) {
                            Text("None").tag(String?.none)
                            Text("Waves").tag(String?.some("waves"))
                            Text("Forest").tag(String?.some("forest"))
                            Text("White Noise").tag(String?.some("white_noise"))
                        }
                        .pickerStyle(.segmented)
                        .colorMultiply(settings.theme.accent)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.25).blur(radius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: settings.theme.accent.opacity(0.3), radius: 10)
                    
                    // Уведомления
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Remind to Breathe")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 18, design: .rounded))
                        if let binding = Binding($settings.notificationsTime) {
                            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                        } else {
                            Button("Set Time") {
                                settings.notificationsTime = Date()
                            }
                            .foregroundColor(settings.theme.accent)
                            .font(.system(size: 18, weight: .bold))
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.25).blur(radius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: settings.theme.accent.opacity(0.3), radius: 10)
                    
                    // Export Stats
                    Button("Export Stats to PDF") {
                        exportStatsToPDF()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(gradient: Gradient(colors: settings.theme.gradient), startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: settings.theme.accent.opacity(0.5), radius: 15)
                }
                .padding()
            }
        }
    }
    
    private var background: some View {
        LinearGradient(gradient: Gradient(colors: [Color(hex: "#0D0D1A"), Color(hex: "#1A0D2E"), Color(hex: "#2B0D4F")]), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .overlay(ParticlesView().blendMode(.screen).opacity(0.8))
    }
    
    private func exportStatsToPDF() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            let title = "BreathSphere Stats"
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 24), .foregroundColor: UIColor.white]
            title.draw(at: CGPoint(x: 40, y: 40), withAttributes: attributes)
            
            var y: CGFloat = 80
            for session in stats.sessions {
                let text = "\(session.date.formatted(date: .long, time: .shortened)): \(session.duration) min - \(session.mode)"
                text.draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.white])
                y += 25
            }
        }
        // В реальности используйте UIActivityViewController для sharing data
        print("PDF data generated: \(data.count) bytes")
    }
}

// Главный App
@main
struct BreathSphereApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
}

struct ContentView: View {
    
    @StateObject var settings = Settings()
    @StateObject var stats = StatsManager()
    @State private var selectedMode: BreathingMode = .relax
    
    var body: some View {
        VStack {
            TabView {
                HomeView(settings: settings, stats: stats, selectedMode: $selectedMode)
                    .tabItem { Label("Breathe", systemImage: "wind") }
                
                ModesView(settings: settings, selectedMode: $selectedMode)
                    .tabItem { Label("Modes", systemImage: "slider.horizontal.3") }
                
                StatisticsView(stats: stats, settings: settings)
                    .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                
                ProfileView(settings: settings, stats: stats)
                    .tabItem { Label("Profile", systemImage: "person.circle") }
            }
            .accentColor(settings.theme.accent)
            .onAppear {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
            .onChange(of: settings.notificationsTime) { newValue in
                scheduleNotification(at: newValue)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func scheduleNotification(at time: Date?) {
        guard let time = time else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to Breathe"
        content.body = "Take a moment for your breathing practice."
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(identifier: "breatheReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
}

#Preview {
    ContentView()
}
