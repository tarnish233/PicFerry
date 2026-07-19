//
//  HostConfigurationField.swift
//  GitPic
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
        HStack(alignment: .top, spacing: HostPreferencesMetrics.fieldColumnSpacing) {
            VStack(alignment: .leading, spacing: HostPreferencesMetrics.fieldSpacing) {
                Text(title)
                    .font(.headline)

                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: HostPreferencesMetrics.fieldLabelWidth, alignment: .leading)

            control
                .frame(
                    minWidth: HostPreferencesMetrics.fieldControlMinWidth,
                    idealWidth: HostPreferencesMetrics.fieldControlIdealWidth,
                    maxWidth: HostPreferencesMetrics.fieldControlMaxWidth,
                    alignment: .leading
                )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
