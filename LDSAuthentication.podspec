Pod::Spec.new do |s|
  s.name         = "LDSAuthentication"
  s.version      = "1.3.0"
  s.summary      = "Swift client library for LDS Account authentication."
  s.author       = 'Stephan Heilner'
  s.homepage     = "https://github.com/CrossWaterBridge/LDSAuthentication"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source       = { :git => "https://github.com/CrossWaterBridge/LDSAuthentication.git", :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'
  s.requires_arc = true
  s.default_subspec = 'Auth'

  s.subspec 'Keychain' do |ss|
    ss.source_files = 'Keychain/*.swift'
    ss.dependency 'Locksmith'
  end
  
  s.subspec 'Auth' do |ss|
    ss.source_files = 'Auth/*.swift'
    ss.dependency 'ProcedureKit'
    ss.dependency 'Swiftification'
    ss.dependency 'LDSAuthentication/Keychain'
  end
  
end
