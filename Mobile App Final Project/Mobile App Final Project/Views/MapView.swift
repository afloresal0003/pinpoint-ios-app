// MapView.swift
import SwiftUI
import MapKit
import CoreLocation

struct MapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    @Binding var selectedPin: Pin?
    
    
    // class for Location Manager
    final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
        var lastKnownLocation: CLLocationCoordinate2D?
        var manager = CLLocationManager()
        
        func checkLocationAuthorization() {
            manager.delegate = self
            manager.startUpdatingLocation()
            
            switch manager.authorizationStatus {
            case .notDetermined://The user choose allow or denny your app to get the location yet
                manager.requestWhenInUseAuthorization()
                
            case .restricted://The user cannot change this app’s status, possibly due to active restrictions such as parental controls being in place.
                print("Location restricted")
                
            case .denied://The user dennied your app to get location or disabled the services location or the phone is in airplane mode
                print("Location denied")
                
            case .authorizedAlways://This authorization allows you to use all location services and receive location events whether or not your app is in use.
                print("Location authorizedAlways")
                
            case .authorizedWhenInUse://This authorization allows you to use all location services and receive location events only when your app is in use
                print("Location authorized when in use")
                lastKnownLocation = manager.location?.coordinate
                
            @unknown default:
                print("Location service disabled")
            }
        }
        
        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {//Trigged every time authorization status changes
            checkLocationAuthorization()
        }
            
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            lastKnownLocation = locations.first?.coordinate
        }
    }
    
    
    @StateObject private var locationManager = LocationManager()

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true // show user location
        mapView.userTrackingMode = .follow // follow user on map if they move
        
        // Register PinAnnotation class
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(PinAnnotation.self))
        
        // Add Long Press Gesture Recognizer
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(gesture:)))
        mapView.addGestureRecognizer(longPressGesture)
        
        locationManager.checkLocationAuthorization()
        
        if let coordinate = locationManager.lastKnownLocation {
            // center of initial region (user's location)
            let centerCoordinate = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            let zoomLevel = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2) // zoom level
            
            // Create the region
            let region = MKCoordinateRegion(center: centerCoordinate, span: zoomLevel)
            
            // Set the region on the map view
            mapView.setRegion(region, animated: true)
            
        } else {
            print("Unknown Location")
        }
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations)
        uiView.addAnnotations(viewModel.annotations)
        
        if let region = viewModel.region {
            uiView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    
    
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        // Customize annotation view
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pinAnnotation = annotation as? PinAnnotation else { return nil }
            let identifier = NSStringFromClass(PinAnnotation.self)
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: pinAnnotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false // We'll handle callout via SwiftUI
                annotationView?.markerTintColor = .blue
            } else {
                annotationView?.annotation = pinAnnotation
            }
            return annotationView
        }
        
        // Handle pin selection
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pinAnnotation = view.annotation as? PinAnnotation else { return }
            parent.selectedPin = pinAnnotation.pin
            mapView.deselectAnnotation(pinAnnotation, animated: true)
        }
        
        // Handle Long Press Gesture
        @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                let location = gesture.location(in: gesture.view)
                if let mapView = gesture.view as? MKMapView {
                    let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
                    
                    // Call the ViewModel's addPin with coordinate
                    parent.viewModel.addPin(coordinate: coordinate) { success in
                        if success {
                            // PinDetailView will be presented automatically via selectedPin binding
                        } else {
                            // Handle error (e.g., show alert)
                            print("Failed to add pin.")
                        }
                    }
                }
            }
        }
    }
}
