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
import Charts
import SwiftUI

struct ChartView: View {
    @State private var selectedDateOther: Date?
    @State private var prevSelectedButton: Int?
    @FocusState private var selectedButton: Int?

    private let dateFormatter = DateFormatter()
    private let maxZeroThickness: CGFloat = 2

    private var showZero: Bool
    private var tideData: SDTide
    private var percentHeight: CGFloat
    private var background: Color

    @FocusState private var chartIsFocused: Bool

    init(tide: SDTide, showZero: Bool = true, percentHeight: CGFloat = 0.8, background: Color = .black) {
        tideData = tide
        dateFormatter.dateStyle = .full
        self.showZero = showZero
        self.percentHeight = percentHeight
        self.background = background
    }

    private var selectedDate: Date? {
        if let normal = selectedDateOther {
            return normal
        }

        if let percent = selectedButton {
            let total = Double(tideData.allIntervals.count)
            let ratio = Double(percent) / 100.0
            let closest = Int(total * ratio)
            if let interval = tideData.allIntervals[safe: closest] {
                return interval.time
            }
        }

        return nil
    }

    private var raisedButton: Int? {
        if let prev = prevSelectedButton {
            if selectedButton == nil {
                return prev
            }
        }
        return nil
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

        func closest(to: Date) -> SDTideInterval? {
            intervalsForDay.sorted(by: { left, right in
                let leftDelta = left.time.distance(to: to).magnitude
                let rightDelta = right.time.distance(to: to).magnitude
                return leftDelta < rightDelta
            }).first
        }

        return Chart {
            getMoonlightMarks()
            getSunlightMarks()

            Plot {
                ForEach(idIntervals) { withId in
                    let tidePoint = withId.value

                    // Visual style only - draw the gradient below the line
                    AreaMark(
                        x: .value("Time", tidePoint.time),
                        yStart: .value("Height", tidePoint.height),
                        yEnd: .value("", Float(dim.ymin))
                    )
                    .foregroundStyle(
                        .linearGradient(
                            .init(
                                colors: [.IndigoFlowerGrey.opacity(0.8), .WhitePlumGrey.opacity(0.4)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    .alignsMarkStylesWithPlotArea()
                    .accessibilityHidden(true) // This is visual only and repeats the line below.

                    LineMark(
                        x: .value("Time", tidePoint.time),
                        y: .value("Height", tidePoint.height)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            .init(
                                colors: [.IndigoFlowerGrey, .WhitePlumGrey]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .alignsMarkStylesWithPlotArea()
                    .lineStyle(.init(lineWidth: 4, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
            }

            getEventMarks()

            // If today, show now line & cover "past" with grey.
            let now = Date()
            if now.startOfDay() == tideData.startTime {
                getNowMark(now, closest: closest(to: now))
            }

            // If hovered / dragged, render the thumb.
            if let hoveredDate = selectedDate {
                if let interval = closest(to: hoveredDate) {
                    getHoveredMark(interval)
                }
            }
        }
        .chartYScale(domain: Float(dim.ymin) ... Float(dim.ymax))
        .chartXScale(domain: tideData.startTime ... tideData.stopTime)
        .chartXSelection(value: $selectedDateOther)
        .chartYAxis {
            getAxisMarks()
        }
        .chartOverlay { _ in
            #if os(tvOS)
                getFocusOverlay(idIntervals: idIntervals)
            #endif
        }.onChange(of: selectedButton) { prev, _ in
            prevSelectedButton = prev
        }
    }

    private func thumb() -> some View {
        return Circle()
            .fill(.white)
            .stroke(.black, lineWidth: 2.0)
            .frame(width: 20)
    }

    @AxisContentBuilder private func getAxisMarks() -> some AxisContent {
        AxisMarks(preset: .extended, position: .leading) { val in
            let y = val.as(Int.self)!
            AxisValueLabel("\(y) ft")
            if y == 0 {
                AxisGridLine(stroke: .init(lineWidth: 3))
            } else {
                AxisGridLine()
            }
        }
        AxisMarks(preset: .automatic, position: .trailing) { val in
            let y = val.as(Int.self)!
            AxisValueLabel("\(y) ft")
        }
    }

    private func getFocusOverlay(idIntervals: [WithID<SDTideInterval>]) -> some View {
        return HStack(alignment: .center, spacing: 5) {
            ForEach(0 ... 100, id: \.self) { num in
                if raisedButton == nil || raisedButton == num {
                    Text("\(num)")
                        .focusable()
                        .frame(width: 2, height: 2)
                        .focused($selectedButton, equals: num)
                        .opacity(0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .focusSection()
    }

    @ChartContentBuilder private func bolded(_ mark: PointMark) -> some ChartContent {
        mark
            .symbol {
                Circle()
                    .stroke(.black, lineWidth: 4)
                    .frame(width: 8)
            }
    }

    @ChartContentBuilder private func getEventMarks() -> some ChartContent {
        let events: [SDTideEvent] = tideData.events
        let eventsWithIds = events.map { WithID(value: $0) }
        Plot {
            ForEach(eventsWithIds) { event2 in
                let event = event2.value
                let mark = bolded(PointMark(x: .value("Time", event.eventTime), y: .value("Height", event.eventHeight)))
                switch event.eventType {
                case .min:
                    mark.annotation(content: { Text("L") })
                case .max:
                    mark.annotation(content: { Text("H") })
                default:
                    Plot {}
                }
            }
        }
    }

    @ChartContentBuilder private func getNowMark(_ now: Date, closest: SDTideInterval?) -> some ChartContent {
        RectangleMark(xStart: .value("", tideData.startTime), xEnd: .value("", now))
            .foregroundStyle(.gray.opacity(0.3))
            .accessibilityHidden(true)
        RuleMark(x: .value("Now", now))
            .foregroundStyle(.gray.opacity(0.8))
        if let interval = closest {
            bolded(PointMark(x: .value("", now), y: .value("", interval.height)))
        }
    }

    @ChartContentBuilder private func getHoveredMark(_ closest: SDTideInterval) -> some ChartContent {
        RuleMark(x: .value("Time", closest.time))
            .foregroundStyle(.white.opacity(0.8))
        PointMark(x: .value("Time", closest.time), y: .value("Height", closest.height))
            .symbol { thumb() }
            .foregroundStyle(.white)
            .annotation(position: .topTrailing, overflowResolution: .init(x: .fit(to: .chart))) {
                VStack(alignment: .leading) {
                    Text("\(closest.time.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .bold()
                        .fontDesign(.rounded)
                        .padding(.init(top: 4, leading: 6, bottom: 0, trailing: 4))
                    Text(Measurement(value: Double(closest.height), unit: UnitLength.feet).formatted())
                        .font(.headline)
                        .bold()
                        .fontDesign(.rounded)
                        .padding(.init(top: 0, leading: 6, bottom: 4, trailing: 4))
                }.foregroundStyle(.white)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerSize: CGSize(width: 4, height: 4)))
                    .padding(.init(top: 4, leading: 6, bottom: 0, trailing: 6))
                    .monospacedDigit()
            }
    }

    private func getAstralMarks<Y: Plottable>(
        pairs: [WithID<(Date, Date)>],
        foregroundStyle: some ShapeStyle,
        y: PlottableValue<Y>,
        fgSeries: String,
        bgSeries: String
    ) -> some ChartContent {
        func base(_ series: LineMark) -> some ChartContent {
            return series
                .foregroundStyle(foregroundStyle)
                .lineStyle(.init(lineWidth: 4, lineCap: .round))
                .interpolationMethod(.catmullRom(alpha: 2))
        }

        return Plot {
            ForEach(pairs) { withId in
                let fg = PlottableValue.value("Astral Body", "\(fgSeries) \(withId)")
                let bg = PlottableValue.value("Astral Body", "\(bgSeries) \(withId)")

                let (rise, set) = withId.value
                let riseAt = PlottableValue.value("Time", rise)
                let setAt = PlottableValue.value("Time", set)

                base(LineMark(x: riseAt, y: y, series: bg))
                    .blur(radius: 4)
                LineMark(x: setAt, y: y, series: bg)

                base(LineMark(x: riseAt, y: y, series: fg))
                LineMark(x: setAt, y: y, series: fg)
            }
        }
    }

    private func getSunlightMarks() -> some ChartContent {
        let max = Double(truncating: tideData.highestTide)
        let gradient = LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
        let y = PlottableValue.value("Intensity", max + 0.5)
        return getAstralMarks(pairs: getDaylightPairs(), foregroundStyle: gradient, y: y, fgSeries: "sun fg", bgSeries: "sun bg")
    }

    private func getMoonlightMarks() -> some ChartContent {
        let max = Double(truncating: tideData.highestTide)
        let gradient = LinearGradient(colors: [.white.opacity(0.8), .gray], startPoint: .leading, endPoint: .trailing)
        let y = PlottableValue.value("Intensity", max + 0.25)
        return getAstralMarks(pairs: getMoonlightPairs(), foregroundStyle: gradient, y: y, fgSeries: "moon fg", bgSeries: "moon bg")
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
                .fill(background)
//            drawDaylight(baseSeconds, dim.xratio, dim.height)
//            drawMoonlight(baseSeconds, dim.xratio, dim.height)
            drawTideLevelAsChart(baseSeconds, dim)
//            if showZero && dim.height >= dim.yoffset {
//                drawBaseline(dim)
//            }
        }
    }
}

struct WithID<T>: Identifiable {
    let value: T
    let id = UUID()
}
