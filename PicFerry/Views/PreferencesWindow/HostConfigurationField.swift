//
//  HostConfigurationField.swift
//  PicFerry
//

import SwiftUI

struct HostConfigurationField<Control: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let control: Control

    init(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HostPreferencesMetrics.fieldSpacing) {
            Text(title)
                .font(.headline)

            control
                .frame(maxWidth: .infinity)

            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
