//
//  HeaderDateProvider.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/5/25.
//

import Synchronization
import Foundation

internal final class HeaderDateProvider: Sendable {
    private let mutex = Mutex((cachedDateString: "", lastUpdated: Date.distantPast))

    internal func get() -> String {
        return mutex.withLock { state in 
            if state.lastUpdated.timeIntervalSinceNow < -1 {
                let now = Date.now 
                state.cachedDateString = now.formatted(DateFormat.RFC1123)
                state.lastUpdated = now
            }
            return state.cachedDateString
        }
    }   
}

public enum DateFormat {
    public static let RFC1123 = Date.VerbatimFormatStyle(
        format: """
        \(weekday: .abbreviated), \
        \(day: .twoDigits) \
        \(month: .abbreviated) \ 
        \(year: .defaultDigits) \
        \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) \
        \(timeZone: .specificName(.short))
        """,
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .gmt,
        calendar: Calendar(identifier: .gregorian)
    )
}