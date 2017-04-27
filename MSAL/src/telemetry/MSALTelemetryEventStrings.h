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

#pragma once

// Event names
extern NSString *const MSAL_TELEMETRY_EVENT_DEFAULT_EVENT;
extern NSString *const MSAL_TELEMETRY_EVENT_API_EVENT;
extern NSString *const MSAL_TELEMETRY_EVENT_TOKEN_GRANT;
extern NSString *const MSAL_TELEMETRY_EVENT_AUTHORITY_VALIDATION;
extern NSString *const MSAL_TELEMETRY_EVENT_ACQUIRE_TOKEN_SILENT;
extern NSString *const MSAL_TELEMETRY_EVENT_LAUNCH_BROKER;
extern NSString *const MSAL_TELEMETRY_EVENT_AUTHORIZATION_CODE;
extern NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP;
extern NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE;
extern NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE;
extern NSString *const MSAL_TELEMETRY_EVENT_UI_EVENT;
extern NSString *const MSAL_TELEMETRY_EVENT_HTTP_REQUEST;

extern NSString *const MSAL_TELEMETRY_KEY_AUTHORITY_TYPE;
extern NSString *const MSAL_TELEMETRY_KEY_AUTHORITY_VALIDATION_STATUS;
extern NSString *const MSAL_TELEMETRY_KEY_EXTENDED_EXPIRES_ON_SETTING;
extern NSString *const MSAL_TELEMETRY_KEY_UI_BEHAVIOR;
extern NSString *const MSAL_TELEMETRY_KEY_TENANT_ID;
extern NSString *const MSAL_TELEMETRY_KEY_USER_ID;
extern NSString *const MSAL_TELEMETRY_KEY_START_TIME;
extern NSString *const MSAL_TELEMETRY_KEY_END_TIME;
extern NSString *const MSAL_TELEMETRY_KEY_ELAPSED_TIME;
extern NSString *const MSAL_TELEMETRY_KEY_DEVICE_ID;
extern NSString *const MSAL_TELEMETRY_KEY_DEVICE_IP_ADDRESS;
extern NSString *const MSAL_TELEMETRY_KEY_APPLICATION_NAME;
extern NSString *const MSAL_TELEMETRY_KEY_APPLICATION_VERSION;
extern NSString *const MSAL_TELEMETRY_KEY_LOGIN_HINT;
extern NSString *const MSAL_TELEMETRY_KEY_NTLM_HANDLED;
extern NSString *const MSAL_TELEMETRY_KEY_UI_CANCELLED;
extern NSString *const MSAL_TELEMETRY_KEY_UI_EVENT_COUNT;
extern NSString *const MSAL_TELEMETRY_KEY_BROKER_APP;
extern NSString *const MSAL_TELEMETRY_KEY_BROKER_VERSION;
extern NSString *const MSAL_TELEMETRY_KEY_BROKER_PROTOCOL_VERSION;
extern NSString *const MSAL_TELEMETRY_KEY_BROKER_APP_USED;
extern NSString *const MSAL_TELEMETRY_KEY_CLIENT_ID;
extern NSString *const MSAL_TELEMETRY_KEY_HTTP_EVENT_COUNT;
extern NSString *const MSAL_TELEMETRY_KEY_CACHE_EVENT_COUNT;
extern NSString *const MSAL_TELEMETRY_KEY_API_ID;
extern NSString *const MSAL_TELEMETRY_KEY_TOKEN_TYPE;
extern NSString *const MSAL_TELEMETRY_KEY_TENANT_SCRUBBED_VALUE;
extern NSString *const MSAL_TELEMETRY_KEY_USER_CANCEL;
extern NSString *const MSAL_TELEMETRY_KEY_IS_SUCCESSFUL;
extern NSString *const MSAL_TELEMETRY_KEY_USER_CANCEL;
extern NSString *const MSAL_TELEMETRY_KEY_CORRELATION_ID;
extern NSString *const MSAL_TELEMETRY_KEY_IS_EXTENED_LIFE_TIME_TOKEN;
extern NSString *const MSAL_TELEMETRY_KEY_API_ERROR_CODE;
extern NSString *const MSAL_TELEMETRY_KEY_PROTOCOL_CODE;
extern NSString *const MSAL_TELEMETRY_KEY_ERROR_DESCRIPTION;
extern NSString *const MSAL_TELEMETRY_KEY_ERROR_DOMAIN;
extern NSString *const MSAL_TELEMETRY_KEY_HTTP_METHOD;
extern NSString *const MSAL_TELEMETRY_KEY_HTTP_PATH;
extern NSString *const MSAL_TELEMETRY_KEY_HTTP_REQUEST_ID_HEADER;
extern NSString *const MSAL_TELEMETRY_KEY_HTTP_RESPONSE_CODE;
extern NSString *const MSAL_TELEMETRY_KEY_OAUTH_ERROR_CODE;
extern NSString *const MSAL_TELEMETRY_KEY_HTTP_RESPONSE_METHOD;
extern NSString *const MSAL_TELEMETRY_KEY_REQUEST_QUERY_PARAMS;
extern NSString *const MSAL_TELEMETRY_KEY_USER_AGENT;
extern NSString *const MSAL_TELEMETRY_KEY_HTTP_ERROR_DOMAIN;
extern NSString *const MSAL_TELEMETRY_KEY_AUTHORITY;
extern NSString *const MSAL_TELEMETRY_KEY_GRANT_TYPE;
extern NSString *const MSAL_TELEMETRY_KEY_API_STATUS;
extern NSString *const MSAL_TELEMETRY_KEY_EVENT_NAME;
extern NSString *const MSAL_TELEMETRY_KEY_REQUEST_ID;

extern NSString *const MSAL_TELEMETRY_VALUE_YES;
extern NSString *const MSAL_TELEMETRY_VALUE_NO;
extern NSString *const MSAL_TELEMETRY_VALUE_ACCESS_TOKEN;
extern NSString *const MSAL_TELEMETRY_VALUE_REFRESH_TOKEN;
extern NSString *const MSAL_TELEMETRY_VALUE_MULTI_RESOURCE_REFRESH_TOKEN;
extern NSString *const MSAL_TELEMETRY_VALUE_FAMILY_REFRESH_TOKEN;
extern NSString *const MSAL_TELEMETRY_VALUE_ADFS_TOKEN;
extern NSString *const MSAL_TELEMETRY_VALUE_BY_CODE;
extern NSString *const MSAL_TELEMETRY_VALUE_BY_REFRESH_TOKEN;
extern NSString *const MSAL_TELEMETRY_VALUE_CANCELLED;
extern NSString *const MSAL_TELEMETRY_VALUE_UNKNOWN;
extern NSString *const MSAL_TELEMETRY_VALUE_AUTHORITY_AAD;
extern NSString *const MSAL_TELEMETRY_VALUE_AUTHORITY_ADFS;
extern NSString *const MSAL_TELEMETRY_VALUE_AUTHORITY_B2C;

