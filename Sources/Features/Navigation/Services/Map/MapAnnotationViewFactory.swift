import Foundation
import MapKit
import UIKit

// Struct to pass context values cleanly
struct MapAnnotationStoreContext {
    let vehicleMode: VehicleMode
    let character: Character
    let currentLegIndex: Int
}

struct MapAnnotationViewFactory {
    
    static func view(for annotation: MKAnnotation, in mapView: MKMapView, storeContext: MapAnnotationStoreContext) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return userLocationView(for: annotation, in: mapView, storeContext: storeContext)
        }
        if let car = annotation as? SimulatedCarAnnotation {
            return simulatedCarView(for: car, in: mapView, storeContext: storeContext)
        }
        if let friend = annotation as? FriendAnnotation {
            return friendView(for: friend, in: mapView)
        }
        if let wp = annotation as? QuestWaypointAnnotation {
            return questWaypointView(for: wp, in: mapView, storeContext: storeContext)
        }
        if let cam = annotation as? CameraAnnotation {
            return cameraView(for: cam, in: mapView)
        }
        if let poi = annotation as? POIAnnotation {
            return poiView(for: poi, in: mapView)
        }
        if annotation is ParkedCarAnnotation {
            return parkedCarView(for: annotation, in: mapView)
        }
        return nil
    }
    
    // MARK: - Specific Factories
    
    private static func userLocationView(for annotation: MKAnnotation, in mapView: MKMapView, storeContext: MapAnnotationStoreContext) -> MKAnnotationView {
        let id = "UserLocation"
        let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? {
            let v = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            v.layer.shadowColor = UIColor.black.cgColor
            v.layer.shadowOpacity = 0.3
            v.layer.shadowRadius = 4
            return v
        }()
        
        // This relies on state passed in, we will handle caching changes in Coordinator/Sync or here
        v.image = MapVehicleImageRenderer.image(for: storeContext.vehicleMode, character: storeContext.character)
        return v
    }
    
    private static func simulatedCarView(for car: SimulatedCarAnnotation, in mapView: MKMapView, storeContext: MapAnnotationStoreContext) -> MKAnnotationView {
        let id = "Car_\(car.vehicleType.rawValue)"
        let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? {
            let v = MKAnnotationView(annotation: car, reuseIdentifier: id)
            v.layer.shadowColor = UIColor.black.cgColor
            v.layer.shadowOpacity = 0.3
            v.layer.shadowRadius = 4
            return v
        }()
        v.image = MapVehicleImageRenderer.image(for: car.vehicleType, character: storeContext.character)
        return v
    }
    
    private static func friendView(for friend: FriendAnnotation, in mapView: MKMapView) -> MKAnnotationView {
        let id = "Friend"
        let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? {
            let v = MKAnnotationView(annotation: friend, reuseIdentifier: id)
            v.layer.shadowColor = UIColor.black.cgColor
            v.layer.shadowOpacity = 0.5
            v.layer.shadowRadius = 4
            return v
        }()
        let size = CGSize(width: 40, height: 40)
        v.image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0).setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            UIColor.white.setStroke()
            let p = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 36, height: 36))
            p.lineWidth = 2; p.stroke()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20)]
            let s = friend.memberAvatar ?? "🐾"
            let sz = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: (size.width - sz.width) / 2, y: (size.height - sz.height) / 2), withAttributes: attrs)
        }
        v.transform = CGAffineTransform(rotationAngle: CGFloat(friend.memberHeading * .pi / 180.0))
        return v
    }
    
    private static func questWaypointView(for wp: QuestWaypointAnnotation, in mapView: MKMapView, storeContext: MapAnnotationStoreContext) -> MKAnnotationView {
        let id = "QuestWP"
        let v: MKMarkerAnnotationView
        if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView {
            dequeued.annotation = wp
            v = dequeued
        } else {
            v = MKMarkerAnnotationView(annotation: wp, reuseIdentifier: id)
            v.canShowCallout = true
        }
        let isPast = wp.index <= storeContext.currentLegIndex
        let isTarget = wp.index == storeContext.currentLegIndex + 1
        v.glyphImage = UIImage(systemName: isPast ? "checkmark" : wp.wp.icon)
        v.glyphTintColor = .white
        if isPast {
            v.markerTintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
            v.displayPriority = .defaultLow
        } else if isTarget {
            v.markerTintColor = Theme.UIColors.acGold
            v.displayPriority = .required
        } else {
            v.markerTintColor = Theme.UIColors.acBorder
            v.displayPriority = .defaultHigh
        }
        return v
    }
    
    private static func cameraView(for cam: CameraAnnotation, in mapView: MKMapView) -> MKAnnotationView {
        let id = "Camera"
        let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: cam, reuseIdentifier: id)
        v.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
        v.markerTintColor = Theme.UIColors.acCoral
        v.canShowCallout = true
        return v
    }
    
    private static func poiView(for poi: POIAnnotation, in mapView: MKMapView) -> MKAnnotationView {
        let id = "POI_\(poi.type)"
        let v: MKMarkerAnnotationView
        if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView {
            v = dequeued
        } else {
            v = MKMarkerAnnotationView(annotation: poi, reuseIdentifier: id)
            v.canShowCallout = true
            let btn = UIButton(type: .contactAdd)
            btn.tintColor = Theme.UIColors.acLeaf
            v.rightCalloutAccessoryView = btn
        }
        switch poi.type {
        case .emergency: v.glyphImage = UIImage(systemName: "shield.fill"); v.markerTintColor = Theme.UIColors.acSky
        case .school:    v.glyphImage = UIImage(systemName: "figure.child"); v.markerTintColor = Theme.UIColors.acGold
        case .park:      v.glyphImage = UIImage(systemName: "tree.fill"); v.markerTintColor = Theme.UIColors.acLeaf
        case .freeway:   v.glyphImage = UIImage(systemName: "car.fill"); v.markerTintColor = Theme.UIColors.acSky
        }
        return v
    }
    
    private static func parkedCarView(for annotation: MKAnnotation, in mapView: MKMapView) -> MKAnnotationView {
        let id = "ParkedCar"
        let v: MKMarkerAnnotationView
        if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView {
            dequeued.annotation = annotation
            v = dequeued
        } else {
            v = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            v.canShowCallout = true
        }
        v.glyphImage = UIImage(systemName: "parkingsign.circle.fill")
        v.markerTintColor = Theme.UIColors.acSky
        v.displayPriority = .required
        return v
    }
}
