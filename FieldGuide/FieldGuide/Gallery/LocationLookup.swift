import CoreLocation
import MapKit

/// One-shot "use current place". Location permission is requested only when this runs,
/// which only happens when the person taps the button.
@MainActor
final class LocationLookup {
    enum LookupError: LocalizedError {
        case denied
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied: "Location access is off for Field Guide. You can type the place name instead."
            case .unavailable: "Couldn’t find your location right now. You can type the place name instead."
            }
        }
    }

    private let manager = CLLocationManager()

    func currentPlaceName() async throws -> String {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LookupError.denied
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }

        guard let coordinate = try await Self.firstCoordinate() else {
            throw LookupError.unavailable
        }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return await Self.placeName(for: location) ?? Self.formatted(coordinate)
    }

    /// The first fix from live updates, or nil after 15 seconds.
    private nonisolated static func firstCoordinate() async throws -> CLLocationCoordinate2D? {
        try await withThrowingTaskGroup(of: CLLocationCoordinate2D?.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if update.authorizationDenied || update.authorizationDeniedGlobally {
                        throw LookupError.denied
                    }
                    if let location = update.location {
                        return location.coordinate
                    }
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func placeName(for location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        if let name = item.name, !name.isEmpty { return name }
        return item.address?.shortAddress
    }

    private static func formatted(_ coordinate: CLLocationCoordinate2D) -> String {
        let latitude = coordinate.latitude.formatted(.number.precision(.fractionLength(3)))
        let longitude = coordinate.longitude.formatted(.number.precision(.fractionLength(3)))
        return "\(latitude)°, \(longitude)°"
    }
}
