Pod::Spec.new do |s|
  s.name         = "MSAL"
  s.version      = "1.0.0"
  s.summary      = "Microsoft Authentication Library (MSAL) Preview for iOS"

  s.description  = <<-DESC
                   The MSAL library preview for iOS gives your app the ability to begin using the Microsoft Cloud by supporting Microsoft Azure Active Directory and Microsoft Accounts in a converged experience using industry standard OAuth2 and OpenID Connect. The library also supports Microsoft Azure B2C for those using our hosted identity management service.
                   DESC
  s.homepage     = "https://github.com/AzureAD/microsoft-authentication-library-for-objc"
  s.license      = { 
    :type => "MIT", 
    :file => "LICENSE" 
  }
  s.authors      = { "Microsoft" => "nugetaad@microsoft.com" }
  s.social_media_url   = "https://twitter.com/azuread"
  s.platform     = :ios, :osx
  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.11"
  s.source       = { 
    :git => "https://github.com/AzureAD/microsoft-authentication-library-for-objc.git",
    :tag => s.version.to_s,
    :submodules => true
  }

  s.pod_target_xcconfig = { 'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF' => 'NO' }
  s.default_subspecs ='app-lib'
  
  s.prefix_header_file = "MSAL/src/MSAL.pch"
  s.header_dir = "MSAL"

  s.subspec 'app-lib' do |app|
  	app.source_files = "MSAL/src/**/*.{h,m}", "MSAL/IdentityCore/IdentityCore/src/**/*.{h,m}"
  	app.ios.public_header_files = "MSAL/src/public/*.h","MSAL/src/public/ios/**/*.h", "MSAL/src/public/configuration/**/*.h"
  	app.osx.public_header_files = "MSAL/src/public/mac/*.h","MSAL/src/public/*.h", "MSAL/src/public/configuration/**/*.h"
  
  	app.ios.exclude_files = "MSAL/src/**/mac/*", "MSAL/IdentityCore/IdentityCore/src/**/mac/*"
  		
  	app.osx.exclude_files = "MSAL/src/**/ios/*", "MSAL/IdentityCore/IdentityCore/src/**/ios/*"
  	app.requires_arc = true
  end
  
  # Note, MSAL has limited support for running in app extensions.
  s.subspec 'extension' do |ext|
  	ext.compiler_flags = '-DADAL_EXTENSION_SAFE=1'
  	ext.source_files = "MSAL/src/**/*.{h,m}", "MSAL/IdentityCore/IdentityCore/src/**/*.{h,m}"
  	ext.ios.public_header_files = "MSAL/src/public/*.h","MSAL/src/public/ios/**/*.h", "MSAL/src/public/configuration/**/*.h"
  	ext.osx.public_header_files = "MSAL/src/public/mac/*.h","MSAL/src/public/*.h", "MSAL/src/public/configuration/**/*.h"
  
  	# There is currently a bug in CocoaPods where it doesn't combine the public headers
  	# for both the platform and overall.
  	ext.ios.exclude_files = "MSAL/src/**/mac/*", "MSAL/IdentityCore/IdentityCore/src/**/mac/*"
  	ext.osx.exclude_files = "MSAL/src/**/ios/*", "MSAL/IdentityCore/IdentityCore/src/**/ios/*"
  	ext.requires_arc = true
  end

end
