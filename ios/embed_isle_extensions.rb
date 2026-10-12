#!/usr/bin/env ruby
# frozen_string_literal: true

# Isle iOS 확장 타깃을 Runner.xcodeproj에 추가합니다.
# 사용: cd ios && gem install xcodeproj && ruby embed_isle_extensions.rb

require 'xcodeproj'

IOS_DIR = File.dirname(__FILE__)
PROJECT_PATH = File.join(IOS_DIR, 'Runner.xcodeproj')
MAIN_BUNDLE_ID = 'com.isle.app.moa.dev'
TEAM_ID = 'V3J8MR637G'

EXTENSIONS = [
  {
    name: 'IsleDeviceActivityMonitor',
    path: 'IsleDeviceActivityMonitor',
    product_type: :app_extension,
    info_plist: 'IsleDeviceActivityMonitor/Info.plist',
    entitlements: 'IsleDeviceActivityMonitor/IsleDeviceActivityMonitor.entitlements',
    sources: ['IsleDeviceActivityMonitor/IsleDeviceActivityMonitor.swift'],
    bundle_suffix: 'IsleDeviceActivityMonitor',
  },
  {
    name: 'IsleSafariContentBlocker',
    path: 'IsleSafariContentBlocker',
    product_type: :app_extension,
    info_plist: 'IsleSafariContentBlocker/Info.plist',
    entitlements: 'IsleSafariContentBlocker/IsleSafariContentBlocker.entitlements',
    sources: ['IsleSafariContentBlocker/ContentBlockerRequestHandler.swift'],
    resources: ['IsleSafariContentBlocker/blockerList.json'],
    bundle_suffix: 'IsleSafariContentBlocker',
  },
  {
    # iOS 공유 시트에 Isle 노출 (Share Extension). receive_sharing_intent 와 연동.
    # pod 링크 없음 — ShareViewController.swift 가 Extension-safe 네이티브 구현.
    name: 'IsleShareExtension',
    path: 'IsleShareExtension',
    product_type: :app_extension,
    info_plist: 'IsleShareExtension/Info.plist',
    entitlements: 'IsleShareExtension/IsleShareExtension.entitlements',
    sources: ['IsleShareExtension/ShareViewController.swift'],
    bundle_suffix: 'IsleShareExtension',
  },
].freeze

def extension_embedded?(project, name)
  project.targets.any? { |t| t.name == name }
end

def add_extension(project, runner_target, spec)
  return if extension_embedded?(project, spec[:name])

  puts "Adding target #{spec[:name]}..."

  ext_target = project.new_target(
    spec[:product_type],
    spec[:name],
    :ios,
    '16.0'
  )

  group = project.main_group.find_subpath(spec[:path], true)
  group.set_source_tree('<group>')
  group.set_path(spec[:path])

  spec[:sources].each do |rel|
    ref = group.new_file(File.basename(rel))
    ext_target.source_build_phase.add_file_reference(ref)
  end

  spec.fetch(:resources, []).each do |rel|
    ref = group.new_file(File.basename(rel))
    ext_target.resources_build_phase.add_file_reference(ref)
  end

  ext_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = spec[:info_plist]
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = spec[:entitlements]
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] =
      "#{MAIN_BUNDLE_ID}.#{spec[:bundle_suffix]}"
    config.build_settings['DEVELOPMENT_TEAM'] = TEAM_ID
    config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    config.build_settings['SKIP_INSTALL'] = 'YES'
    config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks',
    ]
    config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  end

  embed_phase = runner_target.copy_files_build_phases.find { |p| p.dst_subfolder_spec == '13' }
  unless embed_phase
    embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed_phase.name = 'Embed App Extensions'
    embed_phase.symbol_dst_subfolder_spec = :plug_ins
    runner_target.build_phases << embed_phase
  end

  build_file = embed_phase.add_file_reference(ext_target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

  runner_target.add_dependency(ext_target)

  puts "  ✓ #{spec[:name]}"
end

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless runner

EXTENSIONS.each { |spec| add_extension(project, runner, spec) }

project.save
puts 'Done. Open ios/Runner.xcworkspace in Xcode and build on device.'
