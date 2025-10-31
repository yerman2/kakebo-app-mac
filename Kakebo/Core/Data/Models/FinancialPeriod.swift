//
//  FinancialPeriod.swift
//  KakeboApp
//
//  Modelo para gestionar periodos financieros configurables
//  Permite visualización por semana, quincena o mes
//

import Foundation
import SwiftData

/// Tipo de periodo financiero
enum PeriodType: String, Codable, CaseIterable {
    case weekly = "Semanal"
    case biweekly = "Quincenal"
    case monthly = "Mensual"
    case custom = "Personalizado"
    
    var icon: String {
        switch self {
        case .weekly: return "calendar.day.timeline.left"
        case .biweekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .custom: return "calendar.badge.plus"
        }
    }
    
    /// Duración en días del periodo
    var durationInDays: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30 // Aproximado
        case .custom: return 0 // Se define por el usuario
        }
    }
}

/// Modelo de Periodo Financiero
/// Permite configurar y rastrear diferentes ciclos de ingreso/gasto
@Model
final class FinancialPeriod {
    
    // MARK: - Properties
    
    var id: UUID
    var name: String
    var type: PeriodType
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    var isClosed: Bool           // Un periodo cerrado no acepta más transacciones
    var createdAt: Date
    
    /// Indica si es el periodo por defecto del usuario
    var isDefault: Bool
    
    /// Meta de ahorro para este periodo específico (opcional)
    var savingGoalAmount: Decimal?
    
    /// Meta de gastos máximos para el periodo (opcional)
    var maxExpenseLimit: Decimal?
    
    // MARK: - Relationships
    
    /// Transacciones del periodo
    @Relationship(deleteRule: .nullify, inverse: \Transaction.financialPeriod)
    var transactions: [Transaction]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        type: PeriodType,
        startDate: Date,
        endDate: Date,
        isActive: Bool = true,
        isClosed: Bool = false,
        isDefault: Bool = false,
        savingGoalAmount: Decimal? = nil,
        maxExpenseLimit: Decimal? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.isClosed = isClosed
        self.isDefault = isDefault
        self.savingGoalAmount = savingGoalAmount
        self.maxExpenseLimit = maxExpenseLimit
        self.createdAt = Date()
        self.transactions = []
    }
}

// MARK: - Computed Properties

extension FinancialPeriod {
    
    /// Total de ingresos en el periodo
    var totalIncome: Decimal {
        transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Total de gastos en el periodo
    var totalExpenses: Decimal {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Total ahorrado en el periodo
    var totalSavings: Decimal {
        transactions
            .filter { $0.type == .saving }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Balance final del periodo (Ingresos - Gastos - Ahorros)
    var balance: Decimal {
        totalIncome - totalExpenses - totalSavings
    }
    
    /// Balance disponible sin contar ahorros (Ingresos - Gastos)
    var availableBalance: Decimal {
        totalIncome - totalExpenses
    }
    
    /// Porcentaje de ahorro sobre ingresos
    var savingRate: Double {
        guard totalIncome > 0 else { return 0 }
        let rate = NSDecimalNumber(decimal: totalSavings).doubleValue /
                   NSDecimalNumber(decimal: totalIncome).doubleValue
        return rate * 100
    }
    
    /// Porcentaje de gastos sobre ingresos
    var expenseRate: Double {
        guard totalIncome > 0 else { return 0 }
        let rate = NSDecimalNumber(decimal: totalExpenses).doubleValue /
                   NSDecimalNumber(decimal: totalIncome).doubleValue
        return rate * 100
    }
    
    /// Días transcurridos del periodo
    var daysElapsed: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, min(days, duration))
    }
    
    /// Días totales del periodo
    var duration: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
    
    /// Días restantes del periodo
    var daysRemaining: Int {
        max(0, duration - daysElapsed)
    }
    
    /// Porcentaje de tiempo transcurrido
    var timeElapsedPercentage: Double {
        guard duration > 0 else { return 0 }
        return (Double(daysElapsed) / Double(duration)) * 100
    }
    
    /// Indica si el periodo está activo actualmente (fecha actual dentro del rango)
    var isCurrentPeriod: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    /// Indica si el periodo ya finalizó
    var hasEnded: Bool {
        Date() > endDate
    }
    
    /// Promedio de gasto diario en el periodo
    var averageDailyExpense: Decimal {
        guard daysElapsed > 0 else { return 0 }
        return totalExpenses / Decimal(daysElapsed)
    }
    
    /// Proyección de gasto total si se mantiene el ritmo actual
    var projectedTotalExpense: Decimal {
        guard daysElapsed > 0, duration > 0 else { return 0 }
        return averageDailyExpense * Decimal(duration)
    }
}

// MARK: - Business Logic

extension FinancialPeriod {
    
