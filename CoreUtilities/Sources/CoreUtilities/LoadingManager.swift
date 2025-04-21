import Foundation

@MainActor
public final class LoadingManager {
    public static let shared = LoadingManager()
    
    private init() {}
    
    private var activeOperations: [String: [UUID: Task<Void, Never>]] = [:]
    
    public func startLoading(category: String, timeout: TimeInterval = 5.0) async -> UUID {
        let operationId = UUID()
        
        let task = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await endLoading(category: category, operationId: operationId, success: false)
                print("⚠️ [LoadingManager] Operation timeout: \(category) (\(operationId))")
            } catch {
                // Task was cancelled
            }
        }
        
        if activeOperations[category] == nil {
            activeOperations[category] = [:]
        }
        
        activeOperations[category]?[operationId] = task
        print("▶️ [LoadingManager] Started: \(category) (\(operationId))")
        return operationId
    }
    
    public func endLoading(category: String, operationId: UUID, success: Bool) async {
        if let task = activeOperations[category]?[operationId] {
            task.cancel()
            activeOperations[category]?.removeValue(forKey: operationId)
            print("⏹️ [LoadingManager] Ended: \(category) (\(operationId)) - Success: \(success)")
        }
    }
    
    public func isOperationActive(category: String, operationId: UUID) -> Bool {
        return activeOperations[category]?[operationId] != nil
    }
} 