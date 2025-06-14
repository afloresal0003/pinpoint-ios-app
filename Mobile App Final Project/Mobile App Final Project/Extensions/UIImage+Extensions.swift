//
//  UIImage+Extensions.swift
//  Mobile App Final Project
//
//  Created by Ahmed Mahmud on 11/26/24.
//

import UIKit

extension UIImage {
    func fixOrientation() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

