# Xuyiming: CocoaPods specification for the standalone popup component.
Pod::Spec.new do |s|
  s.name = 'XYMPopWindow'
  s.version = '0.1.0'
  s.summary = 'Objective-C bottom popups with nested transitions and WebKit content.'
  s.description = 'Reusable UIKit popup containers with Masonry layout, nested navigation, scroll coordination, and a WebKit popup.'
  # Planned repository address; this project has not been uploaded or tagged yet.
  s.homepage = 'https://github.com/MIKU-MIKU-39/XYMPopWindow'
  s.source = { :git => 'https://github.com/MIKU-MIKU-39/XYMPopWindow.git', :tag => s.version.to_s }
  s.author = 'Xuyiming'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.ios.deployment_target = '13.0'
  s.requires_arc = true
  s.source_files = 'Sources/**/*.{h,m}'
  s.public_header_files = 'Sources/*.h'
  s.frameworks = 'UIKit', 'WebKit'
  s.dependency 'Masonry', '~> 1.1'
end
