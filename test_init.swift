import Foundation

struct TomTomInstruction: Decodable {
    let routeOffsetInMeters: Int
    let travelTimeInSeconds: Int
    let pointIndex: Int
    let instructionType: String?
    let street: String?
    let message: String?
}

let a = TomTomInstruction(routeOffsetInMeters: 100, travelTimeInSeconds: 10, pointIndex: 2, instructionType: "TURN_RIGHT", street: "Main", message: "Turn right")
print(a)
