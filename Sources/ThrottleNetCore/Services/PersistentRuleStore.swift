import Foundation
import Combine

/// Manages persistent storage and lookup of process bandwidth rules.
public final class PersistentRuleStore: ObservableObject {
    public static let shared = PersistentRuleStore()
    
    @Published public private(set) var rules: [PersistentRule] = []
    private let userDefaultsKey = "com.throttlenet.persistent_rules"
    private let queue = DispatchQueue(label: "com.throttlenet.rulestore", qos: .utility)
    
    private init() {
        loadRules()
    }
    
    public func loadRules() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([PersistentRule].self, from: data) {
            DispatchQueue.main.async {
                self.rules = decoded
            }
        }
    }
    
    public func saveRule(_ rule: PersistentRule) {
        var updated = rules.filter { $0.processName != rule.processName.lowercased() }
        updated.append(rule)
        rules = updated
        persist()
    }
    
    public func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
    }
    
    public func deleteRule(forProcessName processName: String) {
        rules.removeAll { $0.processName == processName.lowercased() }
        persist()
    }
    
    public func rule(forProcessName processName: String, bundleId: String? = nil) -> PersistentRule? {
        let name = processName.lowercased()
        return rules.first { rule in
            if let bId = bundleId, let ruleBId = rule.bundleIdentifier, !ruleBId.isEmpty {
                if bId.lowercased() == ruleBId.lowercased() { return true }
            }
            return rule.processName == name
        }
    }
    
    public func toggleRule(id: UUID) {
        if let idx = rules.firstIndex(where: { $0.id == id }) {
            rules[idx].isEnabled.toggle()
            persist()
        }
    }
    
    private func persist() {
        let currentRules = self.rules
        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = try? JSONEncoder().encode(currentRules) {
                UserDefaults.standard.set(data, forKey: self.userDefaultsKey)
            }
        }
    }
}
