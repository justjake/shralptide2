//
//  SDTide+Formatters.swift
//  SwiftTides
//
//  Created by Michael Parlee on 12/24/20.
//

import Foundation
#if os(watchOS)
    import WatchTideFramework
#else
    import ShralpTideFramework
#endif

extension SDTide {
    var currentTideString: String {
        let direction = tideDirection == .rising ? "▲" : "▼"
        let feet = Float(nearestDataPointToCurrentTime.y).formatFeet()
        return feet + direction
    }
}

#if os(watchOS) || WIDGET_EXTENSION
    extension SDTide {
        func hoursToPlot() -> Int {
            return startTime.hoursInDay()
        }
    }
#else
    extension SDTide {
        func hoursToPlot() -> Int {
            guard startTime == nil else {
                let diffComponents = Calendar.current.dateComponents(
                    [.hour], from: startTime, to: stopTime
                )
                return diffComponents.hour!
            }
            return 0
        }
    }
#endif

enum TideError: Error {
    case notFound
}

extension SDTide {
    func nextTide(from date: Date) throws -> SDTideEvent {
        guard let nextEvent = (events.filter { date.timeIntervalSince1970 < $0.eventTime.timeIntervalSince1970 }.first) else { throw TideError.notFound }
        return nextEvent
    }
}
