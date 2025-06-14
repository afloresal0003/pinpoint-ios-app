//
//  PinAnnotation.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/26/24.
//

import Foundation
import MapKit
import FirebaseFirestore

class PinAnnotation: NSObject, MKAnnotation {
    var pin: Pin

    init(pin: Pin) {
        self.pin = pin
        super.init()
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: pin.location.latitude,
            longitude: pin.location.longitude
        )
    }

    var title: String? {
        pin.name
    }

    var subtitle: String? {
        if let pricingLevel = pin.pricingLevel {
            let dollarSigns = String(repeating: "$", count: pricingLevel)
            return "\(pin.address) - \(dollarSigns)"
        }
        return pin.address
    }
}
