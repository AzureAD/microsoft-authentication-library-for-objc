Pod::Spec.new do |s|
  s.name         = "MSAL"
  s.version      = "2.8.1"
  s.summary      = "Microsoft Authentication Library (MSAL) for iOS"
  s.description  = <<-DESC
                   The MSAL library for iOS gives your app the ability to begin using the Microsoft Cloud by supporting Microsoft Azure Active Directory and Microsoft Accounts in a converged experience using industry standard OAuth2 and OpenID Connect. The library also supports Microsoft Azure B2C for those using our hosted identity management service.
                   DESC
  s.homepage     = "https://github.com/AzureAD/microsoft-authentication-library-for-objc"
  s.license      = { 
    :type => "MIT", 
    :file => "LICENSE" 
  }
  s.authors      = { "Microsoft" => "nugetaad@microsoft.com" }
  s.social_media_url   = "https://twitter.com/azuread"
  s.platform     = :ios, :osx
  s.ios.deployment_target = "14.0"
  s.osx.deployment_target = "10.15"
  s.source       = { 
    :git => "https://github.com/AzureAD/microsoft-authentication-library-for-objc.git",
    :tag => s.version.to_s,
    :submodules => true
  }
  s.swift_versions = '5.0'
  s.resource_bundles = {"MSAL" => ["MSAL/PrivacyInfo.xcprivacy"]}
  s.default_subspecs ='app-lib'
  
  s.prefix_header_file = "MSAL/src/MSAL.pch"
  s.header_dir = "MSAL"

  # ================================
  # Common Configuration
  # ================================
  
  common_xcconfig = { 
    'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF' => 'NO', 
    'DEFINES_MODULE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'SWIFT_INSTALL_OBJC_HEADER' => 'YES',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'MSAL-Swift.h',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MSAL_COCOAPOD=1' 
  }
  
  common_source_files = [
    "MSAL/src/**/*.{h,m}", 
    "MSAL/IdentityCore/IdentityCore/src/**/*.{h,m,swift}"
  ]
  
  common_public_headers = [
    "MSAL/src/public/*.h", 
    "MSAL/src/public/configuration/**/*.h", 
    "MSAL/src/native_auth/public/*.h"
  ]
  
  ios_public_headers = common_public_headers + ["MSAL/src/public/ios/**/*.h"]
  osx_public_headers = common_public_headers + ["MSAL/src/public/mac/**/*.h"]
  
  ios_exclude_files = ["MSAL/src/**/mac/*", "MSAL/IdentityCore/IdentityCore/src/**/mac/*"]
  osx_exclude_files = ["MSAL/src/**/ios/*", "MSAL/IdentityCore/IdentityCore/src/**/ios/*"]

  # Helper to apply common subspec configuration
  apply_common_config = lambda do |subspec|
    subspec.ios.public_header_files = ios_public_headers
    subspec.osx.public_header_files = osx_public_headers
    subspec.ios.exclude_files = ios_exclude_files
    subspec.osx.exclude_files = osx_exclude_files
    subspec.requires_arc = true
  end

  # ================================
  # Subspecs
  # ================================

  s.subspec 'app-lib' do |app|
    app.pod_target_xcconfig = common_xcconfig
    app.source_files = common_source_files
    apply_common_config.call(app)
  end

  s.subspec 'native-auth' do |nat|
    nat.pod_target_xcconfig = common_xcconfig.merge({ 
      'HEADER_SEARCH_PATHS' => "$SRCROOT/MSAL" 
    })
    nat.source_files = common_source_files + [
      "MSAL/src/native_auth/**/*.{h,m,swift}", 
      "MSAL/module.modulemap"
    ]
    apply_common_config.call(nat)
  end
  
  # Note, MSAL has limited support for running in app extensions.
  s.subspec 'extension' do |ext|
    ext.pod_target_xcconfig = common_xcconfig
    ext.compiler_flags = '-DADAL_EXTENSION_SAFE=1'
    ext.source_files = common_source_files
    # There is currently a bug in CocoaPods where it doesn't combine the public headers
    # for both the platform and overall.
    apply_common_config.call(ext)
  end

end