    /// Valida que el periodo tenga datos correctos
    func validate() -> (isValid: Bool, errorMessage: String?) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "El nombre del periodo no puede estar vacío")
        }
        
        guard endDate > startDate else {
            return (false, "La fecha final debe ser posterior a la fecha inicial")
        }
        
        if let goal = savingGoalAmount, goal < 0 {
            return (false, "La meta de ahorro no puede ser negativa")
        }
        
        if let limit = maxExpenseLimit, limit < 0 {
            return (false, "El límite de gastos no puede ser negativo")
        }
        
        return (true, nil)
    }
    
    /// Verifica si se cumplió la meta de ahorro
    func isSavingGoalMet() -> Bool {
        guard let goal = savingGoalAmount else { return false }
        return totalSavings >= goal
    }
    
    /// Verifica si se excedió el límite de gastos
    func isOverExpenseLimit() -> Bool {
        guard let limit = maxExpenseLimit else { return false }
        return totalExpenses > limit
    }
    
    /// Cierra el periodo (no permite más transacciones)
    func close() {
        isClosed = true
        isActive = false
    }
    
    /// Calcula puntos ganados en este periodo basado en desempeño
    /// - Returns: Puntos totales del periodo
    func calculatePerformancePoints() -> Int {
        var points = 0
        
        // Puntos base por completar el periodo
        points += 10
        
        // Puntos por cumplir meta de ahorro
        if isSavingGoalMet() {
            points += 50
        }
        
        // Puntos por tasa de ahorro
        if savingRate >= 20 {
            points += 30
        } else if savingRate >= 10 {
            points += 15
        } else if savingRate >= 5 {
            points += 5
        }
        
        // Puntos por no exceder límite de gastos
        if let limit = maxExpenseLimit, totalExpenses <= limit {
            points += 25
        }
        
        // Puntos por balance positivo
        if balance > 0 {
            points += 20
        }
        
        // Bonus por excelente gestión (>30% ahorro)
        if savingRate >= 30 {
            points += 50
        }
        
        return points
    }
    
    /// Compara con un periodo anterior y otorga puntos si hay mejora
    func compareWithPrevious(_ previousPeriod: FinancialPeriod) -> (improvedSavings: Bool, points: Int) {
        let currentSavings = totalSavings
        let previousSavings = previousPeriod.totalSavings
        
        if currentSavings > previousSavings {
            // Puntos proporcionales a la mejora
            let improvement = currentSavings - previousSavings
            let improvementPercentage = (improvement / previousSavings) * 100
            
            let points: Int
            if improvementPercentage >= 50 {
                points = 100 // Mejora excepcional
            } else if improvementPercentage >= 25 {
                points = 50
            } else if improvementPercentage >= 10 {
                points = 25
            } else {
                points = 10
            }
            
            return (true, points)
        }
        
        return (false, 0)
    }
}

// MARK: - Factory Methods

extension FinancialPeriod {
    
    /// Crea un nuevo periodo mensual comenzando hoy
    static func createMonthlyPeriod(name: String? = nil) -> FinancialPeriod {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let periodName = name ?? "Periodo Mensual \(now.formatted(date: .abbreviated, time: .omitted))"
        
        return FinancialPeriod(
            name: periodName,
            type: .monthly,
            startDate: startOfMonth,
            endDate: endOfMonth,
            isActive: true,
            isDefault: true
        )
    }
    
    /// Crea un nuevo periodo semanal comenzando hoy
    static func createWeeklyPeriod(name: String? = nil) -> FinancialPeriod {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        let periodName = name ?? "Semana \(calendar.component(.weekOfYear, from: now))"
        
        return FinancialPeriod(
            name: periodName,
            type: .weekly,
            startDate: startOfWeek,
            endDate: endOfWeek,
            isActive: true
        )
    }
    
    /// Crea un nuevo periodo quincenal
    static func createBiweeklyPeriod(startDate: Date, name: String? = nil) -> FinancialPeriod {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 13, to: startDate)!
        
        let periodName = name ?? "Quincena \(startDate.formatted(date: .abbreviated, time: .omitted))"
        
        return FinancialPeriod(
            name: periodName,
            type: .biweekly,
            startDate: startDate,
            endDate: endDate,
            isActive: true
        )
    }
    
    /// Crea un periodo personalizado
    static func createCustomPeriod(
        name: String,
        startDate: Date,
        endDate: Date
    ) -> FinancialPeriod {
        return FinancialPeriod(
            name: name,
            type: .custom,
            startDate: startDate,
            endDate: endDate,
            isActive: true
        )
    }
}

// MARK: - Identifiable & Hashable

extension FinancialPeriod: Identifiable { }

extension FinancialPeriod: Hashable {
    static func == (lhs: FinancialPeriod, rhs: FinancialPeriod) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
