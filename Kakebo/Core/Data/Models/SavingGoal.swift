//
//  SavingGoal.swift
//  KakeboApp
//
//  Modelo para metas de ahorro con sub-metas y sistema de recompensas
//  Permite definir objetivos financieros a corto, mediano y largo plazo
//

import Foundation
import SwiftData

/// Estado de una meta de ahorro
enum GoalStatus: String, Codable {
    case active = "Activa"
    case completed = "Completada"
    case failed = "No Cumplida"
    case paused = "Pausada"
    case cancelled = "Cancelada"
    
    var color: String {
        switch self {
        case .active: return "#3B82F6"      // Azul
        case .completed: return "#10B981"   // Verde
        case .failed: return "#EF4444"      // Rojo
        case .paused: return "#F59E0B"      // Naranja
        case .cancelled: return "#6B7280"   // Gris
        }
    }
    
    var icon: String {
        switch self {
        case .active: return "target"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .cancelled: return "slash.circle.fill"
        }
    }
}

/// Prioridad de la meta
enum GoalPriority: String, Codable, CaseIterable {
    case low = "Baja"
    case medium = "Media"
    case high = "Alta"
    case critical = "Crítica"
    
    var color: String {
        switch self {
        case .low: return "#6B7280"
        case .medium: return "#3B82F6"
        case .high: return "#F59E0B"
        case .critical: return "#EF4444"
        }
    }
}

/// Modelo de Meta de Ahorro
/// Permite definir objetivos con plazo y recompensas por cumplimiento
@Model
final class SavingGoal {
    
    // MARK: - Properties
    
    var id: UUID
    var name: String
    var goalDescription: String?
    var targetAmount: Decimal
    var currentAmount: Decimal
    var startDate: Date
    var targetDate: Date
    var status: GoalStatus
    var priority: GoalPriority
    var iconName: String
    var colorHex: String
    var createdAt: Date
    
    /// Fecha de completado (si aplica)
    var completedAt: Date?
    
    /// Notas adicionales sobre la meta
    var notes: String?
    
    /// Indica si es una meta recurrente (ej: ahorrar $100 cada mes)
    var isRecurring: Bool
    
    /// Periodo de recurrencia si aplica
    var recurrencePeriod: RecurrencePeriod?
    
    /// Categoría asociada (opcional, para vincular con gastos específicos)
    var linkedCategory: Category?
    
    /// Puntos otorgados al completar la meta
    var rewardPoints: Int
    
    // MARK: - Relationships
    
    /// Sub-metas asociadas (hitos intermedios)
    @Relationship(deleteRule: .cascade, inverse: \SubGoal.parentGoal)
    var subGoals: [SubGoal]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        startDate: Date = Date(),
        targetDate: Date,
        status: GoalStatus = .active,
        priority: GoalPriority = .medium,
        iconName: String = "target",
        colorHex: String = "#3B82F6",
        notes: String? = nil,
        isRecurring: Bool = false,
        recurrencePeriod: RecurrencePeriod? = nil,
        rewardPoints: Int = 100
    ) {
        self.id = id
        self.name = name
        self.goalDescription = description
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.startDate = startDate
        self.targetDate = targetDate
        self.status = status
        self.priority = priority
        self.iconName = iconName
        self.colorHex = colorHex
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurrencePeriod = recurrencePeriod
        self.rewardPoints = rewardPoints
        self.createdAt = Date()
        self.subGoals = []
    }
}

// MARK: - Computed Properties

extension SavingGoal {
    
    /// Monto restante para completar la meta
    var remainingAmount: Decimal {
        max(0, targetAmount - currentAmount)
    }
    
    /// Porcentaje de progreso
    var progressPercentage: Double {
        guard targetAmount > 0 else { return 0 }
        let progress = NSDecimalNumber(decimal: currentAmount).doubleValue /
                      NSDecimalNumber(decimal: targetAmount).doubleValue
        return min(progress * 100, 100)
    }
    
    /// Indica si la meta fue completada
    var isCompleted: Bool {
        status == .completed || currentAmount >= targetAmount
    }
    
