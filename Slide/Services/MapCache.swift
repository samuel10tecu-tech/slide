import CoreLocation
import MapKit

enum MapCache {
    /// Asks MapKit to fetch hybrid tiles around the rider so a later offline look has a chance.
    /// There is no public API to pin a whole resort. Stats never depend on this.
    static func warm(around coordinate: CLLocationCoordinate2D) {
        let distances: [CLLocationDistance] = [1_200, 4_000]
        for meters in distances {
            let options = MKMapSnapshotter.Options()
            options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters)
            options.size = CGSize(width: 360, height: 280)
            options.mapType = .hybrid
            options.showsBuildings = false
            MKMapSnapshotter(options: options).start { _, _ in }
        }
    }
}
