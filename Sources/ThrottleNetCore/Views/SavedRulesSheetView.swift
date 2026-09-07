import SwiftUI

/// Modal sheet for viewing and managing all saved persistent auto-rules.
public struct SavedRulesSheetView: View {
  @ObservedObject var viewModel: DashboardViewModel
  @ObservedObject private var ruleStore = PersistentRuleStore.shared

  public var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Header
      HStack {
        Label("Saved Auto-Rules", systemImage: "pin.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(.purple)

        Spacer()

        Button("Done") {
          viewModel.isShowingSavedRulesSheet = false
        }
        .keyboardShortcut(.defaultAction)
      }

      Text(
        "These limits are automatically applied whenever ThrottleNet detects the process running."
      )
      .font(.system(size: 11))
      .foregroundColor(.secondary)

      Divider()

      if ruleStore.rules.isEmpty {
        VStack(spacing: 12) {
          Spacer()
          Image(systemName: "pin.slash")
            .font(.system(size: 32))
            .foregroundColor(.secondary.opacity(0.5))

          Text("No Auto-Rules Saved")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)

          Text("When throttling any process, check 'Remember & auto-apply' to save it here.")
            .font(.system(size: 11))
            .foregroundColor(.secondary.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach(ruleStore.rules) { rule in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayName)
                  .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 6) {
                  Text(rule.processName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                  if let lastApplied = rule.lastAppliedAt {
                    Text(
                      "• Last applied \(lastApplied.formatted(date: .omitted, time: .shortened))"
                    )
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                  }
                }
              }

              Spacer()

              // Speed tags
              HStack(spacing: 6) {
                if rule.downloadLimitKBps > 0 {
                  Text("↓ \(Int(rule.downloadLimitKBps)) KB/s")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(4)
                }
                if rule.uploadLimitKBps > 0 {
                  Text("↑ \(Int(rule.uploadLimitKBps)) KB/s")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(4)
                }
              }

              // Enabled Toggle
              Toggle(
                "",
                isOn: Binding(
                  get: { rule.isEnabled },
                  set: { _ in ruleStore.toggleRule(id: rule.id) }
                )
              )
              .toggleStyle(.switch)
              .controlSize(.small)

              // Delete Button
              Button(action: {
                ruleStore.deleteRule(id: rule.id)
              }) {
                Image(systemName: "trash")
                  .foregroundColor(.secondary)
                  .font(.system(size: 12))
              }
              .buttonStyle(.plain)
              .help("Delete rule")
            }
            .padding(.vertical, 4)
          }
        }
        .listStyle(.inset)
      }
    }
    .padding(18)
    .frame(width: 480, height: 380)
  }
}
