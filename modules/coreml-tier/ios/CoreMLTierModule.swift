// CoreMLTierModule.swift — tier three of the founder's ladder.
//
// FOUNDER'S RULING, 2026-08-20:
//
//   "prioritise PCC as the best… prioritise core ai over core ml for those who
//    aren't On Apple Intelligence and can. And prioritise core ml over llama
//    where there is ANE."
//
// This is the ANE rung: a small LLM compiled to Core ML, running on the Neural
// Engine of any A12-or-later phone on iOS 18+. It exists for the wide middle of
// the fleet — hardware too old for Apple Intelligence (pre-15 Pro) but new
// enough that its ANE beats llama.cpp on the CPU.
//
// The model is Qwen2.5 0.5B at 302MB, Apache 2.0 — verified against the
// package's model table on 2026-08-21. Apache matters: the LFM alternative
// caps free commercial use at $10M revenue, a ceiling this company intends to
// hit.
//
// ── THE SAME THREE RULES AS THE APPLE MODULE ────────────────────────────────
//
// 1. IT MUST NOT EXIST ON OLD PHONES. Deployment target is iOS 15.1; the
//    package needs iOS 18. Everything is behind `#available` + `canImport`,
//    so a build without the package, or a phone below 18, gets stubs and a
//    reason string — never a crash.
//
// 2. THE 302MB IS NEVER DOWNLOADED WITHOUT CONSENT. `prepare()` is the only
//    call that can touch the network, and the JS side only calls it after the
//    member has agreed through the same consent door every other download
//    uses (4.2.3(ii)). availability() and generate() never download.
//
// 3. A FAILURE IS AN ANSWER. generate() returns {ok, reason, text, detail};
//    the JS ladder maps reasons to rungs. Nothing here throws across the
//    bridge except genuinely broken invocations.
//
// ── iOS 18 IS ALSO THE HARDWARE GATE ────────────────────────────────────────
//
// The A11 (iPhone 8/X) never got third-party ANE access, and iOS 18 dropped
// the A11 entirely — its floor is the A12 (XR/XS). So `#available(iOS 18, *)`
// is simultaneously the OS check AND the Neural Engine check, and no separate
// chip detection is needed. That is measured fact from the 2026-08-20 tier
// research, not an assumption.

import ExpoModulesCore

#if canImport(CoreMLLLM)
import CoreMLLLM
#endif

public class CoreMLTierModule: Module {
  #if canImport(CoreMLLLM)
  // The loaded model, held for the app's lifetime once prepared. One instance:
  // the KV-cache state inside a stateful Core ML model is per-instance, and
  // this app's slots are stateless by design — each generate() is one line.
  @available(iOS 18.0, *)
  private static var llm: CoreMLLLM? = nil
  #endif

  public func definition() -> ModuleDefinition {
    Name("CoreMLTier")

    // Why this device can or cannot use the ANE tier. A string, because each
    // "no" falls to a different rung:
    //
    //   available      package present, OS new enough — prepare() may be called
    //   prepared       as above AND the model is loaded — generate() will answer
    //   unavailableOS  iOS below 18 (which also means pre-A12 hardware) → llama
    //   noPackage      this binary was built without the SPM package — a build
    //                  configuration fact, not a device one. The fix is
    //                  registering plugins/with-coreml-llm.js, never a retry.
    AsyncFunction("availability") { () -> String in
      #if canImport(CoreMLLLM)
      if #available(iOS 18.0, *) {
        return CoreMLTierModule.llm == nil ? "available" : "prepared"
      }
      return "unavailableOS"
      #else
      return "noPackage"
      #endif
    }

    // Load the model — downloading it first if it is not cached. THE ONLY
    // NETWORK-CAPABLE CALL IN THIS MODULE. JS gates it behind the member's
    // download consent; nothing native re-checks that, because consent is a
    // product decision and it lives in one place (boot.ts), not two.
    //
    // The package's loader caches under its own directory with resume support,
    // so a second prepare() after a kill is a disk read, not a re-download.
    AsyncFunction("prepare") { (overrideUrl: String, overrideFolder: String) -> [String: Any] in
      #if canImport(CoreMLLLM)
      if #available(iOS 18.0, *) {
        if CoreMLTierModule.llm != nil {
          return ["ok": true, "reason": "prepared"]
        }
        do {
          // Qwen2.5 0.5B: 309MB, Apache 2.0. Slug verified against the
          // package's ModelInfo.defaults on 2026-08-25, and the exact call
          // shapes are compile-proven by the fork's YourKeyContract.swift on
          // CI — an API drift breaks there, never in an EAS build.
          //
          // THE LAST-BUILD LAW: when JavaScript supplies a URL (both args
          // non-empty), the model downloads from there instead — so hosting
          // can move to Your Key's own R2 by OTA, without a rebuild, forever.
          let model: CoreMLLLM
          if !overrideUrl.isEmpty && !overrideFolder.isEmpty {
            let info = ModelDownloader.ModelInfo(
              id: overrideFolder, name: overrideFolder, size: "",
              downloadURL: overrideUrl, folderName: overrideFolder)
            model = try await CoreMLLLM.load(model: info)
          } else {
            model = try await CoreMLLLM.load(repo: "qwen2.5-0.5b")
          }
          CoreMLTierModule.llm = model
          return ["ok": true, "reason": "prepared"]
        } catch {
          return ["ok": false, "reason": "loadFailed", "detail": String(describing: error)]
        }
      }
      return ["ok": false, "reason": "unavailableOS"]
      #else
      return ["ok": false, "reason": "noPackage"]
      #endif
    }

    // One line, one call — stateless on purpose, the same contract as the
    // Apple tier and llama.cpp, so the rungs stay interchangeable.
    AsyncFunction("generate") { (prompt: String, maxTokens: Int, temperature: Double) -> [String: Any] in
      #if canImport(CoreMLLLM)
      if #available(iOS 18.0, *) {
        guard let llm = CoreMLTierModule.llm else {
          return ["ok": false, "reason": "notPrepared", "text": ""]
        }
        do {
          // Verified against the package source 2026-08-25: generate(_:maxTokens:)
          // is the string-level API (compile-proven by YourKeyContract.swift).
          // Temperature is not exposed on this surface — the validator is the
          // quality gate, exactly as on every other rung.
          _ = temperature
          let text = try await llm.generate(prompt, maxTokens: maxTokens)
          return ["ok": true, "reason": "", "text": text]
        } catch {
          let message = String(describing: error)
          return ["ok": false, "reason": "failed", "text": "", "detail": message]
        }
      }
      return ["ok": false, "reason": "unavailableOS", "text": ""]
      #else
      return ["ok": false, "reason": "noPackage", "text": ""]
      #endif
    }

    // Free the model. The RAM law that governs every local tier applies here
    // too — a 0.5B model held while Kokoro speaks is memory the audio needs.
    AsyncFunction("release") { () -> Bool in
      #if canImport(CoreMLLLM)
      if #available(iOS 18.0, *) {
        CoreMLTierModule.llm = nil
        return true
      }
      return false
      #else
      return false
      #endif
    }
  }
}
