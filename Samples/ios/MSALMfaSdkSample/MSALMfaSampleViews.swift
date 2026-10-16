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
    @State private var path: [MSALMfaSampleRoute] = []
    @State private var challengeResponse: Task<Void, Never>?

    init()
    {
        self.init(model: MSALMfaSampleModel())
    }

    init(model: MSALMfaSampleModel)
    {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View
    {
        NavigationStack(path: $path)
        {
            VStack(spacing: 0)
            {
                Text("MOCK REGISTRATIONS - No real MFA")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding()
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
                    .accessibilityHint("Opens a simulated scanner. No camera is used.")
                    .accessibilityIdentifier("mfa.openScanner")
                }
                .padding()
            }
            .navigationTitle("Accounts")
            .modifier(MSALMfaSampleNavigationStyle())
            .onChange(of: path)
            { _, routes in
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
                    description: Text("Use the QR button to add a mock account. Accounts reset when the app closes.")
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
            Text("MOCK: Recording your response...")
        }
        else
        {
            switch model.challengeStatus
            {
            case .noPendingChallenge: Text("MOCK: No pending sign-in request.")
            case .approved: Text("MOCK: Approved locally. The number was ignored; no sign-in was authorized.")
            case .denied: Text("MOCK: Denied locally. No server was contacted.")
            case .invalidNumber: Text("Enter a whole number using digits only.")
            case .unexpectedResult: Text("The demo expected a matching mock result. No sign-in was authorized.")
            case nil: Text("Pull down to show a mock sign-in request.")
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
                Text(registration.source == .simulatedScan ? "MOCK - Simulated QR scan" : "MOCK - Manual entry")
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
final class MSALMfaSampleChallengeAlertController: UIViewController
{
    private let model: MSALMfaSampleModel
    private let onResponse: (UUID, Bool, String) -> Void
    private let contentController: UIHostingController<AnyView>
    let refreshControl = UIRefreshControl()
    let scrollView = UIScrollView()
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
        if refreshTask != nil
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
        guard refreshTask == nil, !isPresenting, !isDismissing else { return }
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
        let alert = UIAlertController(
            title: String(localized: "Are you trying to sign in?"),
            message: String(localized: "Demo account\ndemo@example.com\n\nEnter the number shown to sign in.\n\nMOCK ONLY - The number is ignored. No real sign-in."),
            preferredStyle: .alert
        )
        alert.view.tintColor = .systemBlue
        alert.view.accessibilityIdentifier = "mfa.challengeAlert"
        alert.addTextField
        { [weak self] field in
            field.placeholder = String(localized: "Enter number")
            field.keyboardType = .numberPad
            field.accessibilityIdentifier = "mfa.challengeNumber"
            field.addTarget(self, action: #selector(Self.numberChanged(_:)), for: .editingChanged)
        }
        alert.addAction(UIAlertAction(title: String(localized: "No, it's not me"), style: .destructive)
        { [weak self] _ in
            self?.onResponse(prompt.id, false, "")
        })
        let yes = UIAlertAction(title: String(localized: "Yes"), style: .default)
        { [weak self, weak alert] _ in
            self?.onResponse(prompt.id, true, alert?.textFields?.first?.text ?? "")
        }
        yes.isEnabled = false
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

    var body: some View
    {
        ScrollView
        {
            VStack(spacing: 24)
            {
                ZStack
                {
                    Rectangle().fill(.white.opacity(0.08))
                    MSALMfaSampleScanCorners()
                        .stroke(sampleBlue, lineWidth: 3)
                        .padding(16)
                    Image(systemName: "qrcode")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(.vertical, 24)
                .accessibilityHidden(true)

                Text("Your account provider will display a QR code")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                Text("SIMULATED SCANNER - No camera is active. This demo only creates mock registrations.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button
                {
                    guard operation == nil else { return }
                    operation = Task { @MainActor in
                        if await model.simulateScan()
                        {
                            path.removeAll()
                        }
                        operation = nil
                    }
                } label: {
                    Text(model.isRegistering ? "Adding mock account..." : "Simulate scan")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(model.isRegistering)
                .accessibilityIdentifier("mfa.simulateScan")

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
        .onDisappear
        {
            operation?.cancel()
            operation = nil
            model.cancelRegistration()
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
                Text("OTHER ACCOUNT")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                    .padding(.bottom, 8)

                VStack(spacing: 0)
                {
                    TextField("Account name", text: $accountName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .secret }
                        .accessibilityIdentifier("mfa.accountName")
                        .padding(16)
                    Divider().padding(.leading, 16)
                    SecureField("Secret key", text: $secret)
                        .focused($focusedField, equals: .secret)
                        .submitLabel(.done)
                        .onSubmit { finish() }
                        .accessibilityIdentifier("mfa.secretKey")
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
                    Text(model.isRegistering ? "Adding mock account..." : "Finish")
                        .font(.title3)
                        .foregroundStyle(canFinish ? Color.white : Color(uiColor: .secondaryLabel))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(canFinish ? sampleBlue : Color(uiColor: .systemGray4))
                }
                .disabled(!canFinish)
                .padding(.top, 36)
                .accessibilityIdentifier("mfa.finishManualEntry")

                Text("MOCK ONLY. Enter a synthetic name and key. The key is ignored and discarded; no key is validated or stored and no account is enrolled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
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
        case .missingName: return "Enter a synthetic account name."
        case .missingSecret: return "Enter a synthetic secret key."
        case .unexpectedResult: return "The demo expected a mock result. No account was added."
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
