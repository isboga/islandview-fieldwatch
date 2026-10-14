import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @EnvironmentObject private var tracker: FieldTracker
    @State private var note = ""
    @State private var camera: MapCameraPosition = .automatic
    @State private var followGPS = true

    private var vertices: [CLLocationCoordinate2D] {
        tracker.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Text("ISLAND VIEW").font(.caption2).bold()
                    Text("FieldWatch · SIG").font(.headline)
                    Map(position: $camera) {
                        ForEach(Array(tracker.points.enumerated()), id: \.element.id) { index, point in
                            Annotation("P\(index + 1)",
                                       coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        if vertices.count >= 2 {
                            MapPolyline(coordinates: vertices)
                                .stroke(.yellow, lineWidth: 3)
                        }
                        if vertices.count >= 3 {
                            MapPolygon(coordinates: vertices)
                                .foregroundStyle(.cyan.opacity(0.18))
                                .stroke(.cyan, lineWidth: 2)
                        }
                        if let loc = tracker.location {
                            Annotation("GPS", coordinate: loc.coordinate) {
                                Image(systemName: "location.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .frame(height: 175)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(tracker.message).font(.caption2)
                    Button("Actualizar GPS") { tracker.refresh() }
                    TextField("Nota del punto", text: $note)
                    Button("Guardar vértice") {
                        tracker.record(note)
                        note = ""
                    }.disabled(tracker.location == nil)
                    if tracker.points.count >= 3 {
                        Text("Área aprox.: \(tracker.polygonAreaSquareMeters / 10000, specifier: "%.4f") ha")
                            .font(.caption)
                        Text("Perímetro: \(tracker.polygonPerimeterMeters, specifier: "%.1f") m")
                            .font(.caption)
                    }
                    ShareLink(item: tracker.geoJSON) {
                        Label("Compartir GeoJSON", systemImage: "square.and.arrow.up")
                    }
                    NavigationLink("Vértices (\(tracker.points.count))") {
                        List(tracker.points) { point in
                            VStack(alignment: .leading) {
                                Text(String(format: "%.6f, %.6f", point.latitude, point.longitude))
                                Text(point.note).font(.caption2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mapa SIG")
            .onAppear { tracker.refresh() }
            .onChange(of: tracker.location?.timestamp) { _, _ in
                guard followGPS, let loc = tracker.location else { return }
                camera = .region(MKCoordinateRegion(center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)))
                followGPS = false
            }
        }
    }
}
