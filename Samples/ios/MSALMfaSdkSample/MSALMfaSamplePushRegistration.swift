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

import Foundation
import Combine
import UIKit
import UserNotifications
import MSAL

@MainActor
final class MSALMfaSamplePushRegistration: ObservableObject
{
    struct Registration
    {
        let deviceToken: Data
        let environment: MSALNativeAuthMfaSdkAPNsEnvironment
    }

    enum Failure: Error, Equatable
    {
        case notificationsDenied
        case registrationFailed
        case missingDeviceToken
        case timedOut
        case invalidConfiguration
        case synchronizationFailed
    }

    @Published private(set) var backgroundFailure: Failure?
    private(set) var currentDeviceToken: Data?
    private var isRefreshing = false
    private var updateOperation: UUID?
    private var pushUpdate: Task<Result<Void, Error>, Never>?
    private var waiters: [UUID: CheckedContinuation<Data, Error>] = [:]
    private var timeoutTask: Task<Void, Never>?
    private let environment: @MainActor () throws -> MSALNativeAuthMfaSdkAPNsEnvironment
    private let requestAuthorization: @MainActor () async throws -> Bool
    private let registerForRemoteNotifications: @MainActor () -> Void
    private let waitForTimeout: @MainActor () async throws -> Void
    private let isAuthorized: @MainActor () async -> Bool
    private let updatePushRegistration: @MainActor (Data, MSALNativeAuthMfaSdkAPNsEnvironment) async throws -> Void

    init(
        environment: @escaping @MainActor () throws -> MSALNativeAuthMfaSdkAPNsEnvironment = {
            guard let value = Bundle.main.object(forInfoDictionaryKey: "MSALMfaAPNsEnvironment") as? String,
                  let environment = MSALNativeAuthMfaSdkAPNsEnvironment(rawValue: value) else
            {
                throw Failure.invalidConfiguration
            }
            return environment
        },
        requestAuthorization: @escaping @MainActor () async throws -> Bool = {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        },
        registerForRemoteNotifications: @escaping @MainActor () -> Void = {
            UIApplication.shared.registerForRemoteNotifications()
        },
        waitForTimeout: @escaping @MainActor () async throws -> Void = {
            try await Task.sleep(for: .seconds(30))
        },
        isAuthorized: @escaping @MainActor () async -> Bool = {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus
            {
            case .authorized, .provisional, .ephemeral: return true
            default: return false
            }
        },
        updatePushRegistration: @escaping @MainActor (Data, MSALNativeAuthMfaSdkAPNsEnvironment) async throws -> Void = {
            try await MSALNativeAuthMfaSdkManager().updatePushRegistration(deviceToken: $0, apnsEnvironment: $1)
        }
    )
    {
        self.environment = environment
        self.requestAuthorization = requestAuthorization
        self.registerForRemoteNotifications = registerForRemoteNotifications
        self.waitForTimeout = waitForTimeout
        self.isAuthorized = isAuthorized
        self.updatePushRegistration = updatePushRegistration
    }

    func refreshIfAuthorized() async
    {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        guard await isAuthorized(), !Task.isCancelled else { return }
        do
        {
            _ = try environment()
            // Ask Apple again even when a previous callback supplied a cached token.
            _ = try await acquireDeviceToken()
        }
        catch is CancellationError
        {
            return
        }
        catch
        {
            backgroundFailure = (error as? Failure) ?? .registrationFailed
        }
    }

    func register() async throws -> Registration
    {
        try Task.checkCancellation()
        let environment = try environment()
        let authorized: Bool
        do
        {
            authorized = try await requestAuthorization()
        }
        catch is CancellationError
        {
            throw CancellationError()
        }
        catch
        {
            throw Failure.registrationFailed
        }
        try Task.checkCancellation()
        guard authorized else { throw Failure.notificationsDenied }
        if let currentDeviceToken
        {
            didRegister(deviceToken: currentDeviceToken)
        }
        else
        {
            _ = try await acquireDeviceToken()
        }
        while let operation = updateOperation, let update = pushUpdate
        {
            let result = await update.value
            try Task.checkCancellation()
            guard updateOperation == operation else { continue }
            try result.get()
            guard let token = currentDeviceToken else { throw Failure.missingDeviceToken }
            return Registration(deviceToken: token, environment: environment)
        }
        try Task.checkCancellation()
        throw Failure.registrationFailed
    }

    @discardableResult
    func didRegister(deviceToken: Data) -> Task<Void, Never>?
    {
        let operation = UUID()
        updateOperation = operation
        guard !deviceToken.isEmpty else
        {
            pushUpdate = nil
            currentDeviceToken = nil
            backgroundFailure = .missingDeviceToken
            complete(.failure(Failure.missingDeviceToken))
            return nil
        }
        currentDeviceToken = deviceToken
        complete(.success(deviceToken))
        let task = Task { @MainActor () -> Result<Void, Error> in
            do
            {
                guard self.updateOperation == operation else { throw CancellationError() }
                let environment = try self.environment()
                try await self.updatePushRegistration(deviceToken, environment)
                if self.updateOperation == operation
                {
                    self.backgroundFailure = nil
                }
                return .success(())
            }
            catch
            {
                let failure = (error as? Failure) ?? .synchronizationFailed
                if self.updateOperation == operation
                {
                    self.backgroundFailure = failure
                }
                return .failure(failure)
            }
        }
        pushUpdate = task
        return Task { _ = await task.value }
    }

    func didFailToRegister()
    {
        updateOperation = nil
        pushUpdate = nil
        currentDeviceToken = nil
        backgroundFailure = .registrationFailed
        complete(.failure(Failure.registrationFailed))
    }

    private func acquireDeviceToken() async throws -> Data
    {
        let id = UUID()
        return try await withTaskCancellationHandler
        {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation
            { continuation in
                waiters[id] = continuation
                guard waiters.count == 1 else { return }
                timeoutTask = Task { @MainActor [weak self, waitForTimeout] in
                    do
                    {
                        try await waitForTimeout()
                        try Task.checkCancellation()
                        self?.complete(.failure(Failure.timedOut))
                    }
                    catch is CancellationError
                    {
                        return
                    }
                    catch
                    {
                        guard !Task.isCancelled else { return }
                        self?.complete(.failure(Failure.registrationFailed))
                    }
                }
                registerForRemoteNotifications()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelWaiter(id)
            }
        }
    }

    private func cancelWaiter(_ id: UUID)
    {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
        if waiters.isEmpty
        {
            timeoutTask?.cancel()
            timeoutTask = nil
        }
    }

    private func complete(_ result: Result<Data, Error>)
    {
        let continuations = Array(waiters.values)
        waiters.removeAll()
        timeoutTask?.cancel()
        timeoutTask = nil
        for continuation in continuations
        {
            continuation.resume(with: result)
        }
    }
}
