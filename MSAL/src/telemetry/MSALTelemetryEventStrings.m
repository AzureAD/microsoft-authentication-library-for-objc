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

#import "MSALTelemetryEventStrings.h"

// Telemetry event name
NSString *const MSAL_TELEMETRY_EVENT_DEFAULT_EVENT          = @"msal.default_event";
NSString *const MSAL_TELEMETRY_EVENT_API_EVENT              = @"msal.api_event";
NSString *const MSAL_TELEMETRY_EVENT_UI_EVENT               = @"msal.ui_event";
NSString *const MSAL_TELEMETRY_EVENT_HTTP_REQUEST           = @"msal.http_event";
NSString *const MSAL_TELEMETRY_EVENT_LAUNCH_BROKER          = @"msal.broker_event";
NSString *const MSAL_TELEMETRY_EVENT_TOKEN_GRANT            = @"msal.token_grant";
NSString *const MSAL_TELEMETRY_EVENT_AUTHORITY_VALIDATION   = @"msal.authority_validation";
NSString *const MSAL_TELEMETRY_EVENT_ACQUIRE_TOKEN_SILENT   = @"msal.acquire_token_silent_handler";
NSString *const MSAL_TELEMETRY_EVENT_AUTHORIZATION_CODE     = @"msal.authorization_code";
NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP     = @"msal.token_cache_lookup";
NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE      = @"msal.token_cache_write";
NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE     = @"msal.token_cache_delete";

// Telemetry property name, only alphabetic letters, dots, and underscores are allowed.
NSString *const MSAL_TELEMETRY_KEY_EVENT_NAME                   = @"msal.event_name";
NSString *const MSAL_TELEMETRY_KEY_AUTHORITY_TYPE               = @"msal.authority_type";
NSString *const MSAL_TELEMETRY_KEY_AUTHORITY_VALIDATION_STATUS  = @"msal.authority_validation_status";
NSString *const MSAL_TELEMETRY_KEY_EXTENDED_EXPIRES_ON_SETTING  = @"msal.extended_expires_on_setting";
NSString *const MSAL_TELEMETRY_KEY_PROMPT_BEHAVIOR              = @"msal.prompt_behavior";
NSString *const MSAL_TELEMETRY_KEY_RESULT_STATUS                = @"msal.status";
NSString *const MSAL_TELEMETRY_KEY_IDP                          = @"msal.idp";
NSString *const MSAL_TELEMETRY_KEY_TENANT_ID                    = @"msal.tenant_id";
NSString *const MSAL_TELEMETRY_KEY_USER_ID                      = @"msal.user_id";
NSString *const MSAL_TELEMETRY_KEY_START_TIME                   = @"msal.start_time";
NSString *const MSAL_TELEMETRY_KEY_END_TIME                     = @"msal.stop_time";
NSString *const MSAL_TELEMETRY_KEY_RESPONSE_TIME                = @"msal.response_time";
NSString *const MSAL_TELEMETRY_KEY_DEVICE_ID                    = @"msal.device_id";
NSString *const MSAL_TELEMETRY_KEY_DEVICE_IP_ADDRESS            = @"msal.device_ip_address";
NSString *const MSAL_TELEMETRY_KEY_APPLICATION_NAME             = @"msal.application_name";
NSString *const MSAL_TELEMETRY_KEY_APPLICATION_VERSION          = @"msal.application_version";
NSString *const MSAL_TELEMETRY_KEY_LOGIN_HINT                   = @"msal.login_hint";
NSString *const MSAL_TELEMETRY_KEY_NTLM_HANDLED                 = @"msal.ntlm";
NSString *const MSAL_TELEMETRY_KEY_UI_CANCELLED                 = @"msal.ui_cancelled";
NSString *const MSAL_TELEMETRY_KEY_UI_EVENT_COUNT               = @"msal.ui_event_count";
NSString *const MSAL_TELEMETRY_KEY_BROKER_APP                   = @"msal.broker_app";
NSString *const MSAL_TELEMETRY_KEY_BROKER_VERSION               = @"msal.broker_version";
NSString *const MSAL_TELEMETRY_KEY_BROKER_PROTOCOL_VERSION      = @"msal.broker_protocol_version";
NSString *const MSAL_TELEMETRY_KEY_BROKER_APP_USED              = @"msal.broker_app_used";
NSString *const MSAL_TELEMETRY_KEY_CLIENT_ID                    = @"msal.client_id";
NSString *const MSAL_TELEMETRY_KEY_HTTP_EVENT_COUNT             = @"msal.http_event_count";
NSString *const MSAL_TELEMETRY_KEY_CACHE_EVENT_COUNT            = @"msal.cache_event_count";
NSString *const MSAL_TELEMETRY_KEY_API_ID                       = @"msal.api_id";
NSString *const MSAL_TELEMETRY_KEY_TOKEN_TYPE                   = @"msal.token_type";
NSString *const MSAL_TELEMETRY_KEY_IS_RT                        = @"msal.is_rt";
NSString *const MSAL_TELEMETRY_KEY_IS_MRRT                      = @"msal.is_mrrt";
NSString *const MSAL_TELEMETRY_KEY_IS_FRT                       = @"msal.is_frt";
NSString *const MSAL_TELEMETRY_KEY_RT_STATUS                    = @"msal.token_rt_status";
NSString *const MSAL_TELEMETRY_KEY_MRRT_STATUS                  = @"msal.token_mrrt_status";
NSString *const MSAL_TELEMETRY_KEY_FRT_STATUS                   = @"msal.token_frt_status";
NSString *const MSAL_TELEMETRY_KEY_IS_SUCCESSFUL                = @"msal.is_successfull";
NSString *const MSAL_TELEMETRY_KEY_CORRELATION_ID               = @"msal.correlation_id";
NSString *const MSAL_TELEMETRY_KEY_IS_EXTENED_LIFE_TIME_TOKEN   = @"msal.is_extended_life_time_token";
NSString *const MSAL_TELEMETRY_KEY_API_ERROR_CODE               = @"msal.api_error_code";
NSString *const MSAL_TELEMETRY_KEY_PROTOCOL_CODE                = @"msal.error_protocol_code";
NSString *const MSAL_TELEMETRY_KEY_ERROR_DESCRIPTION            = @"msal.error_description";
NSString *const MSAL_TELEMETRY_KEY_ERROR_DOMAIN                 = @"msal.error_domain";
NSString *const MSAL_TELEMETRY_KEY_HTTP_METHOD                  = @"msal.method";
NSString *const MSAL_TELEMETRY_KEY_HTTP_PATH                    = @"msal.http_path";
NSString *const MSAL_TELEMETRY_KEY_HTTP_REQUEST_ID_HEADER       = @"msal.x_ms_request_id";
NSString *const MSAL_TELEMETRY_KEY_HTTP_RESPONSE_CODE           = @"msal.response_code";
NSString *const MSAL_TELEMETRY_KEY_OAUTH_ERROR_CODE             = @"msal.oauth_error_code";
NSString *const MSAL_TELEMETRY_KEY_HTTP_RESPONSE_METHOD         = @"msal.response_method";
NSString *const MSAL_TELEMETRY_KEY_REQUEST_QUERY_PARAMS         = @"msal.query_params";
NSString *const MSAL_TELEMETRY_KEY_USER_AGENT                   = @"msal.user_agent";
NSString *const MSAL_TELEMETRY_KEY_HTTP_ERROR_DOMAIN            = @"msal.http_error_domain";
NSString *const MSAL_TELEMETRY_KEY_AUTHORITY                    = @"msal.authority";
NSString *const MSAL_TELEMETRY_KEY_GRANT_TYPE                   = @"msal.grant_type";
NSString *const MSAL_TELEMETRY_KEY_API_STATUS                   = @"msal.api_status";
NSString *const MSAL_TELEMETRY_KEY_REQUEST_ID                   = @"msal.request_id";
NSString *const MSAL_TELEMETRY_KEY_USER_CANCEL                  = @"msal.user_cancel";

