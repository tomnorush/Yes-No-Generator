#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates YesNo.xcodeproj from the folders in this repository.
#
# The project is committed, so you only need this after adding or removing files
# outside Xcode:
#
#   gem install xcodeproj
#   ruby scripts/generate_project.rb
#
# App identifiers, team and version live in Config/Shared.xcconfig, not here.

require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'YesNo.xcodeproj')
IOS_TARGET = '17.0'
WATCH_TARGET = '10.0'

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH, false, 63)
project.root_object.attributes['LastSwiftUpdateCheck'] = '1600'
project.root_object.attributes['LastUpgradeCheck'] = '1600'
project.root_object.attributes['BuildIndependentTargetsInParallel'] = '1'
project.root_object.known_regions = %w[en Base]
project.root_object.development_region = 'en'

# --- Project-wide settings ---------------------------------------------------

config_group = project.main_group.new_group('Config', 'Config')
xcconfig = config_group.new_file('Shared.xcconfig')

project.build_configurations.each do |config|
  config.base_configuration_reference = xcconfig
  config.build_settings.merge!(
    'SWIFT_VERSION' => '5.0',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES',
    'ENABLE_STRICT_OBJC_MSGSEND' => 'YES',
    'GCC_NO_COMMON_BLOCKS' => 'YES',
    'LOCALIZATION_PREFERS_STRING_CATALOGS' => 'YES',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'DEAD_CODE_STRIPPING' => 'YES',
    'CODE_SIGN_STYLE' => 'Automatic'
  )
  if config.name == 'Debug'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    config.build_settings['ENABLE_TESTABILITY'] = 'YES'
    config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
  else
    config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
    config.build_settings['VALIDATE_PRODUCT'] = 'YES'
  end
end

# --- Helpers -----------------------------------------------------------------

def add_sources(group, target, dir)
  Dir.glob(File.join(ROOT, dir, '**', '*.swift')).sort.each do |path|
    relative = path.delete_prefix(File.join(ROOT, dir) + '/')
    subgroup = relative.split('/')[0...-1].reduce(group) do |parent, name|
      parent.children.find { |child| child.display_name == name } || parent.new_group(name, name)
    end
    ref = subgroup.new_file(File.basename(relative))
    target.source_build_phase.add_file_reference(ref)
  end
end

def set_settings(target, settings)
  target.build_configurations.each do |config|
    config.build_settings = settings.dup
  end
end

