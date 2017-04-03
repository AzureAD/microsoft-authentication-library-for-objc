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
NSString *const MSAL_TELEMETRY_EVENT_DEFAULT_EVENT          = @"Microsoft.MSAL.default_event";
NSString *const MSAL_TELEMETRY_EVENT_API_EVENT              = @"Microsoft.MSAL.api_event";
NSString *const MSAL_TELEMETRY_EVENT_UI_EVENT               = @"Microsoft.MSAL.ui_event";
NSString *const MSAL_TELEMETRY_EVENT_HTTP_REQUEST           = @"Microsoft.MSAL.http_event";
NSString *const MSAL_TELEMETRY_EVENT_LAUNCH_BROKER          = @"Microsoft.MSAL.broker_event";
NSString *const MSAL_TELEMETRY_EVENT_TOKEN_GRANT            = @"Microsoft.MSAL.token_grant";
NSString *const MSAL_TELEMETRY_EVENT_AUTHORITY_VALIDATION   = @"Microsoft.MSAL.authority_validation";
NSString *const MSAL_TELEMETRY_EVENT_ACQUIRE_TOKEN_SILENT   = @"Microsoft.MSAL.acquire_token_silent_handler";
NSString *const MSAL_TELEMETRY_EVENT_AUTHORIZATION_CODE     = @"Microsoft.MSAL.authorization_code";
NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP     = @"Microsoft.MSAL.token_cache_lookup";
NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE      = @"Microsoft.MSAL.token_cache_write";
NSString *const MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE     = @"Microsoft.MSAL.token_cache_delete";

