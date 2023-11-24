//
//  ChartView.swift
//  SwiftTides
//
//  Created by Michael Parlee on 12/28/20.
//
#if os(watchOS)
    import WatchTideFramework
#else
    import ShralpTideFramework
#endif
import SwiftUI
import Charts

struct ChartView: View {
    @State private var selectedDate: Date?

    private let dateFormatter = DateFormatter()
    private let maxZeroThickness: CGFloat = 2

    private var showZero: Bool
    private var tideData: SDTide
    private var percentHeight: CGFloat

    init(tide: SDTide, showZero: Bool = true, percentHeight: CGFloat = 0.8) {
        tideData = tide
        dateFormatter.dateStyle = .full
        self.showZero = showZero
        self.percentHeight = percentHeight
    }

    private func pairRiseAndSetEvents(
        _ events: [SDTideEvent], riseEventType: SDTideState, setEventType: SDTideState
    ) -> [(Date, Date)] {
        var pairs = [(Date, Date)]()
        var riseTime: Date!
        var setTime: Date!
        for event: SDTideEvent in events {
            if event.eventType == riseEventType {
                riseTime = event.eventTime
                if event === events.last {
                    setTime = tideData.stopTime
                }
            }
            if event.eventType == setEventType {
                if events.firstIndex(of: event) == 0 {
                    riseTime = tideData.startTime
                }
                setTime = event.eventTime
            }
            if riseTime != nil, setTime != nil {
                pairs.append((riseTime, setTime))
                riseTime = nil
                setTime = nil
            }
        }
        let immutablePairs = pairs
        return immutablePairs
    }

    private func drawTideLevel(
        _ baseSeconds: TimeInterval, _ xratio: CGFloat, _ yoffset: CGFloat, _ yratio: CGFloat,
        _ height: CGFloat
    ) -> some View {
        let intervalsForDay: [SDTideInterval] = tideData.intervals(
            from: Date(timeIntervalSince1970: baseSeconds), forHours: tideData.hoursToPlot()
        )
        var path = Path { tidePath in
            for tidePoint: SDTideInterval in intervalsForDay {
                let minute =
                    Int(tidePoint.time.timeIntervalSince1970 - baseSeconds) / ChartConstants.secondsPerMinute
                let point = CGPoint(
                    x: CGFloat(minute) * xratio, y: yoffset - CGFloat(tidePoint.height) * yratio
                )
                if minute == 0 {
                    tidePath.move(to: point)
                } else {
                    tidePath.addLine(to: point)
                }
            }
        }

        // closes the path so it can be filled
        let lastMinute =
            Int(intervalsForDay.last!.time.timeIntervalSince1970 - baseSeconds)
                / ChartConstants.secondsPerMinute
        path.addLine(to: CGPoint(x: CGFloat(lastMinute) * xratio, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))

        // fill in the tide level curve
        return path.fill(.linearGradient(.init(colors: [.IndigoFlowerGrey, .WhitePlumGrey]), startPoint: .top, endPoint: .bottom))
    }
    
