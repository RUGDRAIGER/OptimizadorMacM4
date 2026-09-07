import Foundation

struct CPUMetrics: Codable, Sendable, Equatable {
    let performanceCoresUsage: Double
    let efficiencyCoresUsage: Double
    let totalUsage: Double
    let performanceCoreCount: Int
    let efficiencyCoreCount: Int
    let timestamp: Date

    var isValid: Bool {
        (0...100).contains(performanceCoresUsage)
            && (0...100).contains(efficiencyCoresUsage)
            && (0...100).contains(totalUsage)
    }
}

struct CPUCoreInfo: Sendable {
    let performanceCoreCount: Int
    let efficiencyCoreCount: Int
    let totalLogicalCores: Int
}
