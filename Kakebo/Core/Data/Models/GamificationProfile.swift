//
//  GamificationProfile.swift
//  KakeboApp
//
//  Sistema completo de gamificación para incentivar buenos hábitos financieros
//  Incluye puntos, rangos, logros (achievements) y rachas tipo Steam
//

import Foundation
import SwiftData

/// Rangos del sistema de gamificación
enum UserRank: String, Codable, CaseIterable {
    case novice = "Novato"
    case apprentice = "Aprendiz"
    case practitioner = "Practicante"
    case expert = "Experto"
    case master = "Maestro"
    case grandMaster = "Gran Maestro"
    case legend = "Leyenda"
    
    /// Puntos mínimos requeridos para alcanzar el rango
    var minimumPoints: Int {
        switch self {
        case .novice: return 0
        case .apprentice: return 100
        case .practitioner: return 500
        case .expert: return 1500
        case .master: return 3500
        case .grandMaster: return 7500
        case .legend: return 15000
        }
    }
    
    /// Puntos requeridos para el siguiente rango
    var nextRankPoints: Int? {
        guard let currentIndex = UserRank.allCases.firstIndex(of: self),
              currentIndex < UserRank.allCases.count - 1 else {
            return nil // Ya es el máximo rango
        }
        return UserRank.allCases[currentIndex + 1].minimumPoints
    }
    
    /// Color del rango
    var color: String {
        switch self {
        case .novice: return "#9CA3AF"      // Gris
        case .apprentice: return "#10B981"  // Verde
        case .practitioner: return "#3B82F6" // Azul
        case .expert: return "#8B5CF6"      // Morado
        case .master: return "#F59E0B"      // Oro
        case .grandMaster: return "#EF4444" // Rojo
        case .legend: return "#EC4899"      // Rosa brillante
        }
    }
    
    /// Icono del rango
    var icon: String {
        switch self {
        case .novice: return "star"
        case .apprentice: return "star.fill"
        case .practitioner: return "star.leadinghalf.filled"
        case .expert: return "medal"
        case .master: return "medal.fill"
        case .grandMaster: return "crown"
        case .legend: return "crown.fill"
        }
    }
}

/// Tipo de logro (achievement)
enum AchievementType: String, Codable {
    // Logros de ahorro
    case firstSaving = "first_saving"
    case savingStreak = "saving_streak"
    case bigSaver = "big_saver"
    case goalCompleted = "goal_completed"
    case multipleGoals = "multiple_goals"
    
    // Logros de gestión
    case firstTransaction = "first_transaction"
    case dailyStreak = "daily_streak"
    case weeklyStreak = "weekly_streak"
    case monthlyComplete = "monthly_complete"
    case budgetMaster = "budget_master"
    
    // Logros de control
    case expenseControl = "expense_control"
    case noBudgetExceed = "no_budget_exceed"
    case positiveBalance = "positive_balance"
    case savingRate = "saving_rate"
    
    // Logros especiales
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    case perfectWeek = "perfect_week"
    case categoryMaster = "category_master"
}

/// Rareza del achievement (estilo Steam)
enum AchievementRarity: String, Codable {
    case common = "Común"
    case uncommon = "Poco Común"
    case rare = "Raro"
    case epic = "Épico"
    case legendary = "Legendario"
    
    var color: String {
        switch self {
        case .common: return "#9CA3AF"
        case .uncommon: return "#10B981"
        case .rare: return "#3B82F6"
        case .epic: return "#8B5CF6"
        case .legendary: return "#F59E0B"
        }
    }
    
    var pointsMultiplier: Int {
        switch self {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 3
        case .epic: return 5
        case .legendary: return 10
        }
    }
}

/// Modelo de Perfil de Gamificación
/// Gestiona todo el sistema de puntos, rangos y logros del usuario
@Model
final class GamificationProfile {
    
    // MARK: - Properties
    
    var id: UUID
    var userId: UUID  // Link con usuario si hay sistema de auth
    var totalPoints: Int
    var currentRank: UserRank
    var createdAt: Date
    var lastActivityDate: Date
    
    /// Racha actual de días consecutivos registrando movimientos
    var currentStreak: Int
    
    /// Racha más larga alcanzada
    var longestStreak: Int
    
    /// Total de metas completadas
    var completedGoalsCount: Int
    
