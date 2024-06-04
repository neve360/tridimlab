/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Top-level View for the Object Capture portion where shots are taken.
*/

/**
 *  \file   CapturePrimaryView.swift
 *
 *   This top-level view handles showing the
 *   info panel and other items during this capture, as well as toggling
 *   the overlay display correctly. Invariant: the `ObjectCaptureSession`
 *   state should exist for the lifetime of this view; when finished,
 *   capture and leave this view to reclaim free resources
 *   for the reconstruction phase.
 *
 *  \author Video Engineering
 *
 *  Copyright (c) 2022 Apple Inc. All rights reserved.
 */

import Foundation
import RealityKit
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "CapturePrimaryView")

struct CapturePrimaryView: View {
    @EnvironmentObject var appModel: AppDataModel
    var session: ObjectCaptureSession

    var body: some View {
        ZStack {
            ObjectCaptureView(session: session,
                              cameraFeedOverlay: { GradientBackground() })
            .hideObjectReticle(appModel.captureMode == .area)
            .blur(radius: appModel.showOverlaySheets ? 45 : 0)
            .transition(.opacity)

            CaptureOverlayView(session: session)
        }
        .onAppear(perform: {
            UIApplication.shared.isIdleTimerDisabled = true
        })
        .id(session.id)
    }
}

private struct GradientBackground: View {
    private let gradient = LinearGradient(
        colors: [.black.opacity(0.4), .clear],
        startPoint: .top,
        endPoint: .bottom
    )
    private let frameHeight: CGFloat = 300

    var body: some View {
        VStack {
            gradient
                .frame(height: frameHeight)

            Spacer()

            gradient
                .rotation3DEffect(Angle(degrees: 180), axis: (x: 1, y: 0, z: 0))
                .frame(height: frameHeight)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