    /// Días transcurridos desde el inicio
    var daysElapsed: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
    }
    
    /// Días restantes hasta la fecha objetivo
    var daysRemaining: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
        return max(0, days)
    }
    
    /// Duración total en días
    var totalDuration: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: startDate, to: targetDate).day ?? 0
    }
    
    /// Porcentaje de tiempo transcurrido
    var timeElapsedPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (Double(daysElapsed) / Double(totalDuration)) * 100
    }
    
    /// Indica si la meta está en riesgo (tiempo transcurrido > progreso)
    var isAtRisk: Bool {
        guard status == .active else { return false }
        return timeElapsedPercentage > progressPercentage + 10 // Margen del 10%
    }
    
    /// Indica si la meta está vencida sin completar
    var isOverdue: Bool {
        Date() > targetDate && !isCompleted
    }
    
    /// Monto promedio que se debe ahorrar por día para cumplir la meta
    var requiredDailyAmount: Decimal {
        guard daysRemaining > 0 else { return 0 }
        return remainingAmount / Decimal(daysRemaining)
    }
    
    /// Monto promedio que se debe ahorrar por semana
    var requiredWeeklyAmount: Decimal {
        requiredDailyAmount * 7
    }
    
    /// Monto promedio que se debe ahorrar por mes
    var requiredMonthlyAmount: Decimal {
        requiredDailyAmount * 30
    }
    
    /// Ritmo actual de ahorro (monto/día)
    var currentSavingRate: Decimal {
        guard daysElapsed > 0 else { return 0 }
        return currentAmount / Decimal(daysElapsed)
    }
    
    /// Proyección de monto final si se mantiene el ritmo actual
    var projectedAmount: Decimal {
        guard totalDuration > 0 else { return currentAmount }
        return currentSavingRate * Decimal(totalDuration)
    }
    
    /// Indica si el ritmo actual es suficiente para completar la meta
    var isOnTrack: Bool {
        projectedAmount >= targetAmount
    }
}

// MARK: - Business Logic

extension SavingGoal {
    
    /// Valida que la meta tenga datos correctos
    func validate() -> (isValid: Bool, errorMessage: String?) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "El nombre de la meta no puede estar vacío")
        }
        
        guard targetAmount > 0 else {
            return (false, "El monto objetivo debe ser mayor a cero")
        }
        
        guard currentAmount >= 0 else {
            return (false, "El monto actual no puede ser negativo")
        }
        
        guard targetDate > startDate else {
            return (false, "La fecha objetivo debe ser posterior a la fecha de inicio")
        }
        
        if isRecurring && recurrencePeriod == nil {
            return (false, "Las metas recurrentes deben tener un periodo definido")
        }
        
        return (true, nil)
    }
    
    /// Agrega dinero a la meta
    /// - Parameter amount: Monto a agregar
    /// - Returns: Puntos ganados por esta contribución
    @discardableResult
    func addAmount(_ amount: Decimal) -> Int {
        guard status == .active else { return 0 }
        
        currentAmount += amount
        
        // Check si se completó la meta
        if currentAmount >= targetAmount {
            complete()
            return rewardPoints
        }
        
        // Puntos proporcionales por contribución (1 punto por cada 10 unidades)
        let points = Int(NSDecimalNumber(decimal: amount / 10).doubleValue)
        
        // Check sub-metas completadas
        checkSubGoalsCompletion()
        
        return points
    }
    
    /// Retira dinero de la meta
    func withdrawAmount(_ amount: Decimal) {
        currentAmount = max(0, currentAmount - amount)
    }
    
    /// Marca la meta como completada
    func complete() {
        status = .completed
        completedAt = Date()
        currentAmount = targetAmount // Asegurar que llegue al 100%
    }
    
    /// Marca la meta como no cumplida
    func fail() {
        status = .failed
    }
    
    /// Pausa la meta
    func pause() {
        status = .paused
    }
    
    /// Resume una meta pausada
    func resume() {
        guard status == .paused else { return }
        status = .active
    }
    
    /// Cancela la meta
    func cancel() {
        status = .cancelled
    }
    
    /// Crea una sub-meta automática basada en porcentaje
    /// - Parameters:
    ///   - name: Nombre de la sub-meta
    ///   - percentage: Porcentaje del total (0-100)
    ///   - targetDate: Fecha objetivo
    func createSubGoal(name: String, percentage: Double, targetDate: Date) -> SubGoal {
        let amount = targetAmount * Decimal(percentage / 100.0)
        let subGoal = SubGoal(
            name: name,
            targetAmount: amount,
            targetDate: targetDate,
            parentGoal: self
        )
        subGoals.append(subGoal)
        return subGoal
    }
    
    /// Verifica y actualiza el estado de las sub-metas
    private func checkSubGoalsCompletion() {
        for subGoal in subGoals where !subGoal.isCompleted {
            if currentAmount >= subGoal.targetAmount {
                subGoal.complete()
            }
        }
    }
    
    /// Calcula los puntos totales ganados incluyendo sub-metas
    func calculateTotalPoints() -> Int {
        var points = isCompleted ? rewardPoints : 0
        
        // Sumar puntos de sub-metas completadas
        points += subGoals.filter { $0.isCompleted }.reduce(0) { $0 + $1.rewardPoints }
        
        // Bonus por completar antes de tiempo
        if isCompleted, let completedDate = completedAt, completedDate < targetDate {
            let daysEarly = Calendar.current.dateComponents([.day], from: completedDate, to: targetDate).day ?? 0
            points += daysEarly * 2 // 2 puntos por cada día de adelanto
        }
        
        return points
    }
}

