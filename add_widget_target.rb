require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

widget_name      = 'PrayerWidget'
widget_bundle_id = 'com.ihsan.ihsanapp.PrayerWidget'
team_id          = '98Q8PA74RJ'

# ── Get or create widget target ───────────────────────────────────────────────
widget_target = project.targets.find { |t| t.name == widget_name }

if widget_target.nil?
  widget_target = project.new_target(:app_extension, widget_name, :ios, '15.0')
  puts "Created PrayerWidget target"
else
  puts "PrayerWidget target already exists — updating settings only"
end

# ── Add frameworks if not already present ─────────────────────────────────────
['WidgetKit', 'SwiftUI'].each do |fw|
  fw_path = "System/Library/Frameworks/#{fw}.framework"
  unless project.frameworks_group.files.any? { |f| f.path == fw_path }
    ref = project.frameworks_group.new_file(fw_path)
    widget_target.frameworks_build_phase.add_file_reference(ref)
  end
end

# ── Get or create source group ────────────────────────────────────────────────
widget_group = project.main_group.groups.find { |g| g.name == widget_name }
widget_group ||= project.main_group.new_group(widget_name, widget_name)

# ── Add Swift source files if not already present ─────────────────────────────
swift_dir   = "#{widget_name}/#{widget_name}"

['PrayerData.swift', 'PrayerWidgetViews.swift', 'PrayerWidgetBundle.swift'].each do |fname|
  full_path = "#{swift_dir}/#{fname}"
  unless widget_group.files.any? { |f| f.path == full_path }
    ref = widget_group.new_file(full_path)
    widget_target.source_build_phase.add_file_reference(ref)
  end
end

# ── Add Assets if not already present ────────────────────────────────────────
assets_path = "#{swift_dir}/Assets.xcassets"
unless widget_group.files.any? { |f| f.path == assets_path }
  assets_ref = widget_group.new_file(assets_path)
  widget_target.resources_build_phase.add_file_reference(assets_ref)
end

# ── Add Info.plist if not already present ────────────────────────────────────
plist_path = "#{widget_name}/Info.plist"
unless widget_group.files.any? { |f| f.path == plist_path }
  widget_group.new_file(plist_path)
end

# ── Build settings (always overwrite — safe to repeat) ───────────────────────
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME']                          = widget_name
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']             = widget_bundle_id
  config.build_settings['DEVELOPMENT_TEAM']                      = team_id
  config.build_settings['SWIFT_VERSION']                         = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY']                = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']            = '15.0'
  config.build_settings['INFOPLIST_FILE']                        = "#{widget_name}/Info.plist"
  config.build_settings['CODE_SIGN_ENTITLEMENTS']                = "#{widget_name}/#{widget_name}.entitlements"
  config.build_settings['CODE_SIGN_STYLE']                       = 'Manual'
  config.build_settings['CODE_SIGN_IDENTITY']                    = 'Apple Distribution'
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER']        = 'Widget'
  config.build_settings['SKIP_INSTALL']                          = 'YES'
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY']        = 'YES'
end

# ── Embed in Runner — remove ALL existing extension embed phases first ─────────
runner_target = project.targets.find { |t| t.name == 'Runner' }

# Remove any existing copy-files phases targeting PlugIns (spec 13)
runner_target.build_phases.delete_if do |p|
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
  p.dst_subfolder_spec == '13'
end

# Create a single clean embed phase
embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13'

embed_ref          = project.new(Xcodeproj::Project::Object::PBXBuildFile)
embed_ref.file_ref = widget_target.product_reference
embed_ref.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
embed_phase.files << embed_ref

project.save
puts "Done — PrayerWidget target configured"