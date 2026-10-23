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
import UIKit
import AVFoundation
import VisionKit
import MSAL

private let sampleBlue = Color(red: 0, green: 0.47, blue: 0.83)

private enum MSALMfaSampleRoute: Hashable
{
    case scanner
    case manualEntry
}

@MainActor
struct MSALMfaSampleAccountsView: View
{
    @StateObject private var model: MSALMfaSampleModel
    @ObservedObject private var pushRegistration: MSALMfaSamplePushRegistration
    @State private var path: [MSALMfaSampleRoute] = []
    @State private var challengeResponse: Task<Void, Never>?

    init(sdk: MSALNativeAuthMFAManager, pushRegistration: MSALMfaSamplePushRegistration)
    {
        self.init(
            model: MSALMfaSampleModel(sdk: sdk, registerForPush: pushRegistration.register),
            pushRegistration: pushRegistration
        )
    }

    init(model: MSALMfaSampleModel, pushRegistration: MSALMfaSamplePushRegistration? = nil)
    {
        _model = StateObject(wrappedValue: model)
        self.pushRegistration = pushRegistration ?? MSALMfaSamplePushRegistration()
    }

    var body: some View
    {
        NavigationStack(path: $path)
        {
            VStack(spacing: 0)
            {
                if let failure = model.serviceFailure
                {
                    Text(failure).font(.footnote).padding()
                }
                if let failure = pushRegistration.backgroundFailure
                {
                    MSALMfaSampleErrorView(error: .pushRegistration(failure))
                        .padding()
                        .accessibilityIdentifier("mfa.pushRegistrationError")
                }
                MSALMfaSampleAccountsContent(model: model, content: AnyView(accountsContent))
                { id, approve, number in
                    challengeResponse = model.respondToChallenge(id: id, approve: approve, number: number)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom)
            {
                HStack
                {
                    Spacer()
                    Button
                    {
                        cancelChallenge()
                        path.append(.scanner)
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(sampleBlue, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }
                    .accessibilityLabel("Scan QR code")
                    .accessibilityHint("Opens the camera to scan an account QR code.")
                    .accessibilityIdentifier("mfa.openScanner")
                }
                .padding()
            }
            .navigationTitle("Accounts")
            .modifier(MSALMfaSampleNavigationStyle())
            .onChange(of: path)
            { _, routes in
                model.setAccountsVisible(routes.isEmpty)
                if !routes.isEmpty
                {
                    cancelChallenge()
                }
            }
            .navigationDestination(for: MSALMfaSampleRoute.self)
            { route in
                switch route
                {
                case .scanner:
                    MSALMfaSampleScannerView(model: model, path: $path)
                case .manualEntry:
                    MSALMfaSampleManualEntryView(model: model, path: $path)
                }
            }
        }
        .tint(.white)
    }

    private var accountsContent: some View
    {
        VStack(spacing: 0)
        {
            if model.registrations.isEmpty
            {
                ContentUnavailableView(
                    "No registrations",
                    systemImage: "person.crop.rectangle",
                    description: Text("Use the QR button to add an account.")
                )
                .accessibilityIdentifier("mfa.emptyState")
            }
            else
            {
                VStack(spacing: 0)
                {
                    ForEach(model.registrations)
                    { registration in
                        registrationRow(registration)
                        Divider().padding(.leading, 16)
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
            }
            challengeStatus
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .accessibilityIdentifier("mfa.challengeStatus")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var challengeStatus: some View
    {
        if model.isRespondingToChallenge
        {
            Text("Sending your response...")
        }
        else
        {
            switch model.challengeStatus
            {
            case .noPendingChallenge: Text("No pending sign-in request.")
            case .approved: Text("Sign-in request approved.")
            case .denied: Text("Sign-in request denied.")
            case .invalidNumber: Text("Enter a whole number using digits only.")
            case .requestFailed: Text("Unable to complete the request. Pull down to try again.")
            case .unexpectedResult: Text("Unable to confirm your decision. Pull down to try again.")
            case nil: Text("Pull down to check for sign-in requests.")
            }
        }
    }

    private func cancelChallenge()
    {
        challengeResponse?.cancel()
        challengeResponse = nil
        model.cancelChallengeFlow()
    }

    private func registrationRow(_ registration: MSALMfaSampleRegistration) -> some View
    {
        HStack(spacing: 16)
        {
            Image(systemName: "person.crop.rectangle")
                .font(.title)
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
                .background(Color(uiColor: .systemGray5), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6)
            {
                Text(verbatim: registration.name)
                    .font(.title3)
                Text(registration.source == .qrCode ? "QR code" : "Manual entry")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mfa.registrationRow")
    }
}

@MainActor
private struct MSALMfaSampleAccountsContent: UIViewControllerRepresentable
{
    @ObservedObject var model: MSALMfaSampleModel
    let content: AnyView
    let onResponse: (UUID, Bool, String) -> Void

    func makeUIViewController(context: Context) -> MSALMfaSampleChallengeAlertController
    {
        MSALMfaSampleChallengeAlertController(model: model, content: content, onResponse: onResponse)
    }

    func updateUIViewController(_ controller: MSALMfaSampleChallengeAlertController, context: Context)
    {
        controller.updateContent(content)
        controller.synchronizePresentation()
    }

    static func dismantleUIViewController(_ controller: MSALMfaSampleChallengeAlertController, coordinator: ())
    {
        controller.cancelRefresh()
    }
}

@MainActor
final class MSALMfaSampleChallengeAlertController: UIViewController, UIScrollViewDelegate
{
    private let model: MSALMfaSampleModel
    private let onResponse: (UUID, Bool, String) -> Void
    private let contentController: UIHostingController<AnyView>
    let refreshControl = UIRefreshControl()
    let scrollView = UIScrollView()
    private var isDraggingAccounts = false
    private(set) var isRefreshPending = false
    private var refreshTask: Task<Void, Never>?
    private var alert: UIAlertController?
    private var displayedPromptID: UUID?
    private var yesAction: UIAlertAction?
    private var isPresenting = false
    private var isDismissing = false

    init(model: MSALMfaSampleModel, content: AnyView, onResponse: @escaping (UUID, Bool, String) -> Void)
    {
        self.model = model
        self.onResponse = onResponse
        contentController = UIHostingController(rootView: content)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder)
    {
        fatalError("Use init(model:content:onResponse:)")
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        // SwiftUI already lays out Accounts inside the navigation and bottom safe areas.
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshAccounts), for: .valueChanged)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        addChild(contentController)
        contentController.sizingOptions = .intrinsicContentSize
        contentController.view.backgroundColor = .clear
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentController.view)
        contentController.didMove(toParent: self)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentController.view.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    func updateContent(_ content: AnyView)
    {
        contentController.rootView = content
    }

    @objc private func refreshAccounts()
    {
        guard refreshTask == nil else { return }
        refreshControl.alpha = 1
        isRefreshPending = true
        startPendingRefresh()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    {
        isDraggingAccounts = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
    {
        isDraggingAccounts = false
        startPendingRefresh()
        synchronizePresentation()
    }

    private func startPendingRefresh()
    {
        guard isRefreshPending, !isDraggingAccounts, refreshTask == nil else { return }
        isRefreshPending = false
        refreshTask = Task { @MainActor in
            await self.model.refreshChallengeFromAccounts()
            guard !Task.isCancelled else { return }
            // End the owned indicator before presenting UIKit's modal alert.
            self.endRefreshing()
            self.refreshTask = nil
            self.synchronizePresentation()
        }
    }

    func cancelRefresh()
    {
        isRefreshPending = false
        isDraggingAccounts = false
        refreshTask?.cancel()
        refreshTask = nil
        endRefreshing()
        model.cancelChallengeFlow()
    }

    private func endRefreshing()
    {
        refreshControl.alpha = 0
        UIView.performWithoutAnimation
        {
            refreshControl.endRefreshing()
            scrollView.layoutIfNeeded()
            if scrollView.contentOffset.y < 0
            {
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0), animated: false)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        if isRefreshPending || refreshTask != nil
        {
            cancelRefresh()
        }
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        synchronizePresentation()
    }

    func synchronizePresentation()
    {
        guard !isDraggingAccounts, !isRefreshPending, refreshTask == nil, !isPresenting, !isDismissing else { return }
        if let alert, displayedPromptID != model.challengePrompt?.id
        {
            alert.textFields?.first?.text = ""
            isDismissing = true
            let completion: () -> Void =
            { [weak self] in
                self?.alert = nil
                self?.yesAction = nil
                self?.displayedPromptID = nil
                self?.isDismissing = false
                self?.synchronizePresentation()
            }
            if alert.isBeingDismissed, let transition = alert.transitionCoordinator
            {
                transition.animate(alongsideTransition: nil) { _ in completion() }
            }
            else
            {
                alert.dismiss(animated: true, completion: completion)
            }
            return
        }
        guard alert == nil, viewIfLoaded?.window != nil, let prompt = model.challengePrompt else { return }
        endRefreshing()
        let instructions = prompt.session.requiresNumberMatching
            ? String(localized: "Enter the number shown to sign in.")
            : String(localized: "Approve only if you started this sign-in.")
        let alert = UIAlertController(
            title: String(localized: "Are you trying to sign in?"),
            message: "\(prompt.session.accountName)\n\(prompt.session.username)\n\n\(instructions)",
            preferredStyle: .alert
        )
        alert.view.tintColor = .systemBlue
        alert.view.accessibilityIdentifier = "mfa.challengeAlert"
        if prompt.session.requiresNumberMatching
        {
            alert.addTextField
            { [weak self] field in
                field.placeholder = String(localized: "Enter number")
                field.keyboardType = .numberPad
                field.accessibilityIdentifier = "mfa.challengeNumber"
                field.addTarget(self, action: #selector(Self.numberChanged(_:)), for: .editingChanged)
            }
        }
        alert.addAction(UIAlertAction(title: String(localized: "No, it's not me"), style: .destructive)
        { [weak self] _ in
            self?.onResponse(prompt.id, false, "")
        })
        let yes = UIAlertAction(title: String(localized: "Yes"), style: .default)
        { [weak self, weak alert] _ in
            self?.onResponse(prompt.id, true, alert?.textFields?.first?.text ?? "")
        }
        yes.isEnabled = !prompt.session.requiresNumberMatching
        alert.addAction(yes)
        self.alert = alert
        yesAction = yes
        displayedPromptID = prompt.id
        isPresenting = true
        present(alert, animated: true)
        { [weak self] in
            self?.isPresenting = false
            self?.synchronizePresentation()
        }
    }

    @objc private func numberChanged(_ field: UITextField)
    {
        yesAction?.isEnabled = MSALMfaSampleModel.isValidChallengeNumber(field.text ?? "")
    }

}

@MainActor
private struct MSALMfaSampleScannerView: View
{
    @ObservedObject var model: MSALMfaSampleModel
    @Binding var path: [MSALMfaSampleRoute]
    @State private var operation: Task<Void, Never>?
    @State private var cameraAuthorized = false
    @State private var cameraError: String?
    @State private var isVisible = false
    @State private var hasScannedCode = false
    @State private var scanID = UUID()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View
    {
        ScrollView
        {
            VStack(spacing: 24)
            {
                ZStack
                {
                    Rectangle().fill(.white.opacity(0.08))
                    if cameraAuthorized, isVisible, scenePhase == .active
                    {
                        MSALMfaSampleCameraScanner(
                            isRunning: !hasScannedCode && !model.isRegistering,
                            onCode: register,
                            onError: {
                                cameraError = String(localized: "The camera could not scan. Try again or enter the account details manually.")
                            }
                        )
                        .id(scanID)
                    }
                    MSALMfaSampleScanCorners()
                        .stroke(sampleBlue, lineWidth: 3)
                        .padding(16)
                        .allowsHitTesting(false)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(.vertical, 24)
                .clipped()
                .accessibilityLabel("QR code camera")

                Text("Your account provider will display a QR code")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                if let cameraError
                {
                    Text(verbatim: cameraError)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("mfa.cameraError")
                }
                if cameraError != nil || model.validationError == .pushRegistration(.notificationsDenied)
                {
                    Button("Open Settings")
                    {
                        if let url = URL(string: UIApplication.openSettingsURLString)
                        {
                            openURL(url)
                        }
                    }
                }
                if model.isRegistering
                {
                    ProgressView("Adding account...")
                        .tint(.white)
                }
                else if hasScannedCode || cameraError != nil
                {
                    Button("Scan again")
                    {
                        model.cancelRegistration()
                        hasScannedCode = false
                        scanID = UUID()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("mfa.retryScan")
                }

                NavigationLink(value: MSALMfaSampleRoute.manualEntry)
                {
                    Text("Enter code manually")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(sampleBlue, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(model.isRegistering)
                .accessibilityIdentifier("mfa.openManualEntry")
                MSALMfaSampleErrorView(error: model.validationError)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .background(Color(white: 0.08))
        .navigationTitle("Scan QR code")
        .modifier(MSALMfaSampleNavigationStyle())
        .onAppear { isVisible = true }
        .task(id: "\(scanID)-\(scenePhase)")
        {
            guard scenePhase == .active else { return }
            await authorizeCamera()
        }
        .onDisappear
        {
            isVisible = false
            operation?.cancel()
            operation = nil
            model.cancelRegistration()
        }
    }

    private func authorizeCamera() async
    {
        cameraError = nil
        guard DataScannerViewController.isSupported else
        {
            cameraAuthorized = false
            cameraError = String(localized: "Camera scanning is unavailable on this device. Enter the account details manually.")
            return
        }
        var authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
        {
            authorized = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard !Task.isCancelled else { return }
        cameraAuthorized = authorized && DataScannerViewController.isAvailable
        if !cameraAuthorized
        {
            cameraError = String(localized: "Camera access is unavailable. Allow camera access in Settings or enter the account details manually.")
        }
    }

    private func register(_ qrCode: String)
    {
        guard operation == nil, !hasScannedCode, isVisible, scenePhase == .active else { return }
        hasScannedCode = true
        operation = Task { @MainActor in
            if await model.registerQRCode(qrCode)
            {
                path.removeAll()
            }
            operation = nil
        }
    }
}

@MainActor
private struct MSALMfaSampleManualEntryView: View
{
    @ObservedObject var model: MSALMfaSampleModel
    @Binding var path: [MSALMfaSampleRoute]
    @State private var accountName = ""
    @State private var secret = ""
    @State private var operation: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable
    {
        case name
        case secret
    }

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 0)
            {
                Text("WORK OR SCHOOL ACCOUNT")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                    .padding(.bottom, 8)

                VStack(spacing: 0)
                {
                    TextField("Activation URL", text: $accountName)
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .secret }
                        .accessibilityIdentifier("mfa.activationURL")
                        .padding(16)
                    Divider().padding(.leading, 16)
                    SecureField("Activation code", text: $secret)
                        .focused($focusedField, equals: .secret)
                        .submitLabel(.done)
                        .onSubmit { finish() }
                        .accessibilityIdentifier("mfa.activationCode")
                        .padding(16)
                }
                .font(.title3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(sampleBlue)
                .background(Color(uiColor: .systemBackground))
                .disabled(model.isRegistering)

                Button(action: finish)
                {
                    Text(model.isRegistering ? "Adding account..." : "Finish")
                        .font(.title3)
                        .foregroundStyle(canFinish ? Color.white : Color(uiColor: .secondaryLabel))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(canFinish ? sampleBlue : Color(uiColor: .systemGray4))
                }
                .disabled(!canFinish)
                .padding(.top, 36)
                .accessibilityIdentifier("mfa.finishManualEntry")

                MSALMfaSampleErrorView(error: model.validationError)
                    .padding(.horizontal, 16)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Add account")
        .modifier(MSALMfaSampleNavigationStyle())
        .onDisappear
        {
            operation?.cancel()
            operation = nil
            model.cancelRegistration()
            secret = ""
            accountName = ""
        }
    }

    private var canFinish: Bool
    {
        operation == nil && !model.isRegistering && MSALMfaSampleModel.canFinish(name: accountName, secret: secret)
    }

    private func finish()
    {
        guard canFinish else { return }
        focusedField = nil
        let enteredName = accountName
        let enteredSecret = secret
        secret = ""
        operation = Task { @MainActor in
            if await model.finishManualEntry(name: enteredName, secret: enteredSecret)
            {
                path.removeAll()
            }
            operation = nil
        }
    }
}

private struct MSALMfaSampleNavigationStyle: ViewModifier
{
    func body(content: Content) -> some View
    {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(sampleBlue, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct MSALMfaSampleErrorView: View
{
    let error: MSALMfaSampleModel.ValidationError?

    var body: some View
    {
        if let error
        {
            Text(message(for: error))
                .font(.footnote)
                .accessibilityIdentifier("mfa.registrationError")
        }
    }

    private func message(for error: MSALMfaSampleModel.ValidationError) -> LocalizedStringKey
    {
        switch error
        {
        case .missingName: return "Enter the activation URL shown on the enrollment page."
        case .missingSecret: return "Enter the activation code shown on the enrollment page."
        case .missingQRCode: return "Scan an account QR code."
        case .registrationFailed: return "Unable to add the account. Please try again."
        case .pushRegistration(let failure):
            switch failure
            {
            case .notificationsDenied: return "Enable notifications in Settings to add this account."
            case .timedOut: return "Registration for push notifications timed out. Check your connection and try again."
            case .invalidConfiguration: return "The app's APNs environment is not configured. Check the signing and build settings."
            case .synchronizationFailed:
                return "Unable to update push notifications for your accounts. Try returning to the app when your connection is available."
            case .registrationFailed, .missingDeviceToken:
                return "Unable to register for push notifications. Check your connection and the app's Push Notifications capability, then try again."
            }
        case .unexpectedResult: return "The SDK returned an incomplete registration. No account was added."
        }
    }
}

private struct MSALMfaSampleScanCorners: Shape
{
    func path(in rect: CGRect) -> Path
    {
        let length = min(rect.width, rect.height) * 0.16
        return Path
        { path in
            for (x, y, dx, dy) in [
                (rect.minX, rect.minY, length, length),
                (rect.maxX, rect.minY, -length, length),
                (rect.minX, rect.maxY, length, -length),
                (rect.maxX, rect.maxY, -length, -length)
            ]
            {
                path.move(to: CGPoint(x: x + dx, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + dy))
            }
        }
    }
}