    private func drawTideLevelAsChart(
        _ baseSeconds: TimeInterval, _ dim: ChartDimensions
    ) -> some View {
        let intervalsForDay: [SDTideInterval] = tideData.intervals(
            from: Date(timeIntervalSince1970: baseSeconds), forHours: tideData.hoursToPlot()
        )
        let idIntervals = intervalsForDay.map { WithID(value: $0) }
        
        let max = Double(truncating: tideData.highestTide)
        
        return Chart {
            Plot {
                ForEach(getDaylightPairs()) { withId in
                    let (rise, set) = withId.value
                    if rise != tideData.startTime {
                        AreaMark(x: .value("Time", rise - 60 * 15), y: .value("Intensity", 0), series: .value("Astral Body", "Sun"))
                            .foregroundStyle(.yellow.opacity(0.3))
                            .interpolationMethod(.linear)
                    }
                    AreaMark(x: .value("Time", rise + 60 * 15), y: .value("Intensity", max), series: .value("Astral Body", "Sun"))
                            .foregroundStyle(.yellow.opacity(0.3))
                            .interpolationMethod(.linear)
                    AreaMark(x: .value("Time", set - 60 * 15), y: .value("Intensity", max), series: .value("Astral Body", "Sun"))
                    if set != tideData.stopTime {
                        AreaMark(x: .value("Time", set + 60 * 15), y: .value("Intensity", 0), series: .value("Astral Body", "Sun"))
                    }
//                    RectangleMark(xStart: .value("Time", rise), xEnd: .value("Time", set))
//                        .foregroundStyle(Color(red: 0.04, green: 0.27, blue: 0.61))
                }
                
            }
            
            Plot {
                ForEach(getMoonlightPairs()) { withId in
                    let (rise, set) = withId.value
                    if rise != tideData.startTime {
                        AreaMark(x: .value("Time", rise - 60 * 15), y: .value("Intensity", 0), series: .value("Astral Body", "Moon"))
                            .foregroundStyle(.gray.opacity(0.2))
                            .interpolationMethod(.catmullRom)
                    }
                    AreaMark(x: .value("Time", rise + 60 * 15), y: .value("Intensity", max), series: .value("Astral Body", "Moon"))
                            .foregroundStyle(.gray.opacity(0.2))
                            .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Time", set - 60 * 15), y: .value("Intensity", max), series: .value("Astral Body", "Moon"))
                    if set != tideData.stopTime {
                        AreaMark(x: .value("Time", set + 60 * 15), y: .value("Intensity", 0), series: .value("Astral Body", "Moon"))
                    }
                }
            }
            

            
            Plot {
                ForEach(idIntervals) { withId in
                    let tidePoint = withId.value
                    AreaMark(
                        x: .value("Time", tidePoint.time),
                        y: .value("Height", tidePoint.height))
                    .foregroundStyle(
                        .linearGradient(
                            .init(
                                colors: [.IndigoFlowerGrey.opacity(0.8), .WhitePlumGrey.opacity(0.8)]),
                                startPoint: .top,
                                endPoint: .bottom
                        )
                    )
                }
            }
            
            if let hoveredDate = selectedDate {
                if let closest = intervalsForDay.sorted(by: { left, right in
                    let leftDelta = left.time.distance(to: hoveredDate).magnitude
                    let rightDelta = right.time.distance(to: hoveredDate).magnitude
                    return leftDelta < rightDelta
                }).first {
                    RuleMark(x: .value("Time", closest.time))
                        .foregroundStyle(.white.opacity(0.8))
                    PointMark(x: .value("Time", closest.time), y: .value("Height", closest.height))
                        .symbolSize(20)
                        .foregroundStyle(.white)
                }
            }
        }
        .chartOverlay { proxy in
            #if os(watchOS)
            #else
            Color.clear
                .onContinuousHover { phase in
                    switch phase {
                    case let .active(location):
                        selectedDate = proxy.value(atX: location.x, as: Date.self)
                    case .ended:
                        selectedDate = nil
                    }
                }
            #endif
        }
        .chartYScale(domain: Float(dim.ymin)...Float(dim.ymax))
        
        
//        var path = Path { tidePath in
//            for tidePoint: SDTideInterval in intervalsForDay {
//                let minute =
//                    Int(tidePoint.time.timeIntervalSince1970 - baseSeconds) / ChartConstants.secondsPerMinute
//                let point = CGPoint(
//                    x: CGFloat(minute) * xratio, y: yoffset - CGFloat(tidePoint.height) * yratio
//                )
//                if minute == 0 {
//                    tidePath.move(to: point)
//                } else {
//                    tidePath.addLine(to: point)
//                }
//            }
//        }
//
//        // closes the path so it can be filled
//        let lastMinute =
//            Int(intervalsForDay.last!.time.timeIntervalSince1970 - baseSeconds)
//                / ChartConstants.secondsPerMinute
//        path.addLine(to: CGPoint(x: CGFloat(lastMinute) * xratio, y: height))
//        path.addLine(to: CGPoint(x: 0, y: height))
//
//        // fill in the tide level curve
//        let tideColor = Color(red: 0, green: 1, blue: 1).opacity(0.7)
//        return path.fill(tideColor)
    }

