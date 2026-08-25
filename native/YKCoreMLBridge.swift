// YKCoreMLBridge.swift — compiled into the APP TARGET by the config plugin
// (plugins/with-coreml-llm.js), because that is where the SPM package lives.
// The pod's thin shim (CoreMLTierModule.swift) finds this class at runtime by
// name — the legal crossing of the pods wall that build 34 proved solid.
//
// API SHAPE: start(request) -> token, poll(token) -> result-or-nil. Single
// argument, synchronous methods only, so the shim can call them through the
// Objective-C runtime with plain `perform` — no block bridging, no protocol
// visibility questions, nothing clever enough to break.
import Foundation
#if canImport(CoreMLLLM)
import CoreMLLLM
#endif

@objc(YKCoreMLBridge)
public final class YKCoreMLBridge: NSObject {
  private static let lock = NSLock()
  private static var results: [String: NSDictionary] = [:]
  #if canImport(CoreMLLLM)
  @available(iOS 18.0, *)
  private static var llm: CoreMLLLM? {
    get { _llmBox as? CoreMLLLM }
    set { _llmBox = newValue }
  }
  #endif
  private static var _llmBox: AnyObject?

  private static func finish(_ token: String, _ dict: [String: Any]) {
    lock.lock()
    results[token] = dict as NSDictionary
    lock.unlock()
  }

  /** Begin an operation. request: { op: availability|prepare|generate|release,
   *  prompt, maxTokens, url, folder }. Returns a token for poll(). */
  @objc public static func start(_ request: NSDictionary) -> NSString {
    let token = UUID().uuidString
    let op = (request["op"] as? String) ?? ""
    #if canImport(CoreMLLLM)
    if #available(iOS 18.0, *) {
      switch op {
      case "availability":
        finish(token, ["ok": true, "value": _llmBox == nil ? "available" : "prepared"])
      case "release":
        llm = nil
        finish(token, ["ok": true, "value": "released"])
      case "prepare":
        let url = (request["url"] as? String) ?? ""
        let folder = (request["folder"] as? String) ?? ""
        Task {
          do {
            if llm == nil {
              if !url.isEmpty && !folder.isEmpty {
                let info = ModelDownloader.ModelInfo(
                  id: folder, name: folder, size: "", downloadURL: url, folderName: folder)
                llm = try await CoreMLLLM.load(model: info)
              } else {
                llm = try await CoreMLLLM.load(repo: "qwen2.5-0.5b")
              }
            }
            finish(token, ["ok": true, "value": "prepared"])
          } catch {
            finish(token, ["ok": false, "reason": "loadFailed", "detail": String(describing: error)])
          }
        }
      case "generate":
        let prompt = (request["prompt"] as? String) ?? ""
        let maxTokens = (request["maxTokens"] as? Int) ?? 256
        Task {
          guard let model = llm else {
            return finish(token, ["ok": false, "reason": "notPrepared"])
          }
          do {
            let text = try await model.generate(prompt, maxTokens: maxTokens)
            finish(token, ["ok": true, "value": text])
          } catch {
            finish(token, ["ok": false, "reason": "failed", "detail": String(describing: error)])
          }
        }
      default:
        finish(token, ["ok": false, "reason": "unknownOp"])
      }
    } else {
      finish(token, ["ok": false, "reason": "unavailableOS"])
    }
    #else
    finish(token, ["ok": false, "reason": "noPackage"])
    #endif
    return token as NSString
  }

  /** The finished result for a token, or nil while the operation runs. */
  @objc public static func poll(_ token: NSString) -> NSDictionary? {
    lock.lock()
    defer { lock.unlock() }
    if let r = results[token as String] {
      results.removeValue(forKey: token as String)
      return r
    }
    return nil
  }
}
