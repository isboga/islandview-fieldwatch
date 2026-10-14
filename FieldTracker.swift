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

    // Polígono formado por los puntos capturados, en orden de registro.
    var polygonAreaSquareMeters: Double {
        guard points.count >= 3 else { return 0 }
        let radius = 6_371_008.8
        var sum = 0.0
        for i in points.indices {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            let lat1 = a.latitude * .pi / 180
            let lat2 = b.latitude * .pi / 180
            var delta = (b.longitude - a.longitude) * .pi / 180
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            sum += delta * (sin(lat1) + sin(lat2))
        }
        return abs(sum) * radius * radius / 2
    }

    var polygonPerimeterMeters: Double {
        guard points.count >= 3 else { return 0 }
        var total = 0.0
        for i in points.indices {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            let p1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
            let p2 = CLLocation(latitude: b.latitude, longitude: b.longitude)
            total += p1.distance(from: p2)
        }
        return total
    }

    var geoJSON: String {
        let pointFeatures: [[String: Any]] = points.enumerated().map { index, p in
            ["type": "Feature",
             "geometry": ["type": "Point", "coordinates": [p.longitude, p.latitude]],
             "properties": ["name": "P\(index + 1)", "note": p.note,
                            "accuracy_m": p.accuracyMeters,
                            "timestamp": ISO8601DateFormatter().string(from: p.recordedAt)]]
        }
        var features = pointFeatures
        if points.count >= 3 {
            let ring = points.map { [$0.longitude, $0.latitude] } +
                       [[points[0].longitude, points[0].latitude]]
            features.append(["type": "Feature",
                             "geometry": ["type": "Polygon", "coordinates": [ring]],
                             "properties": ["area_m2": polygonAreaSquareMeters,
                                            "perimeter_m": polygonPerimeterMeters]])
        }
        let collection: [String: Any] = ["type": "FeatureCollection", "features": features]
        guard let data = try? JSONSerialization.data(withJSONObject: collection,
                                                     options: [.prettyPrinted, .sortedKeys]),
              let value = String(data: data, encoding: .utf8) else { return "{}" }
        return value
    }
}
