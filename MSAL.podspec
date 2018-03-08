Pod::Spec.new do |s|
  s.name             = 'MSAL'
  s.version          = '0.1.2'
  s.summary          = 'Microsoft Authentication Library for iOS'
  s.description      = <<-DESC
The MSAL library preview for iOS gives your app the ability to begin using the Microsoft Cloud by supporting Microsoft Azure Active Directory and Microsoft Accounts in a converged experience using industry standard OAuth2 and OpenID Connect. The library also supports Microsoft Azure B2C for those using our hosted identity management service.
                       DESC

  s.homepage         = 'https://github.com/AzureAD/microsoft-authentication-library-for-objc'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Zayin Krige' => 'zkrige@gmail.com' }
  s.source           = { :git => 'https://github.com/zkrige/microsoft-authentication-library-for-objc.git', 
                         :submodules => true
			}
  s.ios.deployment_target = '10.0'

  s.source_files = 'MSAL/src/**/*.{h,m}', 
                   'MSAL/IdentityCore/IdentityCore/src/**/*.{h,m}', 
                   'MSAL/IdentityCore/IdentityCore/tests/**/MSIDVersion.{h,m,c}' 
  s.exclude_files = 'MSAL/src/cache/mac/**/*',
		    'MSAL/src/ui/mac/**/*',
		    'MSAL/src/public/mac/**/*',
		    'MSAL/IdentityCore/IdentityCore/src/**/MSIDTestIdTokenUtil.{h,m}' 
  s.public_header_files = 'MSAL/src/public/*.h'
  s.prefix_header_file = 'MSAL/src/MSAL.pch'
  pch_MSAL = <<-EOS
	#import "NSDictionary+MSIDExtensions.h"
	#import "NSString+MSIDExtensions.h"
	#import "NSURL+MSIDExtensions.h"
	#import "MSIDLogger+Internal.h"
	#import "MSIDError.h"
	#import "MSIDOAuth2Constants.h"
	#import "IdentityCore_Internal.h"

	#import "MSAL_Internal.h"
	#import "NSOrderedSet+MSALExtensions.h"
	#import "MSALTokenCache.h"
	#import "MSALAccessTokenCacheItem.h"
	#import "MSALKeychainTokenCache.h"
	#import "MSALClientInfo.h"
  EOS
  s.prefix_header_contents = pch_MSAL
end
