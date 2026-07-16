//
//  DatabaseViewController.swift
//  PicFerry
//
//  Native SwiftUI upload history.
//

import AppKit
import Observation
import SwiftUI

private enum HistorySort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case name
    case size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest first".localized
        case .oldest: "Oldest first".localized
        case .name: "Name".localized
        case .size: "Size".localized
        }
    }
}

@MainActor
@Observable
private final class HistoryViewModel {
    var items: [HistoryThumbnailModel] = [] {
        didSet { updateDisplayedItems() }
    }
    var selectedIDs: Set<String> = []
    var searchText = "" {
        didSet { updateDisplayedItems() }
    }
    var sort = HistorySort.newest {
        didSet { updateDisplayedItems() }
    }
    var showsClearConfirmation = false
    private(set) var displayedItems: [HistoryThumbnailModel] = []

    private var hostsByID: [String: Host] = [:]

    init() {
        reload()
    }

    private func updateDisplayedItems() {
        let filteredItems = searchText.isEmpty ? items : items.filter {
            $0.fileName.localizedStandardContains(searchText)
                || $0.url.localizedStandardContains(searchText)
                || hostName(for: $0).localizedStandardContains(searchText)
        }

        displayedItems = filteredItems.sorted { lhs, rhs in
            switch sort {
            case .newest:
                lhs.createdDate > rhs.createdDate
            case .oldest:
                lhs.createdDate < rhs.createdDate
            case .name:
                lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
            case .size:
                lhs.size > rhs.size
            }
        }
    }

    func reload() {
        hostsByID = Dictionary(
            ConfigManager.shared.getHostItems().map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        items = ConfigManager.shared.getHistoryList()
        selectedIDs.formIntersection(Set(items.map(\.stableID)))
    }

    func hostName(for item: HistoryThumbnailModel) -> String {
        guard let hostID = item.host else {
            return "Unknown".localized
        }
        return hostsByID[hostID]?.name ?? "Removed host".localized
    }

    func copySelected(_ ids: Set<String>? = nil) {
        let targetIDs = ids ?? selectedIDs
        let urls = items.filter { targetIDs.contains($0.stableID) }.map(\.url)
        guard !urls.isEmpty,
              let result = (NSApplication.shared.delegate as? AppDelegate)?.copyUrls(urls: urls) else {
            return
        }
        NotificationExt.shared.postCopySuccessfulNotice(result)
    }

    func clearHistory() {
        ConfigManager.shared.clearHistoryList()
        selectedIDs.removeAll()
        reload()
    }
}

struct HistoryView: View {
    @State private var model = HistoryViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            historyTable
        }
        .frame(minWidth: 760, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .searchable(text: $model.searchText, prompt: "Search upload history".localized)
        .toolbar {
            ToolbarItemGroup {
                Picker("Sort".localized, selection: $model.sort) {
                    ForEach(HistorySort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()

                Button("Refresh".localized, systemImage: "arrow.clockwise", action: model.reload)
                Button("Copy".localized, systemImage: "doc.on.doc") {
                    model.copySelected()
                }
                    .disabled(model.selectedIDs.isEmpty)
                Button(
                    "Clear upload history".localized,
                    systemImage: "trash",
                    role: .destructive,
                    action: showClearConfirmation
                )
                .disabled(model.items.isEmpty)
            }
        }
        .alert("history.clear.confirmation.title".localized, isPresented: $model.showsClearConfirmation) {
            Button("Cancel".localized, role: .cancel) {}
            Button("Clear".localized, role: .destructive, action: model.clearHistory)
        } message: {
            Text("This action cannot be undone.".localized)
        }
        .task {
            for await _ in NotificationCenter.default.notifications(
                named: ConfigNotifier.notificationName(.updateHistoryList)
            ) {
                model.reload()
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(
                named: ConfigNotifier.notificationName(.changeHostItems)
            ) {
                model.reload()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Upload History".localized)
                    .font(.title2)
                    .bold()
                Text("\(model.displayedItems.count) \("items".localized)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var historyTable: some View {
        if model.displayedItems.isEmpty {
            ContentUnavailableView(
                model.searchText.isEmpty ? "No Upload History".localized : "No Results".localized,
                systemImage: model.searchText.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass",
                description: Text(
                    model.searchText.isEmpty
                        ? "Uploaded files will appear here.".localized
                        : "Try another search term.".localized
                )
            )
        } else {
            Table(model.displayedItems, selection: $model.selectedIDs) {
                TableColumn("Preview".localized) { item in
                    HistoryPreviewCell(item: item)
                }
                .width(min: 48, ideal: 56, max: 68)

                TableColumn("Name".localized, value: \.fileName)
                    .width(min: 120, ideal: 180)

                TableColumn("Host".localized) { item in
                    Text(model.hostName(for: item))
                        .lineLimit(1)
                }
                .width(min: 90, ideal: 120)

                TableColumn("Size".localized) { item in
                    Text(Int64(item.size), format: .byteCount(style: .file))
                }
                .width(min: 72, ideal: 88)

                TableColumn("Time".localized) { item in
                    Text(item.createdDate, format: .dateTime.year().month().day().hour().minute())
                }
                .width(min: 140, ideal: 170)

                TableColumn("URL".localized, value: \.url)
                    .width(min: 180, ideal: 300)
            }
            .contextMenu(forSelectionType: String.self) { ids in
                Button("Copy".localized, systemImage: "doc.on.doc") {
                    model.copySelected(ids)
                }
                .disabled(ids.isEmpty)
            } primaryAction: { ids in
                model.copySelected(ids)
            }
        }
    }

    private func showClearConfirmation() {
        model.showsClearConfirmation = true
    }
}

private struct HistoryPreviewCell: View {
    let item: HistoryThumbnailModel

    var body: some View {
        Group {
            if item.isImage,
               let data = item.thumbnailData,
               let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 38, height: 38)
        .background(.quaternary, in: .rect(cornerRadius: 7))
        .clipShape(.rect(cornerRadius: 7))
        .accessibilityLabel(item.fileName)
    }
}
