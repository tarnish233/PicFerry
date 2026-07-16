//
//  OutputFormatEditorView.swift
//  PicFerry
//
//  Native SwiftUI output-format editor.
//

import Observation
import SwiftUI

@MainActor
@Observable
private final class OutputFormatEditorModel {
    struct Draft: Identifiable {
        let id = UUID()
        let databaseID: Int?
        var name: String
        var value: String
    }

    var items: [Draft]

    init() {
        items = DBManager.shared.getOutputFormatList().map {
            Draft(databaseID: $0.identifier, name: $0.name, value: $0.value)
        }
    }

    func add() {
        items.append(Draft(databaseID: nil, name: "Custom".localized, value: "{url}"))
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func save() -> Bool {
        let models = items.compactMap { draft -> OutputFormatModel? in
            let name = draft.name.trim()
            let value = draft.value.trim()
            guard !name.isEmpty, !value.isEmpty else { return nil }
            let model = OutputFormatModel(name: name, value: value)
            model.identifier = draft.databaseID
            return model
        }
        guard models.count == items.count else { return false }
        return DBManager.shared.saveOutputFormats(models)
    }
}

struct OutputFormatEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = OutputFormatEditorModel()
    @State private var showsSaveError = false

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Output Formats".localized)
                        .font(.title2)
                        .bold()
                    Text("Use {url} and {filename} as placeholders.".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: model.add) {
                    Label("Add".localized, systemImage: "plus")
                }
                .buttonStyle(.glass)
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Name".localized)
                        .frame(width: 120, alignment: .leading)
                    Text("Template".localized)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: 28)
                }
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach($model.items) { $item in
                            HStack(spacing: 12) {
                                TextField("Name".localized, text: $item.name)
                                    .frame(width: 120)
                                TextField("{url}", text: $item.value)
                                    .font(.system(.body, design: .monospaced))
                                Button("Remove".localized, systemImage: "trash", role: .destructive) {
                                    model.remove(id: item.id)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .frame(width: 28)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)

                            if item.id != model.items.last?.id {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                }
            }
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.72),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
            }

            HStack {
                Spacer()
                Button("Cancel".localized) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save".localized, action: save)
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.items.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 600, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Could not save output formats".localized, isPresented: $showsSaveError) {
        } message: {
            Text("Names and templates cannot be empty. Your existing formats were not changed.".localized)
        }
    }

    private func save() {
        guard model.save() else {
            showsSaveError = true
            return
        }
        dismiss()
    }
}
