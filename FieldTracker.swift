import Foundation
import CoreLocation
import Combine

struct SurveyPoint: Identifiable, Codable {
    var id = UUID()
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let recordedAt: Date
    let note: String
}

@MainActor final class FieldTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var points: [SurveyPoint] = []
    @Published var message = "Solicita GPS"
    private let manager = CLLocationManager()
    private var file: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("points.json")
    }
    override init() {
        super.init()
        if let data = try? Data(contentsOf: file),
           let stored = try? JSONDecoder().decode([SurveyPoint].self, from: data) { points = stored }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    func refresh() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            message = "Buscando GPS…"
            manager.requestLocation()
        default: message = "Activa permiso de ubicación"
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { refresh() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0 else { return }
        location = last
        message = "Precisión estimada ±\(Int(last.horizontalAccuracy)) m"
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        message = error.localizedDescription
    }
    func record(_ note: String) {
        guard let loc = location else { return }
        points.append(SurveyPoint(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude,
                                  accuracyMeters: loc.horizontalAccuracy, recordedAt: loc.timestamp, note: note))
        if let data = try? JSONEncoder().encode(points) {
            try? data.write(to: file, options: .atomic)
        }
        message = "Punto guardado"
    }
}
