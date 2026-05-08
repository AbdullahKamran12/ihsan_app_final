require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

widget_name      = 'PrayerWidget'
widget_bundle_id = 'com.ihsan.ihsanapp.PrayerWidget'
team_id          = '98Q8PA74RJ'

# Exit early if target already exists — prevents duplicates on re-runs
if project.targets.any? { |t| t.name == widget_name }
  puts "PrayerWidget target already exists — skipping"
  exit 0
end

# ── Create widget extension target ───────────────────────────────────────────
widget_target = project.new_target(:app_extension, widget_name, :ios, '14.0')

# ── Add WidgetKit and SwiftUI frameworks ──────────────────────────────────────
widgetkit = project.frameworks_group.new_file('System/Library/Frameworks/WidgetKit.framework')
swiftui   = project.frameworks_group.new_file('System/Library/Frameworks/SwiftUI.framework')
widget_target.frameworks_build_phase.add_file_reference(widgetkit)
widget_target.frameworks_build_phase.add_file_reference(swiftui)

# ── Create source group and add Swift files ───────────────────────────────────
widget_group = project.main_group.new_group(widget_name, widget_name)

['PrayerData.swift', 'PrayerWidgetViews.swift', 'PrayerWidgetBundle.swift'].each do |fname|
  ref = widget_group.new_file("#{widget_name}/#{fname}")
  widget_target.source_build_phase.add_file_reference(ref)
end

# ── Add Assets and Info.plist ─────────────────────────────────────────────────
assets_ref = widget_group.new_file("#{widget_name}/Assets.xcassets")
widget_target.resources_build_phase.add_file_reference(assets_ref)
widget_group.new_file("#{widget_name}/Info.plist")

# ── Build settings ────────────────────────────────────────────────────────────
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']             = widget_bundle_id
  config.build_settings['DEVELOPMENT_TEAM']                      = team_id
  config.build_settings['SWIFT_VERSION']                         = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY']                = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']            = '14.0'
  config.build_settings['INFOPLIST_FILE']                        = "#{widget_name}/Info.plist"
  config.build_settings['CODE_SIGN_ENTITLEMENTS']                = "#{widget_name}/#{widget_name}.entitlements"
  config.build_settings['CODE_SIGN_STYLE']                       = 'Manual'
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER']        = 'codemagic'
  config.build_settings['SKIP_INSTALL']                          = 'YES'
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY']        = 'YES'
end

# ── Embed extension in Runner — reuse existing phase if present ───────────────
runner_target = project.targets.find { |t| t.name == 'Runner' }

embed_phase = runner_target.build_phases.find do |p|
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
  p.dst_subfolder_spec == '13'
end
embed_phase ||= runner_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13'

# Guard against adding the same product reference twice
unless embed_phase.files.any? { |f| f.file_ref == widget_target.product_reference }
  embed_ref          = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  embed_ref.file_ref = widget_target.product_reference
  embed_ref.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  embed_phase.files << embed_ref
end

project.save
puts "Done — PrayerWidget target added"