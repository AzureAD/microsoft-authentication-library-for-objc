//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

import SwiftUI
import VisionKit

@MainActor
struct MSALMfaSampleCameraScanner: UIViewControllerRepresentable
{
    let isRunning: Bool
    let onCode: (String) -> Void
    let onError: () -> Void

    func makeCoordinator() -> Coordinator
    {
        Coordinator(onCode: onCode, onError: onError)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController
    {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context)
    {
        context.coordinator.isEnabled = isRunning
        guard context.coordinator.canScan else
        {
            controller.stopScanning()
            return
        }
        guard !controller.isScanning else { return }
        do
        {
            try controller.startScanning()
        }
        catch
        {
            context.coordinator.reportFailure()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator)
    {
        coordinator.invalidate()
        controller.stopScanning()
        controller.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate
    {
        var isEnabled = false
        private var hasDelivered = false
        private var hasFailed = false
        private var isInvalidated = false
        private let onCode: (String) -> Void
        private let onError: () -> Void

        var canScan: Bool
        {
            isEnabled && !hasDelivered && !hasFailed && !isInvalidated
        }

        init(onCode: @escaping (String) -> Void, onError: @escaping () -> Void)
        {
            self.onCode = onCode
            self.onError = onError
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem])
        {
            for item in addedItems
            {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue, receiveCode(value)
                {
                    dataScanner.stopScanning()
                    return
                }
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        )
        {
            reportFailure()
        }

        @discardableResult
        func receiveCode(_ code: String) -> Bool
        {
            guard canScan, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            hasDelivered = true
            onCode(code)
            return true
        }

        func reportFailure()
        {
            guard canScan else { return }
            hasFailed = true
            // Avoid publishing SwiftUI state from updateUIViewController's startScanning failure.
            DispatchQueue.main.async
            { [weak self] in
                guard let self, !self.isInvalidated else { return }
                self.onError()
            }
        }

        func invalidate()
        {
            isInvalidated = true
        }
    }
}
