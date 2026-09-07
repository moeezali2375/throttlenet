import SwiftUI

/// Main dashboard view for ThrottleNet.
public struct MainDashboardView: View {
  @StateObject private var viewModel = DashboardViewModel()

  public init() {}

  public var body: some View {
    VStack(spacing: 0) {
      // 1. Top Summary Card
      StatusBarSummaryView(viewModel: viewModel)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)

      // 2. Search & Filter Bar
      HStack(spacing: 10) {
        // Search Input
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)
            .font(.system(size: 11))

          TextField("Search processes or PID...", text: $viewModel.searchQuery)
            .textFieldStyle(.plain)
            .font(.system(size: 12))

          if !viewModel.searchQuery.isEmpty {
            Button(action: { viewModel.searchQuery = "" }) {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .frame(maxWidth: 220)

        // Filter Segmented Control
        Picker("Filter", selection: $viewModel.filterMode) {
          ForEach(ProcessFilterMode.allCases) { mode in
            Text(mode.rawValue).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)

        Spacer()

        // Auto-Rules Sheet Button
        Button(action: {
          viewModel.isShowingSavedRulesSheet = true
        }) {
          HStack(spacing: 4) {
            Image(systemName: "pin.fill")
              .font(.system(size: 10))
              .foregroundColor(.purple)
            Text("Auto-Rules (\(viewModel.ruleStore.rules.count))")
              .font(.system(size: 11, weight: .medium))
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        // Sort Menu
        Menu {
          Picker("Sort By", selection: $viewModel.sortField) {
            ForEach(ProcessSortField.allCases) { field in
              Text(field.rawValue).tag(field)
            }
          }

          Divider()

          Button(action: {
            viewModel.sortAscending.toggle()
          }) {
            Label(
              viewModel.sortAscending ? "Ascending Order" : "Descending Order",
              systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
            )
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "arrow.up.arrow.down")
              .font(.system(size: 10))
            Text(viewModel.sortField.rawValue)
              .font(.system(size: 11))
          }
        }
        .menuStyle(.borderlessButton)
        .frame(width: 130)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

      Divider()

      // 3. Process Table Header
      HStack(spacing: 12) {
        Text("PROCESS")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.secondary)
          .frame(minWidth: 160, alignment: .leading)
          .padding(.leading, 38)

        Spacer()

        Text("ACTIVITY")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.secondary)
          .frame(width: 70, alignment: .center)

        Text("DOWNLOAD")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.secondary)
          .frame(width: 78, alignment: .trailing)

        Text("UPLOAD")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.secondary)
          .frame(width: 78, alignment: .trailing)

        Text("LIMIT / ACTION")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.secondary)
          .frame(width: 130, alignment: .trailing)
      }
      .padding(.horizontal, 26)
      .padding(.vertical, 6)
      .background(Color(NSColor.windowBackgroundColor))

      Divider()

      // 4. Process List
      let list = viewModel.filteredAndSortedProcesses

      if list.isEmpty {
        VStack(spacing: 12) {
          Spacer()
          Image(systemName: "network.slash")
            .font(.system(size: 36))
            .foregroundColor(.secondary.opacity(0.6))

          Text(
            viewModel.searchQuery.isEmpty
              ? "No active network processes detected"
              : "No processes matching \"\(viewModel.searchQuery)\""
          )
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.secondary)

          Text(
            "ThrottleNet is continuously monitoring network sockets via macOS diagnostic subsystem."
          )
          .font(.system(size: 11))
          .foregroundColor(.secondary.opacity(0.8))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(list) { process in
              ProcessRowView(process: process, viewModel: viewModel)
                .padding(.horizontal, 14)
            }
          }
          .padding(.vertical, 6)
        }
      }

      Divider()

      // 5. Bottom Toolbar
      HStack(spacing: 12) {
        HStack(spacing: 6) {
          Circle()
            .fill(Color.green)
            .frame(width: 7, height: 7)

          Text("Monitoring (\(list.count) processes)")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }

        Spacer()

        Button(action: {
          viewModel.monitor.sampleBandwidth()
        }) {
          Label("Refresh", systemImage: "arrow.clockwise")
            .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Color(NSColor.windowBackgroundColor))
    }
    .frame(minWidth: 700, minHeight: 480)
    .onAppear {
      viewModel.monitor.startMonitoring()
    }
    .sheet(isPresented: $viewModel.isShowingThrottleSheet) {
      if let selected = viewModel.selectedProcessForThrottle {
        ThrottleSheetView(process: selected, viewModel: viewModel)
      }
    }
    .sheet(isPresented: $viewModel.isShowingSavedRulesSheet) {
      SavedRulesSheetView(viewModel: viewModel)
    }
    .alert(isPresented: $viewModel.isShowingErrorAlert) {
      Alert(
        title: Text("Operation Failed"),
        message: Text(viewModel.errorMessage ?? "An unknown error occurred."),
        dismissButton: .default(Text("OK"))
      )
    }
  }
}
