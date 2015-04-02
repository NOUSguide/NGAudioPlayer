Pod::Spec.new do |s|
  s.name         = "NGAudioPlayer"
  s.version      = "0.0.5"
  s.license      = { :type => 'MIT', :file => 'LICENCE.md' }
  s.summary      = "An audio player for iOS"
  s.description  = "An audio player for iOS that can handle queueing of URLs."
  s.homepage     = "https://github.com/NOUSguide/NGAudioPlayer"
  s.authors      = { "Matthias Tretter" => "https://github.com/myell0w/", "Thomas Heingaertner" => "https://github.com/kampfgnu/" }
  s.source       = { :git => "https://github.com/NOUSguide/NGAudioPlayer.git", :tag => '0.0.5' }
  s.source_files = 'NGAudioPlayer/*.{h,m}'
  s.frameworks = 'Foundation', 'MediaPlayer', 'CoreMedia', 'AVFoundation'
  s.requires_arc = true
  s.platform     = :ios
  s.ios.deployment_target = '4.3'
end
