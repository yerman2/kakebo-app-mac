//
//  TransactionRepositoryImpl.swift
//  KakeboApp
//
//  Implementación de referencia del TransactionRepository con SwiftData
//  Este es un EJEMPLO para el Módulo 1 - úsalo como guía
//

import Foundation
import SwiftData

/// Implementación concreta del TransactionRepository usando SwiftData
/// Cumple con Dependency Inversion Principle: depende de abstracción (protocol)
final class TransactionRepositoryImpl: TransactionRepository {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Inicializa el repository con un contexto de SwiftData
    /// - Parameter modelContext: Contexto para operaciones de persistencia
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    func create(_ entity: Transaction) async throws {
        // Validar antes de insertar
        let validation = entity.validate()
        guard validation.isValid else {
            throw RepositoryError.validationError(validation.errorMessage ?? "Invalid data")
        }
        
        // Insertar en el contexto
        modelContext.insert(entity)
        
        // Guardar cambios
        try modelContext.save()
    }
    
    func getAll() async throws -> [Transaction] {
        // Crear descriptor de fetch ordenado por fecha (más reciente primero)
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        // Ejecutar fetch
        return try modelContext.fetch(descriptor)
    }
    
    func getById(_ id: UUID) async throws -> Transaction? {
        // Crear predicado para buscar por ID
        let predicate = #Predicate<Transaction> { transaction in
            transaction.id == id
        }
        
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        
        // Fetch retorna array, tomamos el primero
        return try modelContext.fetch(descriptor).first
    }
    
    func update(_ entity: Transaction) async throws {
        // SwiftData detecta cambios automáticamente
        // Solo necesitamos validar y guardar
        let validation = entity.validate()
        guard validation.isValid else {
            throw RepositoryError.validationError(validation.errorMessage ?? "Invalid data")
        }
        
        try modelContext.save()
    }
    
    func delete(_ entity: Transaction) async throws {
        modelContext.delete(entity)
        try modelContext.save()
    }
    
    func deleteById(_ id: UUID) async throws {
        guard let entity = try await getById(id) else {
            throw RepositoryError.notFound
        }
        
        try await delete(entity)
    }
    
    // MARK: - Specialized Methods
    
    func getByType(_ type: TransactionType) async throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.type == type
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func getByCategory(_ categoryId: UUID) async throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.category?.id == categoryId
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func getByDateRange(from startDate: Date, to endDate: Date) async throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.date >= startDate && transaction.date <= endDate
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func getByPeriod(_ periodId: UUID) async throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.financialPeriod?.id == periodId
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func getRecent(limit: Int) async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let allTransactions = try modelContext.fetch(descriptor)
        return Array(allTransactions.prefix(limit))
    }
    
    func search(query: String) async throws -> [Transaction] {
        guard !query.isEmpty else {
            return try await getAll()
        }
        
        let lowercaseQuery = query.lowercased()
        
        let predicate = #Predicate<Transaction> { transaction in
            transaction.transactionDescription.lowercased().contains(lowercaseQuery)
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func calculateTotalByType(
        _ type: TransactionType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Decimal {
        // Obtener transacciones del tipo en el rango
        let transactions = try await getByDateRange(from: startDate, to: endDate)
        
        // Filtrar por tipo y sumar
        return transactions
            .filter { $0.type == type }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getRecurringTransactions() async throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.isRecurring == true
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func hasTransactions(forCategory categoryId: UUID) async throws -> Bool {
        let transactions = try await getByCategory(categoryId)
        return !transactions.isEmpty
    }
}

// MARK: - Usage Example

/*
 EJEMPLO DE USO EN UN VIEWMODEL:
 
 ```swift
 @Observable
 class DashboardViewModel {
     private let transactionRepo: TransactionRepository
     
     var transactions: [Transaction] = []
     var totalIncome: Decimal = 0
     var totalExpenses: Decimal = 0
     
     init(transactionRepo: TransactionRepository) {
         self.transactionRepo = transactionRepo
     }
     
     func loadData() async {
         do {
             // Cargar transacciones del mes actual
             let startOfMonth = Calendar.current.startOfMonth(for: Date())
             let endOfMonth = Calendar.current.endOfMonth(for: Date())
             
             transactions = try await transactionRepo.getByDateRange(
                 from: startOfMonth,
                 to: endOfMonth
             )
             
             // Calcular totales
             totalIncome = try await transactionRepo.calculateTotalByType(
                 .income,
                 from: startOfMonth,
                 to: endOfMonth
             )
             
             totalExpenses = try await transactionRepo.calculateTotalByType(
                 .expense,
                 from: startOfMonth,
                 to: endOfMonth
             )
             
         } catch {
             print("Error loading data: \(error)")
         }
     }
     
     func createTransaction(
         amount: Decimal,
         description: String,
         category: Category
     ) async {
         let transaction = Transaction(
             amount: amount,
             type: .expense,
             description: description,
             category: category
         )
         
         do {
             try await transactionRepo.create(transaction)
             await loadData() // Recargar datos
         } catch {
             print("Error creating transaction: \(error)")
         }
     }
 }
 ```
 
 EJEMPLO DE INICIALIZACIÓN EN LA APP:
 
 ```swift
 @main
 struct KakeboApp: App {
     let modelContainer: ModelContainer
     
     init() {
         do {
             modelContainer = try ModelContainer(for: 
                 Transaction.self,
                 Category.self,
                 // ... otros modelos
             )
         } catch {
             fatalError("Failed to initialize ModelContainer: \(error)")
         }
     }
     
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environment(\.modelContext, modelContainer.mainContext)
         }
     }
 }
 
 // En ContentView o donde se necesite:
 struct ContentView: View {
     @Environment(\.modelContext) private var modelContext
     
     var body: some View {
         let transactionRepo = TransactionRepositoryImpl(modelContext: modelContext)
         let viewModel = DashboardViewModel(transactionRepo: transactionRepo)
         
         DashboardView(viewModel: viewModel)
     }
 }
 ```
 
 EJEMPLO DE TESTING:
 
 ```swift
 class MockTransactionRepository: TransactionRepository {
     var mockTransactions: [Transaction] = []
     var createCalled = false
     
     func create(_ entity: Transaction) async throws {
         createCalled = true
         mockTransactions.append(entity)
     }
     
     func getAll() async throws -> [Transaction] {
         return mockTransactions
     }
     
     // ... implementar otros métodos
 }
 
 func testDashboardLoadsData() async {
     // Arrange
     let mockRepo = MockTransactionRepository()
     let testTransaction = Transaction(
         amount: 100,
         type: .expense,
         description: "Test",
         category: testCategory
     )
     mockRepo.mockTransactions = [testTransaction]
     
     let viewModel = DashboardViewModel(transactionRepo: mockRepo)
     
     // Act
     await viewModel.loadData()
     
     // Assert
     XCTAssertEqual(viewModel.transactions.count, 1)
     XCTAssertEqual(viewModel.totalExpenses, 100)
 }
 ```
 */

// MARK: - Performance Tips

/*
 OPTIMIZACIONES PARA PRODUCCIÓN:
 
 1. **Batch Operations:**
    - Para múltiples inserts, usa `modelContext.insertBatch()`
    - Reduce el número de saves
 
 2. **Fetch Limits:**
    - Usa `fetchLimit` en descriptors para queries grandes
    - Implementa paginación para listas largas
 
 3. **Predicates Complejos:**
    - Combina predicates para queries complejas
    - Evita fetch + filter en memoria si se puede hacer en la query
 
 4. **Caching:**
    - Considera cachear queries frecuentes
    - Invalida caché solo cuando hay cambios
 
 5. **Background Context:**
    - Para operaciones pesadas, usa un ModelContext background
    - No bloquees el main thread
 
 EJEMPLO DE BATCH INSERT:
 
 ```swift
 func createBatch(_ transactions: [Transaction]) async throws {
     for transaction in transactions {
         let validation = transaction.validate()
         guard validation.isValid else {
             throw RepositoryError.validationError(validation.errorMessage ?? "")
         }
         modelContext.insert(transaction)
     }
     
     // Un solo save al final
     try modelContext.save()
 }
 ```
 
 EJEMPLO DE PAGINACIÓN:
 
 ```swift
 func getTransactions(page: Int, pageSize: Int = 20) async throws -> [Transaction] {
     var descriptor = FetchDescriptor<Transaction>(
         sortBy: [SortDescriptor(\.date, order: .reverse)]
     )
     
     descriptor.fetchLimit = pageSize
     descriptor.fetchOffset = page * pageSize
     
     return try modelContext.fetch(descriptor)
 }
 ```
 */