// Telemetry property name, only alphabetic letters, dots, and underscores are allowed.
NSString *const MSAL_TELEMETRY_KEY_EVENT_NAME                   = @"Microsoft.MSAL.event_name";
NSString *const MSAL_TELEMETRY_KEY_AUTHORITY_TYPE               = @"Microsoft.MSAL.authority_type";
NSString *const MSAL_TELEMETRY_KEY_AUTHORITY_VALIDATION_STATUS  = @"Microsoft.MSAL.authority_validation_status";
NSString *const MSAL_TELEMETRY_KEY_EXTENDED_EXPIRES_ON_SETTING  = @"Microsoft.MSAL.extended_expires_on_setting";
NSString *const MSAL_TELEMETRY_KEY_PROMPT_BEHAVIOR              = @"Microsoft.MSAL.prompt_behavior";
NSString *const MSAL_TELEMETRY_KEY_RESULT_STATUS                = @"Microsoft.MSAL.status";
NSString *const MSAL_TELEMETRY_KEY_IDP                          = @"Microsoft.MSAL.idp";
NSString *const MSAL_TELEMETRY_KEY_TENANT_ID                    = @"Microsoft.MSAL.tenant_id";
NSString *const MSAL_TELEMETRY_KEY_USER_ID                      = @"Microsoft.MSAL.user_id";
NSString *const MSAL_TELEMETRY_KEY_START_TIME                   = @"Microsoft.MSAL.start_time";
NSString *const MSAL_TELEMETRY_KEY_END_TIME                     = @"Microsoft.MSAL.stop_time";
NSString *const MSAL_TELEMETRY_KEY_RESPONSE_TIME                = @"Microsoft.MSAL.response_time";
NSString *const MSAL_TELEMETRY_KEY_DEVICE_ID                    = @"Microsoft.MSAL.device_id";
NSString *const MSAL_TELEMETRY_KEY_DEVICE_IP_ADDRESS            = @"Microsoft.MSAL.device_ip_address";
NSString *const MSAL_TELEMETRY_KEY_APPLICATION_NAME             = @"Microsoft.MSAL.application_name";
NSString *const MSAL_TELEMETRY_KEY_APPLICATION_VERSION          = @"Microsoft.MSAL.application_version";
NSString *const MSAL_TELEMETRY_KEY_LOGIN_HINT                   = @"Microsoft.MSAL.login_hint";
NSString *const MSAL_TELEMETRY_KEY_NTLM_HANDLED                 = @"Microsoft.MSAL.ntlm";
NSString *const MSAL_TELEMETRY_KEY_UI_EVENT_COUNT               = @"Microsoft.MSAL.ui_event_count";
NSString *const MSAL_TELEMETRY_KEY_BROKER_APP                   = @"Microsoft.MSAL.broker_app";
NSString *const MSAL_TELEMETRY_KEY_BROKER_VERSION               = @"Microsoft.MSAL.broker_version";
NSString *const MSAL_TELEMETRY_KEY_BROKER_PROTOCOL_VERSION      = @"Microsoft.MSAL.broker_protocol_version";
NSString *const MSAL_TELEMETRY_KEY_BROKER_APP_USED              = @"Microsoft.MSAL.broker_app_used";
NSString *const MSAL_TELEMETRY_KEY_CLIENT_ID                    = @"Microsoft.MSAL.client_id";
NSString *const MSAL_TELEMETRY_KEY_HTTP_EVENT_COUNT             = @"Microsoft.MSAL.http_event_count";
NSString *const MSAL_TELEMETRY_KEY_CACHE_EVENT_COUNT            = @"Microsoft.MSAL.cache_event_count";
NSString *const MSAL_TELEMETRY_KEY_API_ID                       = @"Microsoft.MSAL.api_id";
NSString *const MSAL_TELEMETRY_KEY_TOKEN_TYPE                   = @"Microsoft.MSAL.token_type";
NSString *const MSAL_TELEMETRY_KEY_IS_RT                        = @"Microsoft.MSAL.is_rt";
NSString *const MSAL_TELEMETRY_KEY_IS_MRRT                      = @"Microsoft.MSAL.is_mrrt";
NSString *const MSAL_TELEMETRY_KEY_IS_FRT                       = @"Microsoft.MSAL.is_frt";
NSString *const MSAL_TELEMETRY_KEY_RT_STATUS                    = @"Microsoft.MSAL.token_rt_status";
NSString *const MSAL_TELEMETRY_KEY_MRRT_STATUS                  = @"Microsoft.MSAL.token_mrrt_status";
NSString *const MSAL_TELEMETRY_KEY_FRT_STATUS                   = @"Microsoft.MSAL.token_frt_status";
NSString *const MSAL_TELEMETRY_KEY_IS_SUCCESSFUL                = @"Microsoft.MSAL.is_successfull";
NSString *const MSAL_TELEMETRY_KEY_CORRELATION_ID               = @"Microsoft.MSAL.correlation_id";
NSString *const MSAL_TELEMETRY_KEY_IS_EXTENED_LIFE_TIME_TOKEN   = @"Microsoft.MSAL.is_extended_life_time_token";
NSString *const MSAL_TELEMETRY_KEY_API_ERROR_CODE               = @"Microsoft.MSAL.api_error_code";
NSString *const MSAL_TELEMETRY_KEY_PROTOCOL_CODE                = @"Microsoft.MSAL.error_protocol_code";
NSString *const MSAL_TELEMETRY_KEY_ERROR_DESCRIPTION            = @"Microsoft.MSAL.error_description";
NSString *const MSAL_TELEMETRY_KEY_ERROR_DOMAIN                 = @"Microsoft.MSAL.error_domain";
NSString *const MSAL_TELEMETRY_KEY_HTTP_METHOD                  = @"Microsoft.MSAL.method";
NSString *const MSAL_TELEMETRY_KEY_HTTP_PATH                    = @"Microsoft.MSAL.http_path";
NSString *const MSAL_TELEMETRY_KEY_HTTP_REQUEST_ID_HEADER       = @"Microsoft.MSAL.x_ms_request_id";
NSString *const MSAL_TELEMETRY_KEY_HTTP_RESPONSE_CODE           = @"Microsoft.MSAL.response_code";
NSString *const MSAL_TELEMETRY_KEY_OAUTH_ERROR_CODE             = @"Microsoft.MSAL.oauth_error_code";
NSString *const MSAL_TELEMETRY_KEY_HTTP_RESPONSE_METHOD         = @"Microsoft.MSAL.response_method";
NSString *const MSAL_TELEMETRY_KEY_REQUEST_QUERY_PARAMS         = @"Microsoft.MSAL.query_params";
NSString *const MSAL_TELEMETRY_KEY_USER_AGENT                   = @"Microsoft.MSAL.user_agent";
NSString *const MSAL_TELEMETRY_KEY_HTTP_ERROR_DOMAIN            = @"Microsoft.MSAL.http_error_domain";
NSString *const MSAL_TELEMETRY_KEY_AUTHORITY                    = @"Microsoft.MSAL.authority";
NSString *const MSAL_TELEMETRY_KEY_GRANT_TYPE                   = @"Microsoft.MSAL.grant_type";
NSString *const MSAL_TELEMETRY_KEY_API_STATUS                   = @"Microsoft.MSAL.api_status";
NSString *const MSAL_TELEMETRY_KEY_REQUEST_ID                   = @"Microsoft.MSAL.request_id";
NSString *const MSAL_TELEMETRY_KEY_USER_CANCEL                  = @"Microsoft.MSAL.user_cancel";

// Telemetry property value
NSString *const MSAL_TELEMETRY_VALUE_YES                             = @"yes";
NSString *const MSAL_TELEMETRY_VALUE_NO                              = @"no";
NSString *const MSAL_TELEMETRY_VALUE_TRIED                           = @"tried";
NSString *const MSAL_TELEMETRY_VALUE_USER_CANCELLED                  = @"user_cancelled";
NSString *const MSAL_TELEMETRY_VALUE_NOT_FOUND                       = @"not_found";
NSString *const MSAL_TELEMETRY_VALUE_ACCESS_TOKEN                    = @"access_token";
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
