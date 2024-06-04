/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A value type for holding the details about a particular shot file, for use as a model.
*/

import Combine
import Foundation
import SwiftUI
import UIKit

struct ShotFileInfo {
    let url: URL
    let id: UInt32

    init(url inURL: URL) throws {
        url = inURL
        id = try CaptureFolderManager.parseShotId(url: url)
    }
}

extension ShotFileInfo: Identifiable { }
