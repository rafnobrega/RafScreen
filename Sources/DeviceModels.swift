import Foundation
import CoreGraphics

enum NotchStyle {
    case none           // iPhone 8 and earlier, SE
    case notch          // iPhone X through 14
    case dynamicIsland  // iPhone 14 Pro and later
    case iPadCamera     // iPad front camera area (no notch)
}

enum DeviceCategory: String {
    case iPhone
    case iPad
}

struct DeviceModel {
    let name: String
    let category: DeviceCategory
    let screenWidth: CGFloat      // Logical points
    let screenHeight: CGFloat     // Logical points
    let nativeWidth: Int          // Native pixel width
    let nativeHeight: Int         // Native pixel height
    let cornerRadius: CGFloat     // Screen corner radius in points
    let notchStyle: NotchStyle
    let hasHomeButton: Bool
    let bezelWidth: CGFloat       // Bezel thickness around screen
    let statusBarHeight: CGFloat  // For positioning notch/island

    // Computed aspect ratio
    var aspectRatio: CGFloat { screenHeight / screenWidth }

    // Display name for menu
    var displayName: String { name }
}

struct DeviceModelStore {
    static let allModels: [DeviceModel] = iPhones + iPads

    static let iPhones: [DeviceModel] = [
        // Home button models
        DeviceModel(name: "iPhone SE (2nd gen)", category: .iPhone,
                    screenWidth: 375, screenHeight: 667, nativeWidth: 750, nativeHeight: 1334,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 18, statusBarHeight: 20),
        DeviceModel(name: "iPhone 8", category: .iPhone,
                    screenWidth: 375, screenHeight: 667, nativeWidth: 750, nativeHeight: 1334,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 18, statusBarHeight: 20),
        DeviceModel(name: "iPhone 8 Plus", category: .iPhone,
                    screenWidth: 414, screenHeight: 736, nativeWidth: 1080, nativeHeight: 1920,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 18, statusBarHeight: 20),
        DeviceModel(name: "iPhone SE (3rd gen)", category: .iPhone,
                    screenWidth: 375, screenHeight: 667, nativeWidth: 750, nativeHeight: 1334,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 18, statusBarHeight: 20),

        // Notch models
        DeviceModel(name: "iPhone X", category: .iPhone,
                    screenWidth: 375, screenHeight: 812, nativeWidth: 1125, nativeHeight: 2436,
                    cornerRadius: 39, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone XS", category: .iPhone,
                    screenWidth: 375, screenHeight: 812, nativeWidth: 1125, nativeHeight: 2436,
                    cornerRadius: 39, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone XS Max", category: .iPhone,
                    screenWidth: 414, screenHeight: 896, nativeWidth: 1242, nativeHeight: 2688,
                    cornerRadius: 39, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone XR", category: .iPhone,
                    screenWidth: 414, screenHeight: 896, nativeWidth: 828, nativeHeight: 1792,
                    cornerRadius: 39, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone 11", category: .iPhone,
                    screenWidth: 414, screenHeight: 896, nativeWidth: 828, nativeHeight: 1792,
                    cornerRadius: 39, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone 11 Pro", category: .iPhone,
                    screenWidth: 375, screenHeight: 812, nativeWidth: 1125, nativeHeight: 2436,
                    cornerRadius: 39, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone 11 Pro Max", category: .iPhone,
                    screenWidth: 414, screenHeight: 896, nativeWidth: 1242, nativeHeight: 2688,
                    cornerRadius: 39, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone 12 Mini", category: .iPhone,
                    screenWidth: 360, screenHeight: 780, nativeWidth: 1080, nativeHeight: 2340,
                    cornerRadius: 44, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone 12", category: .iPhone,
                    screenWidth: 390, screenHeight: 844, nativeWidth: 1170, nativeHeight: 2532,
                    cornerRadius: 47, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 47),
        DeviceModel(name: "iPhone 12 Pro", category: .iPhone,
                    screenWidth: 390, screenHeight: 844, nativeWidth: 1170, nativeHeight: 2532,
                    cornerRadius: 47, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 47),
        DeviceModel(name: "iPhone 12 Pro Max", category: .iPhone,
                    screenWidth: 428, screenHeight: 926, nativeWidth: 1284, nativeHeight: 2778,
                    cornerRadius: 47, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 47),
        DeviceModel(name: "iPhone 13 Mini", category: .iPhone,
                    screenWidth: 360, screenHeight: 780, nativeWidth: 1080, nativeHeight: 2340,
                    cornerRadius: 44, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 44),
        DeviceModel(name: "iPhone 13", category: .iPhone,
                    screenWidth: 390, screenHeight: 844, nativeWidth: 1170, nativeHeight: 2532,
                    cornerRadius: 47, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 47),
        DeviceModel(name: "iPhone 13 Pro", category: .iPhone,
                    screenWidth: 390, screenHeight: 844, nativeWidth: 1170, nativeHeight: 2532,
                    cornerRadius: 47, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 47),
        DeviceModel(name: "iPhone 13 Pro Max", category: .iPhone,
                    screenWidth: 428, screenHeight: 926, nativeWidth: 1284, nativeHeight: 2778,
                    cornerRadius: 47, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 47),
        DeviceModel(name: "iPhone 14", category: .iPhone,
                    screenWidth: 390, screenHeight: 844, nativeWidth: 1170, nativeHeight: 2532,
                    cornerRadius: 47, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 47),
        DeviceModel(name: "iPhone 14 Plus", category: .iPhone,
                    screenWidth: 428, screenHeight: 926, nativeWidth: 1284, nativeHeight: 2778,
                    cornerRadius: 47, notchStyle: .notch, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 47),

        // Dynamic Island models
        DeviceModel(name: "iPhone 14 Pro", category: .iPhone,
                    screenWidth: 393, screenHeight: 852, nativeWidth: 1179, nativeHeight: 2556,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 14 Pro Max", category: .iPhone,
                    screenWidth: 430, screenHeight: 932, nativeWidth: 1290, nativeHeight: 2796,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 15", category: .iPhone,
                    screenWidth: 393, screenHeight: 852, nativeWidth: 1179, nativeHeight: 2556,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 15 Plus", category: .iPhone,
                    screenWidth: 430, screenHeight: 932, nativeWidth: 1290, nativeHeight: 2796,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 15 Pro", category: .iPhone,
                    screenWidth: 393, screenHeight: 852, nativeWidth: 1179, nativeHeight: 2556,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 15 Pro Max", category: .iPhone,
                    screenWidth: 430, screenHeight: 932, nativeWidth: 1290, nativeHeight: 2796,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 16", category: .iPhone,
                    screenWidth: 393, screenHeight: 852, nativeWidth: 1179, nativeHeight: 2556,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 16 Plus", category: .iPhone,
                    screenWidth: 430, screenHeight: 932, nativeWidth: 1290, nativeHeight: 2796,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 16 Pro", category: .iPhone,
                    screenWidth: 402, screenHeight: 874, nativeWidth: 1206, nativeHeight: 2622,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 16 Pro Max", category: .iPhone,
                    screenWidth: 440, screenHeight: 956, nativeWidth: 1320, nativeHeight: 2868,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),

        // iPhone 17 series
        DeviceModel(name: "iPhone 17", category: .iPhone,
                    screenWidth: 393, screenHeight: 852, nativeWidth: 1179, nativeHeight: 2556,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 17 Air", category: .iPhone,
                    screenWidth: 402, screenHeight: 874, nativeWidth: 1206, nativeHeight: 2622,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 17 Pro", category: .iPhone,
                    screenWidth: 402, screenHeight: 874, nativeWidth: 1206, nativeHeight: 2622,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
        DeviceModel(name: "iPhone 17 Pro Max", category: .iPhone,
                    screenWidth: 440, screenHeight: 956, nativeWidth: 1320, nativeHeight: 2868,
                    cornerRadius: 55, notchStyle: .dynamicIsland, hasHomeButton: false, bezelWidth: 4, statusBarHeight: 54),
    ]

    static let iPads: [DeviceModel] = [
        DeviceModel(name: "iPad (8th gen)", category: .iPad,
                    screenWidth: 810, screenHeight: 1080, nativeWidth: 1620, nativeHeight: 2160,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 24, statusBarHeight: 20),
        DeviceModel(name: "iPad Mini (4th gen)", category: .iPad,
                    screenWidth: 768, screenHeight: 1024, nativeWidth: 1536, nativeHeight: 2048,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 24, statusBarHeight: 20),
        DeviceModel(name: "iPad Air (3rd gen)", category: .iPad,
                    screenWidth: 834, screenHeight: 1112, nativeWidth: 1668, nativeHeight: 2224,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 24, statusBarHeight: 20),
        DeviceModel(name: "iPad Air (4th gen)", category: .iPad,
                    screenWidth: 820, screenHeight: 1180, nativeWidth: 1640, nativeHeight: 2360,
                    cornerRadius: 18, notchStyle: .iPadCamera, hasHomeButton: false, bezelWidth: 12, statusBarHeight: 24),
        DeviceModel(name: "iPad Pro 9.7\"", category: .iPad,
                    screenWidth: 768, screenHeight: 1024, nativeWidth: 1536, nativeHeight: 2048,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 24, statusBarHeight: 20),
        DeviceModel(name: "iPad Pro 10.5\"", category: .iPad,
                    screenWidth: 834, screenHeight: 1112, nativeWidth: 1668, nativeHeight: 2224,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 24, statusBarHeight: 20),
        DeviceModel(name: "iPad Pro 11\" (1st gen)", category: .iPad,
                    screenWidth: 834, screenHeight: 1194, nativeWidth: 1668, nativeHeight: 2388,
                    cornerRadius: 18, notchStyle: .iPadCamera, hasHomeButton: false, bezelWidth: 12, statusBarHeight: 24),
        DeviceModel(name: "iPad Pro 11\" (2nd gen)", category: .iPad,
                    screenWidth: 834, screenHeight: 1194, nativeWidth: 1668, nativeHeight: 2388,
                    cornerRadius: 18, notchStyle: .iPadCamera, hasHomeButton: false, bezelWidth: 12, statusBarHeight: 24),
        DeviceModel(name: "iPad Pro 12.9\" (1st gen)", category: .iPad,
                    screenWidth: 1024, screenHeight: 1366, nativeWidth: 2048, nativeHeight: 2732,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 24, statusBarHeight: 20),
        DeviceModel(name: "iPad Pro 12.9\" (2nd gen)", category: .iPad,
                    screenWidth: 1024, screenHeight: 1366, nativeWidth: 2048, nativeHeight: 2732,
                    cornerRadius: 0, notchStyle: .none, hasHomeButton: true, bezelWidth: 24, statusBarHeight: 20),
        DeviceModel(name: "iPad Pro 12.9\" (3rd gen)", category: .iPad,
                    screenWidth: 1024, screenHeight: 1366, nativeWidth: 2048, nativeHeight: 2732,
                    cornerRadius: 18, notchStyle: .iPadCamera, hasHomeButton: false, bezelWidth: 12, statusBarHeight: 24),
        DeviceModel(name: "iPad Pro 12.9\" (4th gen)", category: .iPad,
                    screenWidth: 1024, screenHeight: 1366, nativeWidth: 2048, nativeHeight: 2732,
                    cornerRadius: 18, notchStyle: .iPadCamera, hasHomeButton: false, bezelWidth: 12, statusBarHeight: 24),
    ]

    static func defaultModel() -> DeviceModel {
        return iPhones.first(where: { $0.name == "iPhone 14" }) ?? iPhones[0]
    }

    static func model(named name: String) -> DeviceModel? {
        return allModels.first(where: { $0.name == name })
    }

    /// Auto-detect the best matching device model based on native pixel resolution
    static func modelForResolution(width: Int, height: Int) -> DeviceModel? {
        // Try exact match first
        if let exact = allModels.first(where: { $0.nativeWidth == width && $0.nativeHeight == height }) {
            return exact
        }
        // Try swapped (landscape)
        if let swapped = allModels.first(where: { $0.nativeWidth == height && $0.nativeHeight == width }) {
            return swapped
        }
        // Find closest match by aspect ratio
        let targetRatio = CGFloat(height) / CGFloat(width)
        let closest = allModels.min(by: { abs($0.aspectRatio - targetRatio) < abs($1.aspectRatio - targetRatio) })
        return closest
    }
}
