/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A class to support the creation, listing and filename support of a
 capture folder in the Documents directory which will contain two
 subdirs --- one for images and one for reconstruction checkpoint.
*/

import Dispatch
import Foundation
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem,
                            category: "CaptureFolderManager")

class CaptureFolderManager: ObservableObject {
    enum Error: Swift.Error {
        case notFileUrl
        case creationFailed
        case alreadyExists
        case invalidShotUrl
    }

    // The app's documents folder that includes captures from all sessions.
    let appDocumentsFolder: URL = URL.documentsDirectory

    // Top-level capture directory that will contain an "Images" and "Checkpoint" subdir.
    // Automatically created at init() with timestamp.
    let captureFolder: URL

    // Sub-dir of captureFolder for images
    let imagesFolder: URL

    // Sub-dir of captureFolder for checkpoint
    let checkpointFolder: URL

    // Subdir to output model files.
    let modelsFolder: URL

    static let imagesFolderName = "Images/"

    @Published var shots: [ShotFileInfo] = []

    init() throws {
        guard let newFolder = CaptureFolderManager.createNewCaptureDirectory() else {
            throw Error.creationFailed
        }
        captureFolder = newFolder

        // Create the subdirs
        imagesFolder = newFolder.appendingPathComponent(Self.imagesFolderName)
        try CaptureFolderManager.createDirectoryRecursively(imagesFolder)

        checkpointFolder = newFolder.appendingPathComponent("Checkpoint/")
        try CaptureFolderManager.createDirectoryRecursively(checkpointFolder)

        modelsFolder = newFolder.appendingPathComponent("Models/")
        try CaptureFolderManager.createDirectoryRecursively(modelsFolder)
    }

    func loadShots() async throws {
        logger.debug("Loading shots (async)...")

        // We don't load straight into the published var since we don't want to have incomplete
        // state displayed, and then have them sort while visible. Have the update be atomic.
        var newShots: [ShotFileInfo] = []

        let imgUrls = try FileManager.default
            .contentsOfDirectory(at: imagesFolder,
                                 includingPropertiesForKeys: [],
                                 options: [.skipsHiddenFiles])
            .filter { $0.isFileURL
                && $0.lastPathComponent.hasSuffix(CaptureFolderManager.heicImageExtension)
            }

        for imgUrl in imgUrls {
            do {
                newShots.append(try ShotFileInfo(url: imgUrl))
            } catch {
                logger.error("Can't get shotId from url: \"\(imgUrl)\" error=\(String(describing: error))")
                continue
            }
        }

        // Sort and then make the final replacement of the published array.
        newShots.sort(by: { $0.id < $1.id })
        shots = newShots
    }

    /// Pulls the image id out of a previously created `photoIdString`.
    /// Throws: if `photoString` is not valid and an id cannot be extracted.
    /// Invariant: For all foo that are photoIdString's:  photoIdString(for: extractId(from: foo)) == foo
    static func parseShotId(url: URL) throws -> UInt32 {
        let photoBasename = url.deletingPathExtension().lastPathComponent
        logger.debug("photoBasename = \(photoBasename)")
        guard let endOfPrefix = photoBasename.lastIndex(of: "_") else {
            logger.warning("Can't get endOfPrefix!")
            throw Error.invalidShotUrl
        }
        let imgPrefix = photoBasename[...endOfPrefix]
        guard imgPrefix == imageStringPrefix else {
            logger.warning("Prefix doesn't match!")
            throw Error.invalidShotUrl
        }
        let idString = photoBasename[photoBasename.index(after: endOfPrefix)...]
        guard let id = UInt32(idString) else {
            logger.warning("Can't convert idString=\"\(idString)\" to uint32!")
            throw Error.invalidShotUrl
        }
        return id
     }

    /// The basename for file with the given `id`.
    static func imageIdString(for id: UInt32) -> String {
        return String(format: "%@%04d", imageStringPrefix, id)
    }

    /// Returns the file URL for the HEIC image for shot `id` in the given `outputDir`.
    static func heicImageUrl(in outputDir: URL, id: UInt32) -> URL {
        return outputDir
            .appendingPathComponent(imageIdString(for: id))
            .appendingPathExtension(heicImageExtension)
    }

    /// Creates a new capture directory based on the current timestamp in the top level Documents
    /// folder.  Else returns nil on failure.
    /// Will contain Images and Checkpoint subdirs.
    ///
    /// - Returns: the created folder'd file URL, else nil on error.
    static func createNewCaptureDirectory() -> URL? {
        // We have set the Info.plist to allow sharing so the app documents dir will be visible
        // from the Files app for view, delete, and share with AirDrop, Mail, iCloud, etc to move
        // the folder to the engine macOS platform.
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let newCaptureDir = URL.documentsDirectory
            .appendingPathComponent(timestamp, isDirectory: true)

        logger.log("Creating capture path: \"\(String(describing: newCaptureDir))\"")
        let capturePath = newCaptureDir.path
        do {
            try FileManager.default.createDirectory(atPath: capturePath,
                                                    withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create capturepath=\"\(capturePath)\" error=\(String(describing: error))")
            return nil
        }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: capturePath, isDirectory: &isDir)
        guard exists && isDir.boolValue else {
            return nil
        }

        return newCaptureDir
    }

    // - MARK: Private interface below.

    // Creates all path components until it exists, else throws.
    // Throws if the file aready exists as well.
    private static func createDirectoryRecursively(_ outputDir: URL) throws {
        guard outputDir.isFileURL else {
            throw CaptureFolderManager.Error.notFileUrl
        }
        let expandedPath = outputDir.path
        var isDirectory: ObjCBool = false

        guard !FileManager.default.fileExists(atPath: outputDir.path, isDirectory: &isDirectory) else {
            logger.error("File already exists at \(expandedPath, privacy: .private)")
            throw CaptureFolderManager.Error.alreadyExists
        }

        logger.log("Creating dir recursively: \"\(expandedPath, privacy: .private)\"")
        try FileManager.default.createDirectory(atPath: expandedPath,
                               withIntermediateDirectories: true)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDir) && isDir.boolValue else {
            logger.error("Dir \"\(expandedPath, privacy: .private)\" doesn't exist after creation!")
            throw CaptureFolderManager.Error.creationFailed
        }
        logger.log("... success creating dir.")
    }

    // What is appended in front of the capture id to get a file basename.
    private static let imageStringPrefix = "IMG_"
    private static let heicImageExtension = "HEIC"
}
