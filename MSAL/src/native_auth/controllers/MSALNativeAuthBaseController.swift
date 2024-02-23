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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

@_implementationOnly import MSAL_Private

class MSALNativeAuthBaseController {

    typealias TelemetryInfo = (event: MSIDTelemetryAPIEvent?, context: MSALNativeAuthRequestContext)
    let clientId: String

    init(
        clientId: String
    ) {
        self.clientId = clientId
    }

    func makeAndStartTelemetryEvent(
        id: MSALNativeAuthTelemetryApiId,
        context: MSIDRequestContext
    ) -> MSIDTelemetryAPIEvent? {
        let event = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: id,
            context: context
        )

        startTelemetryEvent(event, context: context)

        return event
    }

    func makeLocalTelemetryApiEvent(
        name: String,
        telemetryApiId: MSALNativeAuthTelemetryApiId,
        context: MSIDRequestContext
    ) -> MSIDTelemetryAPIEvent? {
        let event = MSIDTelemetryAPIEvent(
            name: name,
            context: context
        )

        event?.setApiId(String(telemetryApiId.rawValue))
        event?.setCorrelationId(context.correlationId())
        event?.setClientId(clientId)

        return event
    }

    func startTelemetryEvent(_ localEvent: MSIDTelemetryAPIEvent?, context: MSIDRequestContext) {
        guard let eventName = localEvent?.property(withName: MSID_TELEMETRY_KEY_EVENT_NAME) else {
            return MSALLogger.log(
                level: .error,
                context: context,
                format: "Telemetry event nil not expected"
            )
        }

        MSIDTelemetry.sharedInstance().startEvent(
            context.telemetryRequestId(),
            eventName: eventName
        )
    }

    func stopTelemetryEvent(_ telemetryInfo: TelemetryInfo, error: Error? = nil) {
        stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, error: error)
    }

    func stopTelemetryEvent(_ localEvent: MSIDTelemetryAPIEvent?, context: MSIDRequestContext, error: Error? = nil) {
        guard let event = localEvent else {
            return MSALLogger.log(
                level: .error,
                context: context,
                format: "Telemetry event nil not expected"
            )
        }

        if let error = error as? NSError {

            if let key = MSIDErrorConverter.defaultErrorConverter?.oauthErrorKey(),
                let oauthErrorCode = error.userInfo[key] as? String {
                event.setOauthErrorCode(oauthErrorCode)
            }

            event.setErrorCodeString(String(error.code))
            event.setErrorDomain(error.domain)
            event.setResultStatus(MSID_TELEMETRY_VALUE_FAILED)
            event.setIsSuccessfulStatus(MSID_TELEMETRY_VALUE_NO)
        } else {
            event.setResultStatus(MSID_TELEMETRY_VALUE_SUCCEEDED)
            event.setIsSuccessfulStatus(MSID_TELEMETRY_VALUE_YES)
        }

        MSIDTelemetry.sharedInstance().stopEvent(context.telemetryRequestId(), event: event)
        MSIDTelemetry.sharedInstance().flush(context.telemetryRequestId())
    }

    /// Stops a telemetry event.
    /// - Parameters:
    ///   - event: The local event to be stopped.
    ///   - context: The context object.
    ///   - delegateDispatcherResult: The result sent by the ``DelegateDispatcher`` that contains whether the developer
    ///                               has implemented the optional delegate or not.
    ///   - controllerError: Optional error set by the Controller when handles the response from API.
    ///                      (ex: SignUpController gets an .attributeValidationFailed. The controller will generate and error and send it here).
    func stopTelemetryEvent(
        _ event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegateDispatcherResult: Result<Void, MSALNativeAuthError>,
        controllerError: MSALNativeAuthError? = nil
    ) {
        switch delegateDispatcherResult {
        case .success:
            stopTelemetryEvent(event, context: context, error: controllerError)
        case .failure(let error):
            MSALLogger.log(level: .error, context: context, format: "Error \(error.errorDescription ?? "No error description")")
            stopTelemetryEvent(event, context: context, error: error)
        }
    }

    func complete<T>(
        _ telemetryEvent: MSIDTelemetryAPIEvent?,
        response: T? = nil,
        error: Error? = nil,
        context: MSIDRequestContext,
        completion: @escaping (T?, Error?) -> Void
    ) {
        stopTelemetryEvent(telemetryEvent, context: context, error: error)
        completion(response, error)
    }

    func performRequest<T: MSALNativeAuthResponseCorrelatable>(
        _ request: MSIDHttpRequest,
        context: MSALNativeAuthRequestContext
    ) async -> Result<T, Error> {
        return await withCheckedContinuation { continuation in
            request.send { [weak self] result, error in
                if let error = error {
                    // 5xx errors contain the server's returned correlation-id in userInfo.
                    if let correlationId = self?.extractCorrelationIdFromUserInfo((error as NSError).userInfo) {
                        context.setServerCorrelationId(UUID(uuidString: correlationId))

                    // 4xx errors are decoded producing an error that conforms to MSALNativeAuthResponseCorrelatable protocol.
                    } else if let errorWithCorrelationId = error as? MSALNativeAuthResponseCorrelatable {
                        context.setServerCorrelationId(errorWithCorrelationId.correlationId)

                    // If a 4xx error fails to decode, this error is returned from the error deserializer.
                    } else if case MSALNativeAuthInternalError.responseSerializationError(let correlationId) = error {
                        context.setServerCorrelationId(correlationId)
                    } else {
                        context.setServerCorrelationId(nil)
                        MSALLogger.log(level: .warning, context: context, format: "Error request - cannot decode error headers. Continuing")
                    }

                    continuation.resume(returning: .failure(error))
                } else if let response = result as? T {
                    context.setServerCorrelationId(response.correlationId)
                    continuation.resume(returning: .success(response))
                } else {
                    MSALLogger.log(level: .error, context: context, format: "Error request - Both result and error are nil")
                    continuation.resume(returning: .failure(MSALNativeAuthInternalError.invalidResponse))
                }
            }
        }
    }

    private func extractCorrelationIdFromUserInfo(_ userInfo: [String: Any]) -> String? {
        guard
            let headers = userInfo[MSIDHTTPHeadersKey] as? [String: Any],
            let correlationId = headers[MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE] as? String
        else {
            return nil
        }

        return correlationId
    }
}
