//
//  PreferencesCardModifier.swift
//  GitPic
//

import SwiftUI

struct PreferencesCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark
            ? .white.opacity(PreferencesStyleMetrics.cardDarkBackgroundOpacity)
            : .white.opacity(PreferencesStyleMetrics.cardLightBackgroundOpacity)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? .white.opacity(PreferencesStyleMetrics.cardDarkStrokeOpacity)
            : .black.opacity(PreferencesStyleMetrics.cardLightStrokeOpacity)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(PreferencesStyleMetrics.cardDarkShadowOpacity)
            : .black.opacity(PreferencesStyleMetrics.cardLightShadowOpacity)
    }

    func body(content: Content) -> some View {
        content
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: PreferencesStyleMetrics.cardCornerRadius)
            )
            .clipShape(RoundedRectangle(cornerRadius: PreferencesStyleMetrics.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PreferencesStyleMetrics.cardCornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(
                color: shadowColor,
                radius: colorScheme == .dark ? 16 : 4,
                y: colorScheme == .dark ? 8 : 2
            )
    }
}

extension View {
    func preferencesCard() -> some View {
        modifier(PreferencesCardModifier())
    }
}
