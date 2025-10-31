//
//  KakeboApp.swift
//  Kakebo
//
//  Created by German Rattia on 31/10/25.
//

import SwiftUI
import SwiftData

@main
struct KakeboApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Transaction.self,
            Category.self,
            SubCategory.self,
            FinancialPeriod.self,
            SavingGoal.self,
            SubGoal.self,
            GamificationProfile.self,
            Achievement.self
        ])
    }
}
