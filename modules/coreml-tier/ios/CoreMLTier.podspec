Pod::Spec.new do |s|
  s.name           = 'CoreMLTier'
  s.version        = '1.0.0'
  s.summary        = "Core ML LLM on the Neural Engine, tier three of the intelligence ladder"
  s.license        = 'MIT'
  s.author         = 'Your Key App Ltd'
  s.homepage       = 'https://yourkey.app'
  s.platforms      = { :ios => '15.1' }
  s.source         = { :git => '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # ── THE SPM PACKAGE IS DECLARED HERE — THE BUILD-34 LESSON ─────────────────
  #
  # Build 34 proved the app-project route wrong on a real phone: the config
  # plugin attached the package to the APP target, but this pod compiles in
  # the Pods project, which cannot see app-target packages — so
  # `canImport(CoreMLLLM)` stayed false and availability() answered
  # 'noPackage' forever. CocoaPods ≥1.13 crosses that wall properly:
  # `spm_dependency` links the package product to THIS pod target. Pinned to
  # the fork (iOS-16 floor, availability-guarded, contract compile-proven on
  # its CI — upstream's .iOS(.v18) floor would refuse our app).
  #
  # Proven end-to-end (prebuild → pod install → unsigned xcodebuild, with an
  # unguarded-import tripwire) on the public link-probe repo's CI before any
  # EAS credit went near it.
  s.spm_dependency(
    :url => 'https://github.com/TusharPrinja/CoreML-LLM',
    :requirement => {:kind => 'branch', :branch => 'main'},
    :products => ['CoreMLLLM']
  )

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
