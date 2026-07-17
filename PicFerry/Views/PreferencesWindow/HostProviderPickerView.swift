//
//  HostProviderPickerView.swift
//  PicFerry
//

import SwiftUI

struct HostProviderPickerView: View {
    let addAction: (HostType) -> Void
    let cancelAction: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Choose an Image Host".localized)
                    .font(.title2)
                    .bold()

                Text("Add an image host, then complete its configuration.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(HostType.allCases, id: \.self) { type in
                    providerButton(for: type)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel".localized, action: cancelAction)
            }
        }
        .padding(18)
        .frame(width: 500, height: 190)
    }

    private func providerButton(for type: HostType) -> some View {
        Button {
            addAction(type)
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: Host.getIconByType(type: type))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)

                Text(type.name)
                    .font(.callout.weight(.semibold))

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add %@ image host".localized.replacing("%@", with: type.name))
    }
}