    /// Total de transacciones registradas
    var totalTransactionsCount: Int
    
    /// Mejor tasa de ahorro alcanzada
    var bestSavingRate: Double
    
    /// Total ahorrado histórico
    var totalSavingsAmount: Decimal
    
    /// Fecha de la última racha registrada
    var lastStreakDate: Date?
    
    // MARK: - Relationships
    
    /// Logros desbloqueados
    @Relationship(deleteRule: .cascade, inverse: \Achievement.profile)
    var unlockedAchievements: [Achievement]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        totalPoints: Int = 0,
        currentRank: UserRank = .novice,
        currentStreak: Int = 0,
        longestStreak: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.totalPoints = totalPoints
        self.currentRank = currentRank
        self.createdAt = Date()
        self.lastActivityDate = Date()
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.completedGoalsCount = 0
        self.totalTransactionsCount = 0
        self.bestSavingRate = 0
        self.totalSavingsAmount = 0
        self.unlockedAchievements = []
    }
}

// MARK: - Computed Properties

extension GamificationProfile {
    
    /// Puntos necesarios para el siguiente rango
    var pointsToNextRank: Int? {
        guard let nextRankPoints = currentRank.nextRankPoints else { return nil }
        return nextRankPoints - totalPoints
    }
    
    /// Porcentaje de progreso hacia el siguiente rango
    var rankProgressPercentage: Double {
        guard let nextRankPoints = currentRank.nextRankPoints else { return 100 }
        let currentRankPoints = currentRank.minimumPoints
        let progress = Double(totalPoints - currentRankPoints) / Double(nextRankPoints - currentRankPoints)
        return min(max(progress * 100, 0), 100)
    }
    
    /// Cantidad de logros desbloqueados
    var achievementCount: Int {
        unlockedAchievements.count
    }
    
    /// Porcentaje de logros desbloqueados del total disponible
    var achievementCompletionRate: Double {
        let totalAchievements = Achievement.allPossibleAchievements().count
        guard totalAchievements > 0 else { return 0 }
        return (Double(achievementCount) / Double(totalAchievements)) * 100
    }
    
    /// Indica si la racha está activa (última actividad fue ayer o hoy)
    var isStreakActive: Bool {
        guard let lastDate = lastStreakDate else { return false }
        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return daysDiff <= 1
    }
    
    /// Logros recientes (últimos 7 días)
    var recentAchievements: [Achievement] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return unlockedAchievements.filter { $0.unlockedAt >= sevenDaysAgo }
    }
}

// MARK: - Business Logic

extension GamificationProfile {
    
    /// Agrega puntos al perfil y verifica si sube de rango
    /// - Parameter points: Cantidad de puntos a agregar
    /// - Returns: Tupla indicando si subió de rango y el nuevo rango
    @discardableResult
    func addPoints(_ points: Int) -> (rankedUp: Bool, newRank: UserRank?) {
        totalPoints += points
        lastActivityDate = Date()
        
        // Verificar si sube de rango
        let previousRank = currentRank
        updateRank()
        
        if currentRank != previousRank {
            return (true, currentRank)
        }
        
        return (false, nil)
    }
    
    /// Actualiza el rango según los puntos totales
    private func updateRank() {
        for rank in UserRank.allCases.reversed() {
            if totalPoints >= rank.minimumPoints {
                currentRank = rank
                break
            }
        }
    }
    
    /// Incrementa la racha de días consecutivos
    /// - Returns: Puntos ganados por mantener/incrementar la racha
    @discardableResult
    func incrementStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Si no hay fecha previa o fue hoy mismo, no incrementar
        if let lastDate = lastStreakDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            
            if lastDay == today {
                return 0 // Ya registró hoy
            }
            
