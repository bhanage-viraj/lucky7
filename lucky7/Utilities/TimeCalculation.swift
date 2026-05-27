//
//  TimeCalculation.swift
//  lucky7
//
//  Created by Kadek Belvanatha Gargita Satwikananda on 26/05/26.
//

import Foundation

extension Date {
    func intervalInSeconds(to endTime: Date) -> TimeInterval {
        return endTime.timeIntervalSince(self)
    }
}
