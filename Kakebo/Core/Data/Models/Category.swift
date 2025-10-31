//
//  Category.swift
//  KakeboApp
//
//  Modelo de datos para categorías y subcategorías
//  Permite organización jerárquica de transacciones con personalización total
//

import Foundation
import SwiftData

/// Tipo de categoría según método Kakebo adaptado
enum CategoryType: String, Codable, CaseIterable {
    case survival = "Supervivencia"      // Casa, servicios básicos, deudas
    case optional = "Opcional"           // Entretenimiento, hobbies
    case culture = "Cultura"             // Educación, libros, cursos
    case extra = "Extra"                 // Imprevistos, regalos
    case income = "Ingresos"             // Categoría especial para ingresos
    case saving = "Ahorros"              // Categoría especial para ahorros
    case custom = "Personalizada"        // Creada por el usuario
    
    var defaultColor: String {
        switch self {
        case .survival: return "#EF4444"  // Rojo
        case .optional: return "#F59E0B"  // Naranja
        case .culture: return "#8B5CF6"   // Morado
        case .extra: return "#EC4899"     // Rosa
        case .income: return "#10B981"    // Verde
        case .saving: return "#3B82F6"    // Azul
        case .custom: return "#6B7280"    // Gris
        }
    }
    
    var icon: String {
        switch self {
        case .survival: return "house.fill"
        case .optional: return "sparkles"
        case .culture: return "book.fill"
        case .extra: return "star.fill"
        case .income: return "arrow.down.circle.fill"
        case .saving: return "banknote.fill"
        case .custom: return "folder.fill"
        }
    }
}

/// Modelo de Categoría principal
/// Cumple SRP: Agrupa transacciones bajo un concepto común
@Model
final class Category {
    
    // MARK: - Properties
    
    var id: UUID
    var name: String
    var type: CategoryType
    var colorHex: String
    var iconName: String
    var isSystemCategory: Bool  // No se puede eliminar si es true
    var isActive: Bool
    var order: Int              // Para ordenamiento personalizado
    var createdAt: Date
    
    /// Descripción opcional de la categoría
    var categoryDescription: String?
    
    /// Límite de presupuesto mensual para esta categoría (opcional)
    var monthlyBudget: Decimal?
    
    // MARK: - Relationships
    
    /// Subcategorías asociadas
    @Relationship(deleteRule: .cascade, inverse: \SubCategory.parentCategory)
    var subCategories: [SubCategory]
    
    /// Transacciones asociadas
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        type: CategoryType,
        colorHex: String? = nil,
        iconName: String? = nil,
        isSystemCategory: Bool = false,
        isActive: Bool = true,
        order: Int = 0,
        description: String? = nil,
        monthlyBudget: Decimal? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.colorHex = colorHex ?? type.defaultColor
        self.iconName = iconName ?? type.icon
        self.isSystemCategory = isSystemCategory
        self.isActive = isActive
        self.order = order
        self.categoryDescription = description
        self.monthlyBudget = monthlyBudget
        self.createdAt = Date()
        self.subCategories = []
        self.transactions = []
    }
}

// MARK: - Computed Properties

extension Category {
    
    /// Total gastado en esta categoría en el mes actual
    var currentMonthTotal: Decimal {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Porcentaje usado del presupuesto mensual (si existe)
    var budgetUsagePercentage: Double? {
        guard let budget = monthlyBudget, budget > 0 else { return nil }
        let used = NSDecimalNumber(decimal: currentMonthTotal).doubleValue
        let total = NSDecimalNumber(decimal: budget).doubleValue
        return (used / total) * 100
    }
    
    /// Indica si se excedió el presupuesto
    var isOverBudget: Bool {
        guard let budget = monthlyBudget else { return false }
        return currentMonthTotal > budget
    }
    
    /// Número de transacciones en el mes actual
    var currentMonthTransactionCount: Int {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .count
    }
}

// MARK: - Business Logic

extension Category {
    
    /// Valida que la categoría tenga datos correctos
    func validate() -> (isValid: Bool, errorMessage: String?) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "El nombre de la categoría no puede estar vacío")
        }
        
        if let budget = monthlyBudget, budget < 0 {
            return (false, "El presupuesto no puede ser negativo")
        }
        
        return (true, nil)
    }
    
    /// Crea una subcategoría asociada a esta categoría
    func addSubCategory(_ name: String, colorHex: String? = nil, iconName: String? = nil) -> SubCategory {
        let subCategory = SubCategory(
            name: name,
            colorHex: colorHex ?? self.colorHex,
            iconName: iconName ?? self.iconName,
            parentCategory: self
        )
        subCategories.append(subCategory)
        return subCategory
    }
    
    /// Verifica si puede ser eliminada
    func canBeDeleted() -> (canDelete: Bool, reason: String?) {
        if isSystemCategory {
            return (false, "Las categorías del sistema no pueden eliminarse")
        }
        
        if !transactions.isEmpty {
            return (false, "No se puede eliminar una categoría con transacciones asociadas")
        }
        
        if !subCategories.isEmpty {
            return (false, "No se puede eliminar una categoría con subcategorías. Elimina primero las subcategorías.")
        }
        
        return (true, nil)
    }
}

// MARK: - SubCategory Model

/// Modelo de Subcategoría
/// Permite organización más específica dentro de categorías
@Model
final class SubCategory {
    
