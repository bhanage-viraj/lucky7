// ViewModels/DistractionViewModel.swift
// Placeholder for DistractionViewModel

import Foundation
import Combine
import SwiftData

@MainActor
class DistractionStat: ObservableObject {
    @Published var distractions: [Distraction] = []
    @Published var totalDistractionDuration: TimeInterval = 0.0
    
    var distractionCount: Int {
        distractions.count
    }
    
    func fetchDistractions(for sessionId: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Distraction>(
                predicate: #Predicate { $0.sessionId == sessionId}
            )
            
            let fetchedDistraction = try context.fetch(descriptor)
            self.distractions = fetchedDistraction
            
            self.totalDistractionDuration = distractions.reduce(0.0) { $0 + $1.distractionDuration }

        } catch {
            print("Error fetching distractions count: \(error)")
        }
    }
}
