require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_group = 'group.com.ihsan.ihsanapp'
widget_bundle_id = 'com.ihsan.ihsanapp.PrayerWidget'
widget_name = 'PrayerWidget'
development_team = '98Q8PA74RJ'

# ── Prevent duplicate target creation ────────────────────────────────────────
existing_target = project.targets.find { |t| t.name == widget_name }

if existing_target
  puts "#{widget_name} already exists. Skipping creation."
  project.save
  exit
end

# ── Create the widget extension target ───────────────────────────────────────
widget_target = project.new_target(
  :app_extension,
  widget_name,
  :ios,
  '14.0'
)

# ── Add WidgetKit and SwiftUI frameworks ─────────────────────────────────────
widgetkit = project.frameworks_group.new_file(
  'System/Library/Frameworks/WidgetKit.framework'
)

swiftui = project.frameworks_group.new_file(
  'System/Library/Frameworks/SwiftUI.framework'
)

widget_target.frameworks_build_phase.add_file_reference(widgetkit)
widget_target.frameworks_build_phase.add_file_reference(swiftui)

# ── Create group for widget source files ─────────────────────────────────────
widget_group = project.main_group.find_subpath(widget_name, true)
widget_group.set_source_tree('<group>')

# ── Add Swift source files ───────────────────────────────────────────────────
[
  'PrayerData.swift',
  'PrayerWidgetViews.swift',
  'PrayerWidgetBundle.swift'
].each do |fname|

  path = "#{widget_name}/#{fname}"

  unless widget_group.files.find { |f| f.path == path }
    ref = widget_group.new_file(path)
    widget_target.source_build_phase.add_file_reference(ref)
  end
end

# ── Add Assets.xcassets ──────────────────────────────────────────────────────
assets_path = "#{widget_name}/Assets.xcassets"

unless widget_group.files.find { |f| f.path == assets_path }
  assets_ref = widget_group.new_file(assets_path)
  widget_target.resources_build_phase.add_file_reference(assets_ref)
end

# ── Add Info.plist ───────────────────────────────────────────────────────────
plist_path = "#{widget_name}/Info.plist"

unless widget_group.files.find { |f| f.path == plist_path }
  widget_group.new_file(plist_path)
end

# ── Build settings ───────────────────────────────────────────────────────────
widget_target.build_configurations.each do |config|

  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] =
    widget_bundle_id

  config.build_settings['SWIFT_VERSION'] = '5.0'

  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'

  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'

  config.build_settings['INFOPLIST_FILE'] =
    "#{widget_name}/Info.plist"

  config.build_settings['CODE_SIGN_ENTITLEMENTS'] =
    "#{widget_name}/#{widget_name}.entitlements"

  config.build_settings['SKIP_INSTALL'] = 'YES'

  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] =
    'NO'

  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'

  # ── Signing fixes ─────────────────────────────────────────────────────────
  config.build_settings['DEVELOPMENT_TEAM'] =
    development_team

  config.build_settings['CODE_SIGN_STYLE'] =
    'Manual'

  config.build_settings['CODE_SIGN_IDENTITY'] =
    'Apple Distribution'
end

# ── Embed extension into Runner target safely ───────────────────────────────
runner_target = project.targets.find { |t| t.name == 'Runner' }

existing_embed_phase = runner_target.copy_files_build_phases.find do |phase|
  phase.name == 'Embed App Extensions'
end

embed_phase = existing_embed_phase ||
              runner_target.new_copy_files_build_phase(
                'Embed App Extensions'
              )

embed_phase.dst_subfolder_spec = '13' # PlugIns

already_embedded = embed_phase.files.any? do |f|
  f.file_ref == widget_target.product_reference
end

unless already_embedded
  embed_ref = project.new(
    Xcodeproj::Project::Object::PBXBuildFile
  )

  embed_ref.file_ref = widget_target.product_reference

  embed_ref.settings = {
    'ATTRIBUTES' => ['RemoveHeadersOnCopy']
  }

  embed_phase.files << embed_ref
end

project.save

puts "Done — PrayerWidget target added safely."