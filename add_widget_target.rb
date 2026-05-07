require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_group = 'group.com.ihsan.ihsanapp'
widget_bundle_id = 'com.ihsan.ihsanapp.PrayerWidget'
widget_name = 'PrayerWidget'

# ── Create the widget extension target ───────────────────────────────────────
widget_target = project.new_target(
  :app_extension,
  widget_name,
  :ios,
  '14.0'
)

# ── Add WidgetKit and SwiftUI frameworks ──────────────────────────────────────
frameworks_group = project.frameworks_group
widgetkit = project.frameworks_group.new_file('System/Library/Frameworks/WidgetKit.framework')
swiftui   = project.frameworks_group.new_file('System/Library/Frameworks/SwiftUI.framework')
widget_target.frameworks_build_phase.add_file_reference(widgetkit)
widget_target.frameworks_build_phase.add_file_reference(swiftui)

# ── Create group for widget source files ─────────────────────────────────────
widget_group = project.main_group.new_group(widget_name, widget_name)

# ── Add Swift source files ────────────────────────────────────────────────────
['PrayerData.swift', 'PrayerWidgetViews.swift', 'PrayerWidgetBundle.swift'].each do |fname|
  ref = widget_group.new_file("#{widget_name}/#{fname}")
  widget_target.source_build_phase.add_file_reference(ref)
end

# ── Add Assets.xcassets ───────────────────────────────────────────────────────
assets_ref = widget_group.new_file("#{widget_name}/Assets.xcassets")
widget_target.resources_build_phase.add_file_reference(assets_ref)

# ── Add Info.plist ────────────────────────────────────────────────────────────
plist_ref = widget_group.new_file("#{widget_name}/Info.plist")

# ── Build settings ────────────────────────────────────────────────────────────
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']    = widget_bundle_id
  config.build_settings['SWIFT_VERSION']                = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY']       = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']   = '14.0'
  config.build_settings['INFOPLIST_FILE']               = "#{widget_name}/Info.plist"
  config.build_settings['CODE_SIGN_ENTITLEMENTS']       = "#{widget_name}/#{widget_name}.entitlements"
  config.build_settings['SKIP_INSTALL']                 = 'YES'
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
end

# ── Embed the extension in the Runner target ──────────────────────────────────
runner_target = project.targets.find { |t| t.name == 'Runner' }
embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13' # PlugIns
embed_ref = project.new(Xcodeproj::Project::Object::PBXBuildFile)
embed_ref.file_ref = widget_target.product_reference
embed_ref.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
embed_phase.files << embed_ref

project.save
puts "Done — PrayerWidget target added to Runner.xcodeproj"