// MARK: - SubGoal Model

/// Modelo de Sub-Meta
/// Hitos intermedios dentro de una meta principal
@Model
final class SubGoal {
    
    var id: UUID
    var name: String
    var targetAmount: Decimal
    var targetDate: Date
    var isCompleted: Bool
    var completedAt: Date?
    var rewardPoints: Int
    var order: Int // Para ordenar las sub-metas
    
    // MARK: - Relationships
    
    var parentGoal: SavingGoal?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        targetDate: Date,
        parentGoal: SavingGoal,
        rewardPoints: Int = 25,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.parentGoal = parentGoal
        self.isCompleted = false
        self.rewardPoints = rewardPoints
        self.order = order
    }
}

// MARK: - SubGoal Computed Properties

extension SubGoal {
    
    /// Progreso de la sub-meta basado en el monto actual de la meta padre
    var progressPercentage: Double {
        guard let parent = parentGoal, targetAmount > 0 else { return 0 }
        let progress = NSDecimalNumber(decimal: parent.currentAmount).doubleValue /
                      NSDecimalNumber(decimal: targetAmount).doubleValue
        return min(progress * 100, 100)
    }
    
    /// Indica si está vencida
    var isOverdue: Bool {
        Date() > targetDate && !isCompleted
    }
}

// MARK: - SubGoal Business Logic

extension SubGoal {
    
    func complete() {
        isCompleted = true
        completedAt = Date()
    }
    
    func validate() -> (isValid: Bool, errorMessage: String?) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "El nombre de la sub-meta no puede estar vacío")
        }
        
        guard targetAmount > 0 else {
            return (false, "El monto objetivo debe ser mayor a cero")
        }
        
        guard parentGoal != nil else {
            return (false, "La sub-meta debe estar asociada a una meta principal")
        }
        
        if let parent = parentGoal, targetAmount > parent.targetAmount {
            return (false, "La sub-meta no puede tener un monto mayor que la meta principal")
        }
        
        return (true, nil)
    }
}

// MARK: - Identifiable & Hashable

extension SavingGoal: Identifiable { }
extension SubGoal: Identifiable { }

extension SavingGoal: Hashable {
    static func == (lhs: SavingGoal, rhs: SavingGoal) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SubGoal: Hashable {
    static func == (lhs: SubGoal, rhs: SubGoal) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Example Goals

extension SavingGoal {
    
    /// Ejemplo: Meta de fondo de emergencia
    static func createEmergencyFund(amount: Decimal, months: Int = 6) -> SavingGoal {
        let targetDate = Calendar.current.date(byAdding: .month, value: months, to: Date())!
        let goal = SavingGoal(
            name: "Fondo de Emergencia",
            description: "Fondo para imprevistos equivalente a \(months) meses de gastos",
            targetAmount: amount,
            targetDate: targetDate,
            priority: .critical,
            iconName: "shield.fill",
            colorHex: "#10B981",
            rewardPoints: 200
        )
        
        // Crear sub-metas cada 25%
        goal.createSubGoal(name: "25% del fondo", percentage: 25, targetDate: Calendar.current.date(byAdding: .month, value: months / 4, to: Date())!)
        goal.createSubGoal(name: "50% del fondo", percentage: 50, targetDate: Calendar.current.date(byAdding: .month, value: months / 2, to: Date())!)
        goal.createSubGoal(name: "75% del fondo", percentage: 75, targetDate: Calendar.current.date(byAdding: .month, value: months * 3 / 4, to: Date())!)
        
        return goal
    }
    
    /// Ejemplo: Meta de viaje
    static func createTravelGoal(destination: String, amount: Decimal, targetDate: Date) -> SavingGoal {
        return SavingGoal(
            name: "Viaje a \(destination)",
            description: "Ahorro para vacaciones en \(destination)",
            targetAmount: amount,
            targetDate: targetDate,
            priority: .medium,
            iconName: "airplane",
            colorHex: "#3B82F6",
            rewardPoints: 150
        )
    }
}
