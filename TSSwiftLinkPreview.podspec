Pod::Spec.new do |s|

	s.ios.deployment_target = '13.0'
	s.platform         = :ios, '13.0'
	s.name = "TSSwiftLinkPreview"
	s.summary = "It makes a preview from an url, grabbing all the information such as title, relevant texts and images."
	s.requires_arc = true
	s.version = "1.1.3"
	s.license = { :type => "MIT", :file => "LICENSE" }
	s.author = { "Leonardo Cardoso" => "contact@leocardz.com" }
	s.homepage = "https://github.com/Topsecret-network/SwiftLinkPreview"
	s.source = { :git => "https://github.com/Topsecret-network/SwiftLinkPreview.git", :tag => s.version }
	s.source_files = "Sources/**/*.swift"
	s.swift_version = '4.2'

end
