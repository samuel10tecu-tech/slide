import CoreMotion
import Foundation

@MainActor
final class AltimeterService {
    var onRelative: (Double) -> Void = { _ in }

    private let altimeter = CMAltimeter()
    private var running = false

    var available: Bool { CMAltimeter.isRelativeAltitudeAvailable() }

    func start() {
        guard available, !running else { return }
        running = true
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let value = data?.relativeAltitude.doubleValue else { return }
            Task { @MainActor in
                self?.onRelative(value)
            }
        }
    }

    func stop() {
        guard running else { return }
        altimeter.stopRelativeAltitudeUpdates()
        running = false
    }
}

@MainActor
final class MotionService {
    var onSample: (_ time: TimeInterval, _ magnitudeG: Double) -> Void = { _, _ in }

    private let motion = CMMotionManager()

    func start() {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 1.0 / 25.0
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let acceleration = data.acceleration
            let magnitude = sqrt(
                acceleration.x * acceleration.x
                    + acceleration.y * acceleration.y
                    + acceleration.z * acceleration.z
            )
            let timestamp = data.timestamp
            Task { @MainActor in
                self?.onSample(timestamp, magnitude)
            }
        }
    }

    func stop() {
        if motion.isAccelerometerActive {
            motion.stopAccelerometerUpdates()
        }
    }
}
