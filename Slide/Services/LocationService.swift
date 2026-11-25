import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    var onLocations: ([CLLocation]) -> Void = { _ in }
    var onAuthorization: (CLAuthorizationStatus) -> Void = { _ in }
    var onFailure: (String) -> Void = { _ in }

    private let manager = CLLocationManager()
    private var backgroundEnabled = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 2
        manager.pausesLocationUpdatesAutomatically = false
    }

    var currentStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    func start() {
        enableBackgroundIfAllowed()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func enableBackgroundIfAllowed() {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }
        guard !backgroundEnabled else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        backgroundEnabled = true
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let copy = locations
        Task { @MainActor in
            self.onLocations(copy)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.enableBackgroundIfAllowed()
            }
            self.onAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let code = error as? CLError, code.code == .locationUnknown {
            return
        }
        let message = error.localizedDescription
        Task { @MainActor in
            self.onFailure(message)
        }
    }
}
