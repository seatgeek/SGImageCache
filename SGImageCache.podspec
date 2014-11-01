Pod::Spec.new do |s|
  s.name         = "SGImageCache"
  s.version      = "1.2.0"
  s.summary      = "A lightweight iOS image cache."
  s.homepage     = "https://github.com/seatgeek/SGImageCache"
  s.license      = { :type => "BSD", :file => "LICENSE" }
  s.author       = "SeatGeek"
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/seatgeek/SGImageCache.git", :tag => "1.2.0" }
  s.requires_arc = true
  s.dependency "SGHTTPRequest"
  s.dependency "MGEvents"

  s.default_subspec = 'base'  # ensures that the PromiseKit additions are opt-in

  s.subspec 'base' do |ss|
    ss.source_files = "*.{h,m}"
  end

  s.subspec 'PromiseKit' do |ss|
    ss.dependency 'PromiseKit/base'
    ss.dependency 'SGImageCache/base'
    ss.source_files = "PromiseKit/*.{h,m}"
  end
end
