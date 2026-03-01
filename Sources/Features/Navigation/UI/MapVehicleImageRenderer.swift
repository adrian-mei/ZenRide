import UIKit

/// Renders UIImages for the player's vehicle/character pin on the map.
enum MapVehicleImageRenderer {

    static func image(for type: VehicleType, character: Character) -> UIImage {
        if type.isOnFoot { return onFootImage(for: character) }
        return vehicleImage(for: type, character: character)
    }

    // MARK: - On-foot (avatar circle)

    private static func onFootImage(for character: Character) -> UIImage {
        let size = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.setShadow(offset: CGSize(width: 0, height: 3), blur: 6,
                              color: UIColor.black.withAlphaComponent(0.35).cgColor)

            let avatarRect = CGRect(x: 2, y: 2, width: 40, height: 40)
            let charColor = UIColor(hex: character.colorHex) ?? .systemOrange
            charColor.setFill()
            UIBezierPath(ovalIn: avatarRect).fill()

            UIColor.white.setStroke()
            let border = UIBezierPath(ovalIn: avatarRect)
            border.lineWidth = 3
            border.stroke()

            drawCharacterSymbol(character: character, in: avatarRect, padding: 8)
        }
    }

    // MARK: - Vehicle

    private static func vehicleImage(for type: VehicleType, character: Character) -> UIImage {
        let size = CGSize(width: 50, height: 60)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.setShadow(offset: CGSize(width: 0, height: 4), blur: 6,
                              color: UIColor.black.withAlphaComponent(0.3).cgColor)

            var bodyColor: UIColor
            var bodyRect: CGRect
            var hasTop: Bool
            var cornerRadius: CGFloat = 10

            switch type {
            case .car:
                bodyColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                bodyRect  = CGRect(x: 10, y: 15, width: 30, height: 40)
                hasTop    = true
            case .sportsCar:
                bodyColor = UIColor.systemRed
                bodyRect  = CGRect(x: 8, y: 22, width: 34, height: 32)
                hasTop    = true
            case .electricCar:
                bodyColor = UIColor.systemCyan
                bodyRect  = CGRect(x: 10, y: 15, width: 30, height: 40)
                hasTop    = true
            case .suv:
                bodyColor    = UIColor(red: 0.4, green: 0.55, blue: 0.35, alpha: 1.0)
                bodyRect     = CGRect(x: 6, y: 8, width: 38, height: 46)
                hasTop       = true
                cornerRadius = 6
            case .truck:
                bodyColor    = UIColor.systemGray
                bodyRect     = CGRect(x: 5, y: 5, width: 40, height: 50)
                hasTop       = true
                cornerRadius = 4
            case .motorcycle, .scooter:
                bodyColor = UIColor.systemRed
                bodyRect  = CGRect(x: 18, y: 10, width: 14, height: 40)
                hasTop    = false
            case .bicycle:
                bodyColor = UIColor.systemBlue
                bodyRect  = CGRect(x: 22, y: 15, width: 6, height: 35)
                hasTop    = false
            case .mountainBike:
                bodyColor = UIColor.systemGreen
                bodyRect  = CGRect(x: 22, y: 15, width: 6, height: 35)
                hasTop    = false
            case .walking, .running, .skateboard:
                bodyColor = UIColor.clear
                bodyRect  = CGRect(x: 11, y: 10, width: 28, height: 40)
                hasTop    = false
            }

            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: cornerRadius)
            bodyColor.setFill()
            bodyPath.fill()

            if hasTop {
                let roofRect = CGRect(x: bodyRect.minX, y: bodyRect.minY - 5,
                                     width: bodyRect.width, height: bodyRect.height * 0.5)
                let roofPath = UIBezierPath(roundedRect: roofRect,
                                            byRoundingCorners: [.topLeft, .topRight],
                                            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
                UIColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1.0).setFill()
                roofPath.fill()

                let glassPath = UIBezierPath(roundedRect: CGRect(x: bodyRect.minX + 4, y: bodyRect.minY + 1,
                                                                  width: bodyRect.width - 8, height: 10),
                                             cornerRadius: 4)
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0).setFill()
                glassPath.fill()

                if type == .sportsCar {
                    let spoilerPath = UIBezierPath(rect: CGRect(x: bodyRect.minX - 2, y: bodyRect.minY - 4,
                                                                width: bodyRect.width + 4, height: 3))
                    UIColor.darkGray.setFill()
                    spoilerPath.fill()
                }
            } else if type == .motorcycle || type == .scooter {
                let screenPath = UIBezierPath(roundedRect: CGRect(x: bodyRect.minX - 2, y: bodyRect.minY - 2,
                                                                   width: bodyRect.width + 4, height: 8),
                                              cornerRadius: 4)
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0).setFill()
                screenPath.fill()

                let barPath = UIBezierPath(rect: CGRect(x: bodyRect.minX - 6, y: bodyRect.minY + 6,
                                                        width: bodyRect.width + 12, height: 3))
                UIColor.darkGray.setFill()
                barPath.fill()
            } else if type == .bicycle || type == .mountainBike {
                let wheelColor = (type == .mountainBike) ? UIColor.systemGreen : UIColor.systemBlue
                for wheelY in [bodyRect.minY + 3, bodyRect.maxY - 9] {
                    let wheelPath = UIBezierPath(ovalIn: CGRect(x: bodyRect.minX - 7, y: wheelY, width: 20, height: 20))
                    wheelColor.withAlphaComponent(0.4).setFill()
                    wheelPath.fill()
                    wheelColor.setStroke()
                    wheelPath.lineWidth = 2
                    wheelPath.stroke()
                }
            }

            let borderRect = CGRect(x: bodyRect.minX, y: bodyRect.minY - (hasTop ? 5 : 0),
                                    width: bodyRect.width, height: bodyRect.height + (hasTop ? 5 : 0))
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: cornerRadius)
            UIColor.white.setStroke()
            borderPath.lineWidth = 3
            borderPath.stroke()

            if !type.isOnFoot && type != .bicycle && type != .mountainBike {
                let lightY = bodyRect.maxY - 2
                for xOff in [bodyRect.minX + 4, bodyRect.maxX - 10] {
                    let lightPath = UIBezierPath(ovalIn: CGRect(x: xOff, y: lightY, width: 6, height: 4))
                    UIColor(red: 1.0, green: 0.98, blue: 0.8, alpha: 1.0).setFill()
                    lightPath.fill()
                }
            }

            let avatarDiam: CGFloat = 28
            let avatarRect = CGRect(
                x: bodyRect.midX - avatarDiam / 2,
                y: bodyRect.midY - avatarDiam / 2 - (hasTop ? 4 : 8),
                width: avatarDiam, height: avatarDiam
            )
            let charColor = UIColor(hex: character.colorHex) ?? .systemOrange
            charColor.setFill()
            UIBezierPath(ovalIn: avatarRect).fill()

            let avatarBorder = UIBezierPath(ovalIn: avatarRect)
            UIColor.white.setStroke()
            avatarBorder.lineWidth = 2
            avatarBorder.stroke()

            drawCharacterSymbol(character: character, in: avatarRect, padding: 5)
        }
    }

    // MARK: - Shared

    private static func drawCharacterSymbol(character: Character, in rect: CGRect, padding: CGFloat) {
        let config = UIImage.SymbolConfiguration(pointSize: rect.width - padding * 2, weight: .bold)
        if let symbol = UIImage(systemName: character.icon, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
            let symSize = symbol.size
            let origin = CGPoint(
                x: rect.midX - symSize.width / 2,
                y: rect.midY - symSize.height / 2
            )
            symbol.draw(at: origin)
        }
    }
}
