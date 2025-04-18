//
//  AIScreenshotManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/16/25.
//

import AppKit
import Foundation
import ScreenCaptureKit

class AIScreenshotManager {
    
    static func getBase64ScreenshotImage(patchSize: Int, maxPatches: Int) async -> String? {
        guard let image = await takeScreenshot() else { return nil }
        return base64Image(image, patchSize: patchSize, maxPatches: maxPatches)
    }
    
    public static func takeScreenshot() async -> CGImage? {
        guard let targetBundleId = NSWorkspace.shared.menuBarOwningApplication?.bundleIdentifier,
              let content = try? await SCShareableContent.current,
              let application = content.applications.first(where: { $0.bundleIdentifier == targetBundleId }),
              let desktop = content.displays.first else { return nil }
        let filter = SCContentFilter(display: desktop, including: [application], exceptingWindows: [])
        
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: .init())
    }
    
    public static func base64Image(_ image: CGImage, patchSize: Int, maxPatches: Int) -> String {
        let shrink = getShrinkFactor(image: image, patchSize: patchSize, new: maxPatches)
        let newW: Float = Float(image.width) * shrink > 1 ? shrink : 1
        let newH: Float = Float(image.height) * shrink > 1 ? shrink : 1
        let newSize: CGSize = CGSize(width: Int(newW), height: Int(newH))
        
        let ns = NSImage(cgImage: image, size: newSize)
        let pngData = NSBitmapImageRep(data: ns.tiffRepresentation ?? Data())!.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
        
        return pngData.base64EncodedString()
    }
    
    private static func getPatchCount(for image: CGImage, patchSize: Int) -> Int {
        let wPatch: Int = (image.width + patchSize - 1) / patchSize
        let hPatch: Int = (image.height + patchSize - 1) / patchSize
        
        return wPatch * hPatch
    }
    
    private static func getShrinkFactor(image: CGImage, patchSize: Int, new: Int) -> Float {
        let patches = getPatchCount(for: image, patchSize: patchSize)
        return sqrtf(Float((new * patches * patches / (image.width * image.height))))
    }
    
    
}
