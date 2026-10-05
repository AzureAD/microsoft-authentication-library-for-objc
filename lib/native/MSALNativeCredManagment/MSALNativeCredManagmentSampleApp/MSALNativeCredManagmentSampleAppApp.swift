//
//  MSALNativeCredManagmentSampleAppApp.swift
//  MSALNativeCredManagmentSampleApp
//
//  Created by Serhii Demchenko on 2026-05-27.
//

import SwiftUI

@main
struct MSALNativeCredManagmentSampleAppApp: App {

    @StateObject private var viewModel = CredentialManagementViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.initialize()
                }
        }
    }
}
