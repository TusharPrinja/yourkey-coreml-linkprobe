// YKCoreMLBridge.swift — compiled into the APP TARGET by the config plugin,
// where the SPM package genuinely lives. The pod's thin shim finds this class
// at runtime via NSClassFromString — the legal crossing of the pods wall.
import Foundation
import CoreMLLLM   // ← the tripwire: unconditional import; cannot compile unless linked

@objc(YKCoreMLBridge)
@available(iOS 18.0, *)
public final class YKCoreMLBridge: NSObject {
  private static var llm: CoreMLLLM?

  @objc public static func hasPackage() -> Bool { true }

  @objc public static func prepare(_ overrideUrl: String, folder overrideFolder: String,
                                   completion: @escaping (Bool, String) -> Void) {
    Task {
      do {
        if llm == nil {
          if !overrideUrl.isEmpty && !overrideFolder.isEmpty {
            let info = ModelDownloader.ModelInfo(
              id: overrideFolder, name: overrideFolder, size: "",
              downloadURL: overrideUrl, folderName: overrideFolder)
            llm = try await CoreMLLLM.load(model: info)
          } else {
            llm = try await CoreMLLLM.load(repo: "qwen2.5-0.5b")
          }
        }
        completion(true, "prepared")
      } catch {
        completion(false, String(describing: error))
      }
    }
  }

  @objc public static func generate(_ prompt: String, maxTokens: Int,
                                    completion: @escaping (Bool, String) -> Void) {
    Task {
      guard let llm else { return completion(false, "notPrepared") }
      do { completion(true, try await llm.generate(prompt, maxTokens: maxTokens)) }
      catch { completion(false, String(describing: error)) }
    }
  }

  @objc public static func releaseModel() { llm = nil }
}
