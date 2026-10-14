import Foundation

enum AreaUnit: String, CaseIterable, Identifiable {
    case squareMeters = "m²"
    case hectares = "ha"
    case squareKilometers = "km²"
    var id: String { rawValue }
    func convert(_ squareMeters: Double) -> Double {
        switch self {
        case .squareMeters: return squareMeters
        case .hectares: return squareMeters / 10000
        case .squareKilometers: return squareMeters / 1000000
        }
    }
}
