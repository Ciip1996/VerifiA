Pod::Spec.new do |s|
  s.name             = 'FaceTecSDK'
  s.version          = '9.7.123'
  s.summary          = 'FaceTec 3D Liveness SDK (development build)'
  s.description      = 'FaceTec device SDK for iOS — development xcframework'
  s.homepage         = 'https://facetec.com'
  s.license          = { :type => 'Commercial', :text => 'FaceTec Commercial License' }
  s.author           = { 'FaceTec' => 'sdk@facetec.com' }
  s.platform         = :ios, '15.5'
  s.source           = { :path => '.' }
  s.vendored_frameworks = 'FaceTecSDKForDevelopment.xcframework'
  s.preserve_paths   = 'FaceTecSDKForDevelopment.xcframework'
  s.frameworks       = 'Foundation', 'UIKit', 'AVFoundation', 'CoreMotion',
                       'LocalAuthentication', 'VideoToolbox', 'CoreMedia'
end