    var id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var isActive: Bool
    var order: Int
    var createdAt: Date
    
    var subCategoryDescription: String?
    var monthlyBudget: Decimal?
    
    // MARK: - Relationships
    
    /// Categoría padre
    var parentCategory: Category?
    
    /// Transacciones asociadas
    @Relationship(deleteRule: .nullify, inverse: \Transaction.subCategory)
    var transactions: [Transaction]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        iconName: String,
        parentCategory: Category,
        isActive: Bool = true,
        order: Int = 0,
        description: String? = nil,
        monthlyBudget: Decimal? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.parentCategory = parentCategory
        self.isActive = isActive
        self.order = order
        self.subCategoryDescription = description
        self.monthlyBudget = monthlyBudget
        self.createdAt = Date()
        self.transactions = []
    }
}

// MARK: - SubCategory Computed Properties

extension SubCategory {
    
    var currentMonthTotal: Decimal {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }
    
    var budgetUsagePercentage: Double? {
        guard let budget = monthlyBudget, budget > 0 else { return nil }
        let used = NSDecimalNumber(decimal: currentMonthTotal).doubleValue
        let total = NSDecimalNumber(decimal: budget).doubleValue
        return (used / total) * 100
    }
    
    var isOverBudget: Bool {
        guard let budget = monthlyBudget else { return false }
        return currentMonthTotal > budget
    }
}

// MARK: - SubCategory Business Logic

extension SubCategory {
    
    func validate() -> (isValid: Bool, errorMessage: String?) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return (false, "El nombre de la subcategoría no puede estar vacío")
        }
        
        guard parentCategory != nil else {
            return (false, "La subcategoría debe estar asociada a una categoría")
        }
        
        if let budget = monthlyBudget, budget < 0 {
            return (false, "El presupuesto no puede ser negativo")
        }
        
        return (true, nil)
    }
    
    func canBeDeleted() -> (canDelete: Bool, reason: String?) {
        if !transactions.isEmpty {
            return (false, "No se puede eliminar una subcategoría con transacciones asociadas")
        }
        
        return (true, nil)
    }
}

// MARK: - Identifiable & Hashable

extension Category: Identifiable { }
extension SubCategory: Identifiable { }

extension Category: Hashable {
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SubCategory: Hashable {
    static func == (lhs: SubCategory, rhs: SubCategory) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Default Categories

extension Category {
    
    /// Crea las categorías por defecto del sistema
    static func createDefaultCategories() -> [Category] {
        return [
            // Categorías de Gastos
            Category(name: "Casa", type: .survival, isSystemCategory: true, order: 1),
            Category(name: "Servicios", type: .survival, isSystemCategory: true, order: 2),
            Category(name: "Deudas", type: .survival, isSystemCategory: true, order: 3),
            Category(name: "Transporte", type: .survival, isSystemCategory: true, order: 4),
            Category(name: "Alimentación", type: .survival, isSystemCategory: true, order: 5),
            Category(name: "Entretenimiento", type: .optional, isSystemCategory: true, order: 6),
            Category(name: "Educación", type: .culture, isSystemCategory: true, order: 7),
            Category(name: "Salud", type: .survival, isSystemCategory: true, order: 8),
            Category(name: "Ropa", type: .optional, isSystemCategory: true, order: 9),
            Category(name: "Otros", type: .extra, isSystemCategory: true, order: 10),
            
            // Categorías especiales
            Category(name: "Ingresos", type: .income, isSystemCategory: true, order: 0),
            Category(name: "Ahorros", type: .saving, isSystemCategory: true, order: 11)
        ]
    }
    
    /// Crea subcategorías por defecto para Servicios
    static func createDefaultSubCategories(for category: Category) -> [SubCategory] {
        switch category.name {
        case "Servicios":
            return [
                SubCategory(name: "Internet", colorHex: category.colorHex, iconName: "wifi", parentCategory: category),
                SubCategory(name: "Teléfono", colorHex: category.colorHex, iconName: "phone.fill", parentCategory: category),
                SubCategory(name: "Electricidad", colorHex: category.colorHex, iconName: "bolt.fill", parentCategory: category),
                SubCategory(name: "Agua", colorHex: category.colorHex, iconName: "drop.fill", parentCategory: category),
                SubCategory(name: "Gas", colorHex: category.colorHex, iconName: "flame.fill", parentCategory: category)
            ]
        case "Transporte":
            return [
                SubCategory(name: "Gasolina", colorHex: category.colorHex, iconName: "fuelpump.fill", parentCategory: category),
                SubCategory(name: "Transporte Público", colorHex: category.colorHex, iconName: "bus.fill", parentCategory: category),
                SubCategory(name: "Mantenimiento", colorHex: category.colorHex, iconName: "wrench.fill", parentCategory: category)
            ]
        case "Alimentación":
            return [
                SubCategory(name: "Supermercado", colorHex: category.colorHex, iconName: "cart.fill", parentCategory: category),
                SubCategory(name: "Restaurantes", colorHex: category.colorHex, iconName: "fork.knife", parentCategory: category),
                SubCategory(name: "Cafeterías", colorHex: category.colorHex, iconName: "cup.and.saucer.fill", parentCategory: category)
            ]
        default:
            return []
        }
    }
}