    private func drawMoonlight(_ baseSeconds: TimeInterval, _ xratio: CGFloat, _ height: CGFloat)
        -> some View
    {
        return Path { path in
            let moonEvents: [SDTideEvent] = tideData.moonriseMoonsetEvents
            let moonPairs: [(Date, Date)] = pairRiseAndSetEvents(
                moonEvents, riseEventType: .moonrise, setEventType: .moonset
            )
            for (rise, set) in moonPairs {
                let moonriseMinutes =
                    Int(rise.timeIntervalSince1970 - baseSeconds) / ChartConstants.secondsPerMinute
                let moonsetMinutes =
                    Int(set.timeIntervalSince1970 - baseSeconds) / ChartConstants.secondsPerMinute
                let rect = CGRect(
                    x: CGFloat(moonriseMinutes) * xratio, y: 0,
                    width: CGFloat(moonsetMinutes) * xratio - CGFloat(moonriseMinutes) * xratio,
                    height: height
                )
                path.addRect(rect)
            }
        }
        .fill(Color(red: 1, green: 1, blue: 1).opacity(0.2))
    }
    
    private func getMoonlightPairs() -> [WithID<(Date, Date)>] {
        let moonEvents: [SDTideEvent] = tideData.moonriseMoonsetEvents
        let moonPairs: [(Date, Date)] = pairRiseAndSetEvents(
            moonEvents, riseEventType: .moonrise, setEventType: .moonset
        )
        return moonPairs.map { WithID(value: $0) }
    }
    
    private func getDaylightPairs() -> [WithID<(Date, Date)>] {
        let sunEvents: [SDTideEvent] = tideData.sunriseSunsetEvents
        let sunPairs: [(Date, Date)] = pairRiseAndSetEvents(
            sunEvents, riseEventType: .sunrise, setEventType: .sunset
        )
        return sunPairs.map { WithID(value: $0) }
    }

    private func drawDaylight(_ baseSeconds: TimeInterval, _ xratio: CGFloat, _ height: CGFloat)
        -> some View
    {
        let sunEvents: [SDTideEvent] = tideData.sunriseSunsetEvents
        let sunPairs: [(Date, Date)] = pairRiseAndSetEvents(
            sunEvents, riseEventType: .sunrise, setEventType: .sunset
        )
        return Path { path in
            for (rise, set) in sunPairs {
                let sunriseMinutes =
                    Int(rise.timeIntervalSince1970 - baseSeconds) / ChartConstants.secondsPerMinute
                let sunsetMinutes =
                    Int(set.timeIntervalSince1970 - baseSeconds) / ChartConstants.secondsPerMinute
                let rect = CGRect(
                    x: CGFloat(sunriseMinutes) * xratio, y: 0,
                    width: CGFloat(sunsetMinutes) * xratio - CGFloat(sunriseMinutes) * xratio, height: height
                )
                path.addRect(rect)
            }
        }
        .fill(Color(red: 0.04, green: 0.27, blue: 0.61))
    }

    private func drawBaseline(_ dim: ChartDimensions)
        -> some View
    {
        let proportionalThickness = 0.015 * dim.height
        let thickness =
            proportionalThickness <= maxZeroThickness ? proportionalThickness : maxZeroThickness
        return Path { baselinePath in
            baselinePath.move(to: CGPoint(x: CGFloat(dim.xmin), y: CGFloat(dim.yoffset)))
            baselinePath.addLine(
                to: CGPoint(x: CGFloat(dim.xmax) * CGFloat(dim.xratio), y: CGFloat(dim.yoffset)))
        }
        .stroke(Color.white, lineWidth: thickness)
    }

    var body: some View {
        return GeometryReader { proxy in
            let dim = calculateDimensions(proxy, tideData: tideData, percentHeight: self.percentHeight)

            let day = tideData.startTime!
            let baseSeconds: TimeInterval = day.timeIntervalSince1970

            Rectangle()
                .fill(Color.black)
//            drawDaylight(baseSeconds, dim.xratio, dim.height)
//            drawMoonlight(baseSeconds, dim.xratio, dim.height)
            drawTideLevelAsChart(baseSeconds, dim)
            if showZero && dim.height >= dim.yoffset {
                drawBaseline(dim)
            }
        }
    }
}

struct WithID<T> : Identifiable {
    let value: T
    let id = UUID()
}