            // Verificar si fue ayer
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysDiff == 1 {
                // Racha continua
                currentStreak += 1
                
                if currentStreak > longestStreak {
                    longestStreak = currentStreak
                }
            } else if daysDiff > 1 {
                // Racha rota
                currentStreak = 1
            }
        } else {
            // Primera racha
            currentStreak = 1
        }
        
        lastStreakDate = today
        lastActivityDate = Date()
        
        // Calcular puntos por racha
        let points = calculateStreakPoints()
        addPoints(points)
        
        // Check logros de rachas
        checkStreakAchievements()
        
        return points
    }
    
    /// Calcula puntos por racha actual
    private func calculateStreakPoints() -> Int {
        switch currentStreak {
        case 1...6:
            return currentStreak * 2      // 2 puntos por día
        case 7...13:
            return currentStreak * 5      // 5 puntos por día
        case 14...29:
            return currentStreak * 10     // 10 puntos por día
        case 30...:
            return currentStreak * 20     // 20 puntos por día (racha épica)
        default:
            return 0
        }
    }
    
    /// Registra una transacción y actualiza contadores
    func recordTransaction() {
        totalTransactionsCount += 1
        lastActivityDate = Date()
        
        // Incrementar racha automáticamente al registrar transacción
        incrementStreak()
        
        // Check logros relacionados
        checkTransactionAchievements()
    }
    
    /// Registra una meta completada
    func recordGoalCompleted(points: Int) {
        completedGoalsCount += 1
        addPoints(points)
        checkGoalAchievements()
    }
    
    /// Actualiza la mejor tasa de ahorro
    func updateBestSavingRate(_ rate: Double) {
        if rate > bestSavingRate {
            bestSavingRate = rate
            checkSavingRateAchievements()
        }
    }
    
    /// Desbloquea un logro
    func unlockAchievement(_ achievement: Achievement) {
        guard !unlockedAchievements.contains(where: { $0.type == achievement.type }) else {
            return // Ya desbloqueado
        }
        
        achievement.unlock()
        unlockedAchievements.append(achievement)
        addPoints(achievement.points)
    }
    
    /// Verifica logros relacionados con rachas
    private func checkStreakAchievements() {
        if currentStreak == 7 {
            let achievement = Achievement.createStreakAchievement(days: 7)
            unlockAchievement(achievement)
        } else if currentStreak == 30 {
            let achievement = Achievement.createStreakAchievement(days: 30)
            unlockAchievement(achievement)
        } else if currentStreak == 100 {
            let achievement = Achievement.createStreakAchievement(days: 100)
            unlockAchievement(achievement)
        }
    }
    
    /// Verifica logros relacionados con transacciones
    private func checkTransactionAchievements() {
        if totalTransactionsCount == 1 {
            let achievement = Achievement.firstTransactionAchievement()
            unlockAchievement(achievement)
        } else if totalTransactionsCount == 100 {
            let achievement = Achievement.create(
                type: .dailyStreak,
                name: "Gestor Compulsivo",
                description: "Registra 100 transacciones",
                rarity: .rare,
                points: 100
            )
            unlockAchievement(achievement)
        }
    }
    
    /// Verifica logros relacionados con metas
    private func checkGoalAchievements() {
        if completedGoalsCount == 1 {
            let achievement = Achievement.firstGoalAchievement()
            unlockAchievement(achievement)
        } else if completedGoalsCount == 5 {
            let achievement = Achievement.create(
                type: .multipleGoals,
                name: "Planificador Experto",
                description: "Completa 5 metas de ahorro",
                rarity: .epic,
                points: 200
            )
            unlockAchievement(achievement)
        }
    }
    
    /// Verifica logros relacionados con tasa de ahorro
    private func checkSavingRateAchievements() {
        if bestSavingRate >= 20 {
            let achievement = Achievement.create(
                type: .savingRate,
                name: "Ahorrador Compulsivo",
                description: "Alcanza una tasa de ahorro del 20%",
                rarity: .rare,
                points: 150
            )
            unlockAchievement(achievement)
        } else if bestSavingRate >= 50 {
            let achievement = Achievement.create(
                type: .savingRate,
                name: "Maestro del Ahorro",
                description: "Alcanza una tasa de ahorro del 50%",
                rarity: .legendary,
                points: 500
            )
            unlockAchievement(achievement)
        }
    }
}

// MARK: - Achievement Model

/// Modelo de Logro (Achievement)
/// Representa un hito alcanzado en el sistema
@Model
final class Achievement {
    
    var id: UUID
    var type: AchievementType
    var name: String
    var achievementDescription: String
    var rarity: AchievementRarity
    var points: Int
    var iconName: String
    var isUnlocked: Bool
    var unlockedAt: Date?
    var createdAt: Date
    
    // MARK: - Relationships
    
