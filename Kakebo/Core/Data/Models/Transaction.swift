//
//  Transaction.swift
//  KakeboApp
//
//  Modelo de datos para transacciones financieras
//  Representa ingresos, gastos y transferencias a ahorros
//

import Foundation
import SwiftData

/// Tipo de transacción en el sistema
enum TransactionType: String, Codable {
    case income     // Ingreso
    case expense    // Gasto
    case saving     // Ahorro/Inversión
    case transfer   // Transferencia entre categorías
}

/// Modelo principal de transacción
/// Cumple SRP: Solo representa una transacción financiera
@Model
final class Transaction {
    
    // MARK: - Properties
    
    /// Identificador único
    var id: UUID
    
    /// Monto de la transacción (siempre positivo, el tipo define si suma o resta)
    var amount: Decimal
    
    /// Tipo de transacción
    var type: TransactionType
    
    /// Descripción o concepto
    var transactionDescription: String
    
    /// Fecha de la transacción
    var date: Date
    
    /// Fecha de creación en el sistema
    var createdAt: Date
    
    /// Notas adicionales (opcional)
    var notes: String?
    
    /// Indica si es una transacción recurrente
    var isRecurring: Bool
    
    /// Periodo de recurrencia si aplica
    var recurrencePeriod: RecurrencePeriod?
    
    // MARK: - Relationships
    
    /// Categoría asociada (obligatoria)
    var category: Category?
    
    /// Subcategoría asociada (opcional)
    var subCategory: SubCategory?
    
    /// Periodo financiero al que pertenece
    var financialPeriod: FinancialPeriod?
    
    /// Etiquetas personalizadas (para filtros avanzados)
    var tags: [String]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType,
        description: String,
        date: Date = Date(),
        category: Category,
        subCategory: SubCategory? = nil,
        notes: String? = nil,
        isRecurring: Bool = false,
        recurrencePeriod: RecurrencePeriod? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.transactionDescription = description
        self.date = date
        self.createdAt = Date()
        self.category = category
        self.subCategory = subCategory
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurrencePeriod = recurrencePeriod
        self.tags = tags
    }
}

// MARK: - Computed Properties

extension Transaction {
    
    /// Retorna el monto con signo según el tipo de transacción
    /// - Income: positivo
    /// - Expense: negativo
    /// - Saving: tratado como expense (sale del flujo disponible)
    var signedAmount: Decimal {
        switch type {
        case .income:
            return amount
        case .expense, .saving:
            return -amount
        case .transfer:
            return 0 // Las transferencias no afectan el balance total
        }
    }
    
    /// Retorna el color asociado al tipo de transacción
    var typeColor: String {
        switch type {
        case .income:
            return "#10B981"  // Verde
        case .expense:
            return "#EF4444"  // Rojo
        case .saving:
            return "#3B82F6"  // Azul
        case .transfer:
            return "#6B7280"  // Gris
        }
    }
    
    /// Indica si la transacción pertenece al mes actual
    var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }
}

// MARK: - Business Logic

extension Transaction {
    
    /// Valida que la transacción tenga datos correctos
    /// - Returns: Tupla con resultado de validación y mensaje de error si aplica
    func validate() -> (isValid: Bool, errorMessage: String?) {
        // Validar monto positivo
        guard amount > 0 else {
            return (false, "El monto debe ser mayor a cero")
        }
        
        // Validar descripción no vacía
        guard !transactionDescription.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "La descripción es obligatoria")
        }
        
        // Validar categoría asignada
        guard category != nil else {
            return (false, "Debe asignar una categoría")
        }
        
        // Validar recurrencia
        if isRecurring {
            guard recurrencePeriod != nil else {
                return (false, "Las transacciones recurrentes deben tener un periodo definido")
            }
        }
        
        return (true, nil)
    }
}

// MARK: - Recurrence Period

/// Periodo de recurrencia para transacciones automáticas
enum RecurrencePeriod: String, Codable, CaseIterable {
    case daily = "Diario"
    case weekly = "Semanal"
    case biweekly = "Quincenal"
    case monthly = "Mensual"
    case quarterly = "Trimestral"
    case yearly = "Anual"
    
    /// Días que representa cada periodo
    var days: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .quarterly: return 90
        case .yearly: return 365
        }
    }
    
    /// Siguiente fecha de ejecución desde una fecha dada
    func nextDate(from date: Date) -> Date {
        switch self {
        case .daily:
            return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return Calendar.current.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

// MARK: - Identifiable & Hashable

extension Transaction: Identifiable { }

extension Transaction: Hashable {
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
