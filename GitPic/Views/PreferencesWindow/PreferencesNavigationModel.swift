//
//  PreferencesNavigationModel.swift
//  GitPic
//

import Observation

@MainActor
@Observable
final class PreferencesNavigationModel {
    var selection = PreferencesDestination.general
}
