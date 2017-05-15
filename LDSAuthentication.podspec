Pod::Spec.new do |s|
  s.name         = "LDSAuthentication"
  s.version      = "1.0.1"
  s.summary      = "Swift client library for LDS Account authentication."
  s.author       = 'Stephan Heilner'
  s.homepage     = "https://github.com/CrossWaterBridge/LDSAuthentication"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source       = { :git => "https://github.com/CrossWaterBridge/LDSAuthentication.git", :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'
  s.source_files = 'LDSAuthentication/*.swift'
  s.requires_arc = true
  s.dependency 'ProcedureKit', '4.0.0-beta.4'
  s.dependency 'Locksmith' 
  s.dependency 'Swiftification' 
end
