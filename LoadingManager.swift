class LoadingManager {
    static let shared = LoadingManager()
    
    // Private map to store operation IDs
    private var operations: [String: [UUID: OperationState]] = [:]
    private let lock = NSLock()
    
    // Struct for operation state
    private struct OperationState {
        let startTime: Date
        let timeout: TimeInterval
        var isComplete: Bool = false
    }
    
    private init() {}
    
    // Start tracking a loading operation and return an ID
    @MainActor
    func startLoading(category: String = "default", timeout: TimeInterval = 30.0) async -> UUID {
        // Asynchrone Operation einfügen
        await Task.yield()
        
        let operationId = UUID()
        
        lock.lock()
        defer { lock.unlock() }
        
        var categoryOperations = operations[category] ?? [:]
        categoryOperations[operationId] = OperationState(startTime: Date(), timeout: timeout)
        operations[category] = categoryOperations
        
        print("Loading operation started: \(category) - \(operationId)")
        return operationId
    }
    
    // End tracking a loading operation
    @MainActor
    func endLoading(category: String = "default", operationId: UUID, success: Bool) async {
        // Asynchrone Operation einfügen
        await Task.yield()
        
        lock.lock()
        defer { lock.unlock() }
        
        guard var categoryOperations = operations[category],
              categoryOperations[operationId] != nil else {
            print("Warning: Attempted to end unknown loading operation: \(category) - \(operationId)")
            return
        }
        
        // Mark as complete
        categoryOperations[operationId]?.isComplete = true
        operations[category] = categoryOperations
        
        print("Loading operation ended: \(category) - \(operationId), success: \(success)")
    }
    
    // Check if any operations are in progress for a category
    func isLoading(category: String = "default") -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let categoryOperations = operations[category] else {
            return false
        }
        
        let now = Date()
        
        // An operation is considered "loading" if it's not complete and hasn't timed out
        return categoryOperations.values.contains { state in
            !state.isComplete && now.timeIntervalSince(state.startTime) < state.timeout
        }
    }
} 