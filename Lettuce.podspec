#
#  Be sure to run `pod spec lint Lettuce.podspec' to ensure this is a

Pod::Spec.new do |s|
  s.name         = "Lettuce"
  s.version      = "0.0.3"
  s.summary      = "Simple network interceptor for Swift."
  s.description  = <<-DESC
  Sniff your network requests using a base URL so you can assert on the payload for faster network issues debugging.
                   DESC

  s.homepage     = "https://github.com/alyakan/Lettuce"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Aly" => "aly.yakan@gmail.com" }
  s.platform     = :ios, "9.0"
  s.swift_version = "4.2"
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/alyakan/Lettuce.git", :tag => "#{s.version}" }
  s.source_files  = 'Lettuce/Classes/**/*'
  s.dependency "GZIP", "~> 1.2"
end