    var profile: GamificationProfile?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        type: AchievementType,
        name: String,
        description: String,
        rarity: AchievementRarity,
        points: Int,
        iconName: String = "trophy.fill",
        isUnlocked: Bool = false
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.achievementDescription = description
        self.rarity = rarity
        self.points = points * rarity.pointsMultiplier
        self.iconName = iconName
        self.isUnlocked = isUnlocked
        self.createdAt = Date()
    }
}

// MARK: - Achievement Methods

extension Achievement {
    
    func unlock() {
        isUnlocked = true
        unlockedAt = Date()
    }
    
    /// Crea todos los logros posibles del sistema
    static func allPossibleAchievements() -> [Achievement] {
        return [
            // Logros básicos
            firstTransactionAchievement(),
            firstSavingAchievement(),
            firstGoalAchievement(),
            
            // Logros de rachas
            createStreakAchievement(days: 7),
            createStreakAchievement(days: 30),
            createStreakAchievement(days: 100),
            
            // Logros de ahorro
            create(type: .bigSaver, name: "Gran Ahorrador", description: "Ahorra más de $1,000", rarity: .rare, points: 100),
            create(type: .savingRate, name: "Ahorrador Compulsivo", description: "Alcanza 20% de tasa de ahorro", rarity: .rare, points: 150),
            create(type: .savingRate, name: "Maestro del Ahorro", description: "Alcanza 50% de tasa de ahorro", rarity: .legendary, points: 500),
            
            // Logros de gestión
            create(type: .dailyStreak, name: "Gestor Compulsivo", description: "Registra 100 transacciones", rarity: .rare, points: 100),
            create(type: .perfectWeek, name: "Semana Perfecta", description: "Registra todos los días de una semana", rarity: .uncommon, points: 50),
            create(type: .monthlyComplete, name: "Mes Completo", description: "Completa un mes sin exceder presupuesto", rarity: .epic, points: 200),
            
            // Logros especiales
            create(type: .earlyBird, name: "Madrugador", description: "Registra una transacción antes de las 6 AM", rarity: .uncommon, points: 30),
            create(type: .nightOwl, name: "Noctámbulo", description: "Registra una transacción después de las 11 PM", rarity: .uncommon, points: 30)
        ]
    }
    
    static func firstTransactionAchievement() -> Achievement {
        return Achievement(
            type: .firstTransaction,
            name: "Primer Paso",
            description: "Registra tu primera transacción",
            rarity: .common,
            points: 10,
            iconName: "star.fill"
        )
    }
    
    static func firstSavingAchievement() -> Achievement {
        return Achievement(
            type: .firstSaving,
            name: "Primer Ahorro",
            description: "Realiza tu primer ahorro",
            rarity: .common,
            points: 15,
            iconName: "banknote.fill"
        )
    }
    
    static func firstGoalAchievement() -> Achievement {
        return Achievement(
            type: .goalCompleted,
            name: "Meta Alcanzada",
            description: "Completa tu primera meta de ahorro",
            rarity: .uncommon,
            points: 50,
            iconName: "target"
        )
    }
    
    static func createStreakAchievement(days: Int) -> Achievement {
        let (name, rarity, icon) = achievementDetailsForStreak(days)
        return Achievement(
            type: .dailyStreak,
            name: name,
            description: "Registra movimientos durante \(days) días consecutivos",
            rarity: rarity,
            points: days * 2,
            iconName: icon
        )
    }
    
    private static func achievementDetailsForStreak(_ days: Int) -> (String, AchievementRarity, String) {
        switch days {
        case 7:
            return ("Racha de 7 días", .uncommon, "flame.fill")
        case 30:
            return ("Racha de 30 días", .rare, "flame.fill")
        case 100:
            return ("Racha Legendaria", .legendary, "flame.circle.fill")
        default:
            return ("Racha de \(days) días", .common, "flame")
        }
    }
    
    static func create(
        type: AchievementType,
        name: String,
        description: String,
        rarity: AchievementRarity,
        points: Int,
        iconName: String = "trophy.fill"
    ) -> Achievement {
        return Achievement(
            type: type,
            name: name,
            description: description,
            rarity: rarity,
            points: points,
            iconName: iconName
        )
    }
}

// MARK: - Identifiable & Hashable

extension GamificationProfile: Identifiable { }
extension Achievement: Identifiable { }

extension GamificationProfile: Hashable {
    static func == (lhs: GamificationProfile, rhs: GamificationProfile) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Achievement: Hashable {
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
