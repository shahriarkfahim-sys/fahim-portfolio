import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
import Vision

struct Options {
  let inputPath: String
  let outputPath: String
  let canvasWidth: Int = 720
  let canvasHeight: Int = 900
}

enum PortraitError: Error, CustomStringConvertible {
  case badArguments
  case cannotLoadImage(String)
  case cannotCreateMask
  case cannotRenderImage
  case cannotWriteImage(String)

  var description: String {
    switch self {
    case .badArguments:
      return "Usage: swift tools/create-home-portrait.swift <input-image> <output-png>"
    case .cannotLoadImage(let path):
      return "Could not load image at \(path)"
    case .cannotCreateMask:
      return "Could not create a foreground mask"
    case .cannotRenderImage:
      return "Could not render the output image"
    case .cannotWriteImage(let path):
      return "Could not write PNG to \(path)"
    }
  }
}

func loadCGImage(from path: String) throws -> CGImage {
  let url = URL(fileURLWithPath: path)
  guard
    let source = CGImageSourceCreateWithURL(url as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, [
      kCGImageSourceShouldCache: true
    ] as CFDictionary)
  else {
    throw PortraitError.cannotLoadImage(path)
  }
  return image
}

func personSegmentationMask(for image: CGImage) throws -> CGImage {
  let request = VNGeneratePersonSegmentationRequest()
  request.qualityLevel = .accurate
  request.outputPixelFormat = kCVPixelFormatType_OneComponent8

  let handler = VNImageRequestHandler(cgImage: image, options: [:])
  try handler.perform([request])

  guard let observation = request.results?.first else {
    throw PortraitError.cannotCreateMask
  }

  let context = CIContext(options: [.useSoftwareRenderer: false])
  let rawMask = CIImage(cvPixelBuffer: observation.pixelBuffer)
  let scaledMask = rawMask.transformed(
    by: CGAffineTransform(
      scaleX: CGFloat(image.width) / rawMask.extent.width,
      y: CGFloat(image.height) / rawMask.extent.height
    )
  )

  guard let cgMask = context.createCGImage(
    scaledMask,
    from: CGRect(x: 0, y: 0, width: image.width, height: image.height)
  ) else {
    throw PortraitError.cannotCreateMask
  }
  return cgMask
}

func instanceMask(for image: CGImage) throws -> CGImage {
  let request = VNGenerateForegroundInstanceMaskRequest()
  let handler = VNImageRequestHandler(cgImage: image, options: [:])
  try handler.perform([request])

  guard
    let observation = request.results?.first as? VNInstanceMaskObservation,
    !observation.allInstances.isEmpty
  else {
    throw PortraitError.cannotCreateMask
  }

  let mask = try observation.generateScaledMaskForImage(
    forInstances: observation.allInstances,
    from: handler
  )

  let context = CIContext(options: [.useSoftwareRenderer: false])
  let maskImage = CIImage(cvPixelBuffer: mask)
  guard let cgMask = context.createCGImage(maskImage, from: maskImage.extent) else {
    throw PortraitError.cannotCreateMask
  }
  return cgMask
}

func foregroundMask(for image: CGImage) throws -> CGImage {
  do {
    return try personSegmentationMask(for: image)
  } catch {
    return try instanceMask(for: image)
  }
}

func boundingBox(in mask: CGImage, threshold: UInt8 = 20) -> CGRect {
  let width = mask.width
  let height = mask.height
  var pixels = [UInt8](repeating: 0, count: width * height)

  let colorSpace = CGColorSpaceCreateDeviceGray()
  let bitmapInfo = CGImageAlphaInfo.none.rawValue
  let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width,
    space: colorSpace,
    bitmapInfo: bitmapInfo
  )
  context?.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))

  var minX = width
  var minY = height
  var maxX = 0
  var maxY = 0

  for y in 0..<height {
    for x in 0..<width {
      if pixels[y * width + x] > threshold {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
    }
  }

  guard minX <= maxX, minY <= maxY else {
    return CGRect(x: 0, y: 0, width: width, height: height)
  }

  let boxWidth = maxX - minX + 1
  let boxHeight = maxY - minY + 1
  let marginX = Int(Double(boxWidth) * 0.055)
  let marginTop = Int(Double(boxHeight) * 0.05)
  let marginBottom = Int(Double(boxHeight) * 0.01)

  let x = max(0, minX - marginX)
  let y = max(0, minY - marginTop)
  let right = min(width, maxX + marginX)
  let bottom = min(height, maxY + marginBottom)

  return CGRect(x: x, y: y, width: right - x, height: bottom - y)
}

func subjectImage(from image: CGImage, mask: CGImage) throws -> CGImage {
  let ciImage = CIImage(cgImage: image)
  let ciMask = CIImage(cgImage: mask).applyingFilter("CIMaskToAlpha")
  let clear = CIImage(color: .clear).cropped(to: ciImage.extent)

  let filter = CIFilter.blendWithAlphaMask()
  filter.inputImage = ciImage
  filter.backgroundImage = clear
  filter.maskImage = ciMask

  let context = CIContext(options: [.useSoftwareRenderer: false])
  guard
    let output = filter.outputImage,
    let rendered = context.createCGImage(output, from: ciImage.extent)
  else {
    throw PortraitError.cannotRenderImage
  }
  return rendered
}

func placeOnCanvas(_ subject: CGImage, crop: CGRect, options: Options) throws -> CGImage {
  guard let cropped = subject.cropping(to: crop) else {
    throw PortraitError.cannotRenderImage
  }

  let canvasWidth = options.canvasWidth
  let canvasHeight = options.canvasHeight
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

  guard let context = CGContext(
    data: nil,
    width: canvasWidth,
    height: canvasHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo
  ) else {
    throw PortraitError.cannotRenderImage
  }

  context.clear(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
  context.interpolationQuality = .high

  let targetWidth = Double(canvasWidth) * 0.98
  let targetHeight = Double(canvasHeight) * 0.97
  let scale = min(targetWidth / Double(cropped.width), targetHeight / Double(cropped.height))
  let drawWidth = Double(cropped.width) * scale
  let drawHeight = Double(cropped.height) * scale
  let drawX = (Double(canvasWidth) - drawWidth) / 2.0
  let drawY = Double(canvasHeight) - drawHeight

  context.draw(
    cropped,
    in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
  )

  guard let output = context.makeImage() else {
    throw PortraitError.cannotRenderImage
  }
  return output
}

func writePNG(_ image: CGImage, to path: String) throws {
  let url = URL(fileURLWithPath: path)
  guard
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else {
    throw PortraitError.cannotWriteImage(path)
  }

  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else {
    throw PortraitError.cannotWriteImage(path)
  }
}

func parseOptions() throws -> Options {
  guard CommandLine.arguments.count == 3 else {
    throw PortraitError.badArguments
  }
  return Options(inputPath: CommandLine.arguments[1], outputPath: CommandLine.arguments[2])
}

do {
  let options = try parseOptions()
  let image = try loadCGImage(from: options.inputPath)
  let mask = try foregroundMask(for: image)
  let subject = try subjectImage(from: image, mask: mask)
  let crop = boundingBox(in: mask)
  let output = try placeOnCanvas(subject, crop: crop, options: options)
  try writePNG(output, to: options.outputPath)
} catch let error as PortraitError {
  fputs("\(error.description)\n", stderr)
  exit(1)
} catch {
  fputs("\(error)\n", stderr)
  exit(1)
}
