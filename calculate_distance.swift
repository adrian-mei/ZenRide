import Foundation

struct CLLocationCoordinate2D {
    var latitude: Double
    var longitude: Double
}

func haversineDistance(la1: Double, lo1: Double, la2: Double, lo2: Double) -> Double {
    let R = 6371e3 // metres
    let phi1 = la1 * .pi / 180
    let phi2 = la2 * .pi / 180
    let deltaPhi = (la2 - la1) * .pi / 180
    let deltaLambda = (lo2 - lo1) * .pi / 180

    let a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
            cos(phi1) * cos(phi2) *
            sin(deltaLambda / 2) * sin(deltaLambda / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return R * c
}

let points = [
    (37.77490, -122.41940),
    (37.77550, -122.41800),
    (37.77650, -122.41600),
    (37.77750, -122.41400),
    (37.77850, -122.41200),
    (37.77950, -122.41000),
    (37.78050, -122.40800),
    (37.78150, -122.40600)
]

var totalDistance = 0.0
for i in 1..<points.count {
    let d = haversineDistance(la1: points[i-1].0, lo1: points[i-1].1, la2: points[i].0, lo2: points[i].1)
    totalDistance += d
    print("Point \(i) distance: \(d), total: \(totalDistance)")
}
