import Foundation

// Extension für MainActor, um die run-Methode mit @discardableResult zu markieren
@available(iOS 15.0, macOS 12.0, *)
extension MainActor {
    @discardableResult
    static func run<T>(_ body: @MainActor () throws -> T) async rethrows -> T {
        try await body()
    }
} 