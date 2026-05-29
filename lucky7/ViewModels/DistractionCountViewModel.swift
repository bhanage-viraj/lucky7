// ViewModels/DistractionViewModel.swift
// Placeholder for DistractionViewModel

import Foundation
import Combine
import SwiftData

@MainActor
class DistractionCount: ObservableObject {
    @Published var distractions: [Distraction] = []
    
    func fetchDistractions(for sessionId: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Distraction>(
                predicate: #Predicate { distraction in distraction.sessionId == sessionId}
            )
            
            let realData = try context.fetch(descriptor)
            self.distractions = realData

        } catch {
            print("Error fetchin distractions: \(error)")
        }
    }
}
