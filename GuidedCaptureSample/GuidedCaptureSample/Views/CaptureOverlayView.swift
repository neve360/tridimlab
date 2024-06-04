/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Full-screen overlay UI with buttons to control the capture, intended to placed in a `ZStack` over the `ObjectCaptureView`.
*/

import AVFoundation
import Foundation
import RealityKit
import SwiftUI
import os
import UniformTypeIdentifiers

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "CaptureOverlayView")
internal let reducedTutorialAnimationTime: TimeInterval = 2.0

struct CaptureOverlayView: View {
    @EnvironmentObject var appModel: AppDataModel
    var session: ObjectCaptureSession

    @State private var showCaptureModeGuidance: Bool = false
    @State private var hasDetectionFailed = false
    @State private var showTutorialView = false
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    var body: some View {
        ZStack {
            if showTutorialView, let url = appModel.tutorialURL {
                TutorialView(url: url, showTutorialView: $showTutorialView)
            } else {
                VStack(spacing: 20) {
                    TopOverlayButtons(session: session,
                                      capturingStarted: capturingStarted,
                                      showCaptureModeGuidance: showCaptureModeGuidance)

                    Spacer()

                    BoundingBoxGuidanceView(session: session, hasDetectionFailed: hasDetectionFailed)

                    BottomOverlayButtons(session: session,
                                         hasDetectionFailed: $hasDetectionFailed,
                                         showCaptureModeGuidance: $showCaptureModeGuidance,
                                         showTutorialView: $showTutorialView,
                                         capturingStarted: capturingStarted,
                                         rotationAngle: rotationAngle)
                }
                .padding()
                .padding(.horizontal, 15)
                .background {
                    VStack {
                        Spacer().frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 65 : 25)

                        FeedbackView(messageList: appModel.messageList)
                            .layoutPriority(1)
                    }
                    .rotationEffect(rotationAngle)
                }
                .task {
                    for await _ in NotificationCenter.default.notifications(named: UIDevice.orientationDidChangeNotification) {
                        withAnimation {
                            deviceOrientation = UIDevice.current.orientation
                        }
                    }
                }
            }
        }
        // When camera tracking isn't normal, display the AR coaching view and hide the overlay view.
        .opacity(session.cameraTracking == .normal && !session.isPaused ? 1.0 : 0.0 )
    }

    private var capturingStarted: Bool {
        switch session.state {
            case .initializing, .ready, .detecting:
                return false
            default:
                return true
        }
    }

    private var rotationAngle: Angle {
        switch deviceOrientation {
            case .landscapeLeft:
                return Angle(degrees: 90)
            case .landscapeRight:
                return Angle(degrees: -90)
            case .portraitUpsideDown:
                return Angle(degrees: 180)
            default:
                return Angle(degrees: 0)
        }
    }
}

private struct TutorialView: View {
    @EnvironmentObject var appModel: AppDataModel
    var url: URL
    @Binding var showTutorialView: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isVisible = false
    private let delay: TimeInterval = 0.3

    var body: some View {
        VStack {
            Spacer()
            TutorialVideoView(url: url, isInReviewSheet: false)
                .frame(maxHeight: horizontalSizeClass == .regular ? 350 : 280)
                .overlay(alignment: .bottom) {
                    if appModel.captureMode == .object {
                        Text(LocalizedString.tutorialText)
                            .font(.headline)
                            .padding(.bottom, appModel.captureMode == .object ? 16 : 0)
                            .foregroundStyle(.white)
                    }
                }
            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .background(Color.black.opacity(0.5))
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation {
                    isVisible = true
                }
            }
        }
        .task {
            let animationDuration = try? await AVURLAsset(url: url).load(.duration).seconds - reducedTutorialAnimationTime
            DispatchQueue.main.asyncAfter(deadline: .now() + (animationDuration ?? 0.0)) {
                withAnimation {
                    showTutorialView = false
                }
            }
        }
    }

    private struct LocalizedString {
        static let tutorialText = NSLocalizedString(
            "Move slowly around your object. (Object Capture, Orbit, Tutorial)",
            bundle: Bundle.main,
            value: "Move slowly around your object.",
            comment: "Guided feedback message to move slowly around object to start capturing."
        )
    }
}

@MainActor
private struct BoundingBoxGuidanceView: View {
    @EnvironmentObject var appModel: AppDataModel
    var session: ObjectCaptureSession
    var hasDetectionFailed: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack {
            if let guidanceText {
                Text(guidanceText)
                    .font(.callout)
                    .bold()
                    .foregroundColor(.white)
                    .transition(.opacity)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: horizontalSizeClass == .regular ? 400 : 360)
            }
        }
    }

    private var guidanceText: String? {
        if case .ready = session.state {
            switch appModel.captureMode {
                case .object:
                    if hasDetectionFailed {
                        return NSLocalizedString(
                            "Can‘t find your object. It should be larger than 3 in (8 cm) in each dimension.",
                            bundle: Bundle.main,
                            value: "Can‘t find your object. It should be larger than 3 in (8 cm) in each dimension.",
                            comment: "Feedback message when detection has failed.")
                    } else {
                        return NSLocalizedString(
                            "Move close and center the dot on your object, then tap Continue. (Object Capture, State)",
                            bundle: Bundle.main,
                            value: "Move close and center the dot on your object, then tap Continue.",
                            comment: "Feedback message to fill the camera feed with the object.")
                    }
                case .area:
                    return NSLocalizedString(
                        "Look at your subject (Object Capture, State).",
                        bundle: Bundle.main,
                        value: "Look at your subject.",
                        comment: "Feedback message to look at the subject in the area mode.")
                }
        } else if case .detecting = session.state {
            return NSLocalizedString(
                "Move around to ensure that the whole object is inside the box. Drag handles to manually resize. (Object Capture, State)",
                bundle: Bundle.main,
                value: "Move around to ensure that the whole object is inside the box. Drag handles to manually resize.",
                comment: "Feedback message to resize the box to the object.")
        } else {
            return nil
        }
    }
}