// Telemetry property value
NSString *const MSAL_TELEMETRY_VALUE_YES                             = @"yes";
NSString *const MSAL_TELEMETRY_VALUE_NO                              = @"no";
NSString *const MSAL_TELEMETRY_VALUE_MULTIPLE                        = @"multiple";
NSString *const MSAL_TELEMETRY_VALUE_TRIED                           = @"tried";
NSString *const MSAL_TELEMETRY_VALUE_EXPIRED                         = @"expired";
NSString *const MSAL_TELEMETRY_VALUE_USER_CANCELLED                  = @"user_cancelled";
NSString *const MSAL_TELEMETRY_VALUE_NOT_FOUND                       = @"not_found";
NSString *const MSAL_TELEMETRY_VALUE_ACCESS_TOKEN                    = @"access_token";
NSString *const MSAL_TELEMETRY_VALUE_REFRESH_TOKEN                   = @"refresh_token";
NSString *const MSAL_TELEMETRY_VALUE_MULTI_RESOURCE_REFRESH_TOKEN    = @"multi_resource_refresh_token";
NSString *const MSAL_TELEMETRY_VALUE_FAMILY_REFRESH_TOKEN            = @"family_refresh_token";
NSString *const MSAL_TELEMETRY_VALUE_ADFS_TOKEN                      = @"ADFS_access_token_refresh_token";
NSString *const MSAL_TELEMETRY_VALUE_BY_CODE                         = @"by_code";
NSString *const MSAL_TELEMETRY_VALUE_BY_REFRESH_TOKEN                = @"by_refresh_token";
NSString *const MSAL_TELEMETRY_VALUE_SUCCEEDED                       = @"succeeded";
NSString *const MSAL_TELEMETRY_VALUE_FAILED                          = @"failed";
NSString *const MSAL_TELEMETRY_VALUE_CANCELLED                       = @"cancelled";
NSString *const MSAL_TELEMETRY_VALUE_UNKNOWN                         = @"unknown";
NSString *const MSAL_TELEMETRY_VALUE_AUTHORITY_AAD                   = @"aad";
NSString *const MSAL_TELEMETRY_VALUE_AUTHORITY_ADFS                  = @"adfs";
NSString *const MSAL_TELEMETRY_VALUE_AUTHORITY_B2C                   = @"b2c";
