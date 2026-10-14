import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tracker: FieldTracker
    @State private var note = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Text("ISLAND VIEW").font(.caption).bold()
                    Text("FieldWatch").font(.headline)
                    Text(tracker.message).font(.caption2)
                    if let loc = tracker.location {
                        Text(String(format: "%.6f", loc.coordinate.latitude))
                        Text(String(format: "%.6f", loc.coordinate.longitude))
                    }
                    Button("Actualizar GPS") { tracker.refresh() }
                    TextField("Nota", text: $note)
                    Button("Guardar punto") {
                        tracker.record(note)
                        note = ""
                    }.disabled(tracker.location == nil)
                    if tracker.points.count >= 3 {
                        Text("Área: \(tracker.polygonAreaSquareMeters / 10000, specifier: "%.4f") ha")
                            .font(.caption)
                        Text("Perímetro: \(tracker.polygonPerimeterMeters, specifier: "%.1f") m")
                            .font(.caption)
                    }
                    ShareLink(item: tracker.geoJSON, subject: Text("FieldWatch GeoJSON"),
                              message: Text("Datos SIG de Island View")) {
                        Label("Compartir GeoJSON", systemImage: "square.and.arrow.up")
                    }
                    NavigationLink("Puntos: \(tracker.points.count)") {
                        List(tracker.points) { point in
                            VStack(alignment: .leading) {
                                Text(String(format: "%.6f, %.6f", point.latitude, point.longitude))
                                Text(point.note).font(.caption2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Campo")
            .onAppear { tracker.refresh() }
        }
    }
}