def embed(target, product, phase_name, destination, path = '')
  phase = target.new_copy_files_build_phase(phase_name)
  phase.symbol_dst_subfolder_spec = destination
  phase.dst_path = path
  build_file = phase.add_file_reference(product.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# --- Local Swift package with the shared logic --------------------------------

package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = 'YesNoKit'
project.root_object.package_references << package

def link_package(project, target, product_name)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = product_name
  target.package_product_dependencies << dependency
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

# --- iOS app ------------------------------------------------------------------

ios = project.new_target(:application, 'YesNo', :ios, IOS_TARGET)
ios_group = project.main_group.new_group('YesNo', 'YesNo')
add_sources(ios_group, ios, 'YesNo')
ios.resources_build_phase.add_file_reference(ios_group.new_file('Assets.xcassets'))
ios.resources_build_phase.add_file_reference(ios_group.new_file('PrivacyInfo.xcprivacy'))
ios_group.new_file('Info.plist') # merged into the generated Info.plist, not copied
docs_group = project.main_group.new_group('docs', 'docs')
ios.resources_build_phase.add_file_reference(docs_group.new_file('privacy.md'))
link_package(project, ios, 'YesNoKit')

set_settings(ios, {
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'PRODUCT_BUNDLE_IDENTIFIER' => '$(BUNDLE_ID_BASE)',
  'SDKROOT' => 'iphoneos',
  'IPHONEOS_DEPLOYMENT_TARGET' => IOS_TARGET,
  'TARGETED_DEVICE_FAMILY' => '1,2',
  'SUPPORTS_MACCATALYST' => 'NO',
  'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD' => 'NO',
  'SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD' => 'NO',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'INFOPLIST_FILE' => 'YesNo/Info.plist',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Yes or No',
  'INFOPLIST_KEY_LSApplicationCategoryType' => 'public.app-category.utilities',
  'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' => 'YES',
  'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents' => 'YES',
  'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
  'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone' =>
    'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
  'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad' =>
    'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown ' \
    'UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  'ENABLE_PREVIEWS' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
})

# --- watchOS app ---------------------------------------------------------------

watch = project.new_target(:application, 'YesNoWatch', :watchos, WATCH_TARGET)
watch_group = project.main_group.new_group('YesNoWatch', 'YesNoWatch')
add_sources(watch_group, watch, 'YesNoWatch')
watch.resources_build_phase.add_file_reference(watch_group.new_file('Assets.xcassets'))
watch.resources_build_phase.add_file_reference(watch_group.new_file('PrivacyInfo.xcprivacy'))
watch_group.new_file('Info.plist')
link_package(project, watch, 'YesNoKit')

set_settings(watch, {
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'PRODUCT_BUNDLE_IDENTIFIER' => '$(BUNDLE_ID_BASE).watchkitapp',
  'SDKROOT' => 'watchos',
  'WATCHOS_DEPLOYMENT_TARGET' => WATCH_TARGET,
  'TARGETED_DEVICE_FAMILY' => '4',
  'SKIP_INSTALL' => 'YES',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'INFOPLIST_FILE' => 'YesNoWatch/Info.plist',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Yes or No',
  'INFOPLIST_KEY_UISupportedInterfaceOrientations' =>
    'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown',
  'INFOPLIST_KEY_WKCompanionAppBundleIdentifier' => '$(BUNDLE_ID_BASE)',
  'INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp' => 'YES',
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  'ENABLE_PREVIEWS' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
})

# --- Watch complication (WidgetKit extension) ---------------------------------

widget = project.new_target(:app_extension, 'YesNoWatchWidget', :watchos, WATCH_TARGET)
widget_group = project.main_group.new_group('YesNoWatchWidget', 'YesNoWatchWidget')
add_sources(widget_group, widget, 'YesNoWatchWidget')
widget_group.new_file('Info.plist')

set_settings(widget, {
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'PRODUCT_BUNDLE_IDENTIFIER' => '$(BUNDLE_ID_BASE).watchkitapp.complication',
  'SDKROOT' => 'watchos',
  'WATCHOS_DEPLOYMENT_TARGET' => WATCH_TARGET,
  'TARGETED_DEVICE_FAMILY' => '4',
  'SKIP_INSTALL' => 'YES',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'INFOPLIST_FILE' => 'YesNoWatchWidget/Info.plist',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Yes or No',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
})

# --- UI tests ------------------------------------------------------------------

ui_tests = project.new_target(:ui_test_bundle, 'YesNoUITests', :ios, IOS_TARGET)
ui_group = project.main_group.new_group('YesNoUITests', 'YesNoUITests')
add_sources(ui_group, ui_tests, 'YesNoUITests')

set_settings(ui_tests, {
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'PRODUCT_BUNDLE_IDENTIFIER' => '$(BUNDLE_ID_BASE).uitests',
  'SDKROOT' => 'iphoneos',
  'IPHONEOS_DEPLOYMENT_TARGET' => IOS_TARGET,
  'TARGETED_DEVICE_FAMILY' => '1,2',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'TEST_TARGET_NAME' => 'YesNo',
  'SWIFT_EMIT_LOC_STRINGS' => 'NO',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
})

# --- Wiring: complication inside watch app inside phone app -------------------

embed(watch, widget, 'Embed Foundation Extensions', :plug_ins)
watch.add_dependency(widget)
embed(ios, watch, 'Embed Watch Content', :products_directory, '$(CONTENTS_FOLDER_PATH)/Watch')
ios.add_dependency(watch)
ui_tests.add_dependency(ios)

target_attributes = project.root_object.attributes['TargetAttributes'] ||= {}
[ios, watch, widget, ui_tests].each do |target|
  target_attributes[target.uuid] = { 'CreatedOnToolsVersion' => '16.0' }
end
target_attributes[ui_tests.uuid]['TestTargetID'] = ios.uuid

# Loose files worth seeing in Xcode but not built into anything.
project.main_group.new_file('YesNo.storekit')
project.main_group.new_file('README.md')

# new_target links Foundation.framework by a hard-coded SDK path; it's linked implicitly anyway.
project.targets.each do |target|
  target.frameworks_build_phase.files.select { |f| f.file_ref&.path&.end_with?('Foundation.framework') }
        .each(&:remove_from_project)
end
frameworks_group = project.main_group.children.find { |c| c.display_name == 'Frameworks' }
if frameworks_group
  frameworks_group.recursive_children.select { |c| c.is_a?(Xcodeproj::Project::Object::PBXFileReference) }
                  .each(&:remove_from_project)
  frameworks_group.recursive_children.each(&:remove_from_project)
  frameworks_group.remove_from_project
end

project.root_object.preferred_project_object_version = '63'
project.sort(groups_position: :above)
project.save

# --- Shared schemes -------------------------------------------------------------

ios_scheme = Xcodeproj::XCScheme.new
ios_scheme.configure_with_targets(ios, ui_tests, launch_target: true)
# Local StoreKit testing: purchases in the simulator use YesNo.storekit, no App Store Connect needed.
ios_scheme.launch_action.xml_element.add_element(
  'StoreKitConfigurationFileReference', 'identifier' => '../../YesNo.storekit'
)
ios_scheme.save_as(PROJECT_PATH, 'YesNo', true)

watch_scheme = Xcodeproj::XCScheme.new
watch_scheme.configure_with_targets(watch, nil, launch_target: true)
watch_scheme.save_as(PROJECT_PATH, 'YesNoWatch', true)

puts "Generated #{PROJECT_PATH.delete_prefix(ROOT + '/')}"
