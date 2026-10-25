#!/usr/bin/env ruby
# Optional regeneration tool; the generated project is checked in. gem install xcodeproj
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('..', __dir__)
path = File.join(root, 'iOS/MacPulse.xcodeproj')
project = Xcodeproj::Project.new(path)
project.root_object.attributes['LastUpgradeCheck'] = '1600'
project.root_object.known_regions = ['en', 'vi', 'Base']
package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = '..'
project.root_object.package_references << package
app = project.new_target(:application, 'MacPulseMobile', :ios, '17.0')
unit = project.new_target(:unit_test_bundle, 'MacPulseMobileTests', :ios, '17.0')
ui = project.new_target(:ui_test_bundle, 'MacPulseUITests', :ios, '17.0')
def core_dependency(project, target, package)
  product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product.package = package
  product.product_name = 'MacPulseCore'
  target.package_product_dependencies << product
  build = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build.product_ref = product
  target.frameworks_build_phase.files << build
end
[app, unit].each { |t| core_dependency(project, t, package) }
app_group = project.main_group.new_group('MacPulse', 'MacPulse')
Dir[File.join(root, 'iOS/MacPulse/*.swift')].sort.each { |p| app.source_build_phase.add_file_reference(app_group.new_file(File.basename(p))) }
shared = project.main_group.new_group('Shared UI')
['AppTheme.swift', 'AppLocalization.swift', 'Components.swift'].each do |name|
  app.source_build_phase.add_file_reference(shared.new_file("../Sources/MacPulse/#{name}"))
end
['Assets.xcassets', 'PrivacyInfo.xcprivacy'].each { |p| app.resources_build_phase.add_file_reference(app_group.new_file(p)) }
app_group.new_file('Info.plist')
app.resources_build_phase.add_file_reference(project.main_group.new_file('../LICENSE'))
tests = project.main_group.new_group('Tests')
unit.source_build_phase.add_file_reference(tests.new_file('../Tests/MacPulseCoreTests/MobileTests.swift'))
unit.source_build_phase.add_file_reference(tests.new_file('MacPulseTests/MobileDeviceTests.swift'))
ui.source_build_phase.add_file_reference(tests.new_file('MacPulseUITests/MacPulseUITests.swift'))
[unit, ui].each { |t| t.add_dependency(app) }
project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
end
[app, unit, ui].each do |target|
  target.build_configurations.each do |config|
    b = config.build_settings
    b['SWIFT_VERSION'] = '5.0'
    b['TARGETED_DEVICE_FAMILY'] = '1,2'
    b['CODE_SIGN_STYLE'] = 'Automatic'
    b['DEVELOPMENT_TEAM'] = ''
    b['SUPPORTS_MACCATALYST'] = 'NO'
    b['SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
    b['GENERATE_INFOPLIST_FILE'] = 'YES'
    b['PRODUCT_BUNDLE_IDENTIFIER'] = "com.macpulse.mobile#{target == app ? '' : '.' + target.name}"
  end
end
app.product_reference.path = 'MacPulse.app'
app.build_configurations.each do |config|
  b = config.build_settings
  b['PRODUCT_NAME'] = 'MacPulse'
  b['PRODUCT_MODULE_NAME'] = 'MacPulseMobile'
  b['INFOPLIST_FILE'] = 'MacPulse/Info.plist'
  b['GENERATE_INFOPLIST_FILE'] = 'NO'
  b['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  b.delete('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME')
  b['MARKETING_VERSION'] = '1.6.0'
  b['CURRENT_PROJECT_VERSION'] = '7'
  b['ENABLE_PREVIEWS'] = 'YES'
end
unit.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/MacPulse.app/MacPulse'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
ui.build_configurations.each { |c| c.build_settings['TEST_TARGET_NAME'] = app.name }
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(unit)
scheme.add_test_target(ui)
scheme.set_launch_target(app)
scheme.save_as(path, 'MacPulse-iOS', true)
puts "Generated #{path}"
