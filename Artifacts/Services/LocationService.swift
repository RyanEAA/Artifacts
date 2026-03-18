//
//  LocationService.swift
//  Artifacts
//

import Foundation
import CoreLocation

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = LocationService()

    private let manager = CLLocationManager()

    @Published private(set) var currentCoordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 10
        currentCoordinate = manager.location?.coordinate
    }

    func start() {
        requestAuthorizationIfNeeded()
        if isAuthorized(status: manager.authorizationStatus) {
            if let existing = manager.location?.coordinate {
                currentCoordinate = existing
            }
            manager.requestLocation()
            manager.startUpdatingLocation()
        }
    }

    func currentOrCachedCoordinate() -> CLLocationCoordinate2D? {
        currentCoordinate ?? manager.location?.coordinate
    }

    func requestAuthorizationIfNeeded() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    private func isAuthorized(status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

        if isAuthorized(status: status) {
            if let existing = manager.location?.coordinate {
                DispatchQueue.main.async {
                    self.currentCoordinate = existing
                }
            }
            manager.requestLocation()
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
            DispatchQueue.main.async {
                self.currentCoordinate = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            self.currentCoordinate = latest.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location update failed:", error.localizedDescription)
    }
}
