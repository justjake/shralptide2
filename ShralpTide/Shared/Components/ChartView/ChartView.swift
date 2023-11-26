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
    enum Scale {
        case large
        case small
    }

    @State private var selectedDate: Date?
    @FocusState private var chartIsFocused: Bool

    private let dateFormatter = DateFormatter()
    private let maxZeroThickness: CGFloat = 2
    private let interactive: Bool
    private let scale: Scale

    private var showZero: Bool
    private var tideData: SDTide
    private var percentHeight: CGFloat
    private var background: Color

    init(tide: SDTide, showZero: Bool = true, percentHeight: CGFloat = 0.8, background: Color = .black, interactive: Bool = false, scale: Scale = .small) {
        tideData = tide
        dateFormatter.dateStyle = .full
        self.showZero = showZero
        self.percentHeight = percentHeight
        self.background = background
        self.interactive = interactive
        self.scale = scale
    }

    var body: some View {
        return GeometryReader { proxy in
            let dim = calculateDimensions(proxy, tideData: tideData, percentHeight: self.percentHeight)

            let day = tideData.startTime!
            let baseSeconds: TimeInterval = day.timeIntervalSince1970

            Rectangle().fill(background)
            drawTideLevelAsChart(baseSeconds, dim)
        }
    }

    var isToday: Bool {
        Date().startOfDay() == tideData.startTime
    }

    var swipeDelta: TimeInterval {
        let total = tideData.startTime.distance(to: tideData.stopTime)
        return total / 100
    }

    var defaultFocusedDate: Date {
        if isToday {
            Date()
        } else {
            tideData.startTime.midday()
        }
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
            if isToday {
                getNowMark(now, closest: closest(to: now))
            }

            // If hovered / dragged, render the thumb.
            if interactive {
                if let hoveredDate = selectedDate {
                    if let interval = closest(to: hoveredDate) {
                        #if os(tvOS)
                            if chartIsFocused {
                                getHoveredMark(interval)
                            }
                        #else
                            getHoveredMark(interval)
                        #endif
                    }
                }
            }
        }
        .chartYScale(domain: Float(dim.ymin) ... Float(dim.ymax))
        .chartXScale(domain: tideData.startTime ... tideData.stopTime)
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            getYAxisMarks()
        }
        .chartXAxis {
            getXAxisMarks()
        }
        #if os(tvOS)
        .onSwipeGesture(swipe: { onSwipe($0) }, pan: { onPan($0, dim: dim) })
        .focused($chartIsFocused)
        .onChange(of: chartIsFocused) { _, _ in
            if selectedDate == nil {
                if isToday {
                    selectedDate = Date()
                } else {
                    selectedDate = tideData.startTime.midday()
                }
            }
        }
        #endif
    }

    #if os(tvOS)
        private func onSwipe(_ swipe: UISwipeGestureRecognizer.Direction) {
            switch swipe {
            case .left:
                selectedDate = max((selectedDate ?? defaultFocusedDate) - swipeDelta, tideData.startTime)
            case .right:
                selectedDate = min((selectedDate ?? defaultFocusedDate) + swipeDelta, tideData.stopTime)
            default:
                ()
            }
        }

        private func onPan(_ gesture: UIPanGestureRecognizer, dim: ChartDimensions) {
            if !chartIsFocused {
                return
            }
            let dxdy = gesture.translation(in: nil)
            print("pan: translation \(dxdy), velocity: \(gesture.velocity(in: nil)), geo: \(dim.proxy.size)")
            let dPercent = dxdy.x / dim.proxy.size.width
            let secondsPerHalf = CGFloat(60 * 60 * 12)
            let centerpoint = Calendar.current.date(byAdding: .init(hour: 12), to: tideData.startTime)!
            let newDate = centerpoint + secondsPerHalf * dPercent
            selectedDate = newDate
        }
    #endif

    private func thumb() -> some View {
        Circle()
            .fill(.white)
            .stroke(.black, lineWidth: 2.0)
            .frame(width: 20)
    }

    @AxisContentBuilder private func getYAxisMarks() -> some AxisContent {
        if scale == .large {
            #if os(tvOS)
                AxisMarks(preset: .automatic, position: .leading) { val in
                    let y = val.as(Float.self)!
                    AxisValueLabel(y.formatFeet())
                        .font(.subheadline)
                    if y == 0 {
                        AxisGridLine(stroke: .init(lineWidth: 3))
                    } else {
                        AxisGridLine()
                    }
                }
            #endif
            AxisMarks(preset: .automatic, position: .trailing) { val in
                let y = val.as(Float.self)!
                AxisValueLabel(y.formatFeet())
                #if os(tvOS)
                    .font(.subheadline)
                #endif
            }
        }
    }

    @AxisContentBuilder private func getXAxisMarks() -> some AxisContent {
        if scale == .large {
            AxisMarks(preset: .extended, position: .bottom) { _ in
                AxisValueLabel()
                #if os(tvOS)
                    .font(.subheadline)
                #endif
                AxisGridLine()
            }
        }
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
                    mark.annotation {
                        if scale == .large {
                            HeightLabel(height: event.eventHeight, time: event.eventTime)
                        } else {
                            Text("L").font(.caption).fontDesign(.rounded)
                        }
                    }
                case .max:
                    mark.annotation(overflowResolution: .init(y: .fit(to: .chart)), content: {
                        if scale == .large {
                            HeightLabel(height: event.eventHeight, time: event.eventTime)
                        } else {
                            Text("H").font(.caption).fontDesign(.rounded)
                        }
                    })
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
                    Text(closest.height.formatFeet())
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
}

class MemoSlot<In: Equatable, Out> {
    enum State {
        case empty
        case memo(prevArgs: In, prevResult: Out)
    }

    var state: State = .empty

    func use(_ compute: () -> Out, _ args: In) -> Out {
        switch state {
        case .empty:
            let result = compute()
            state = .memo(prevArgs: args, prevResult: result)
            return result
        case let .memo(prevArgs, prevResult):
            if prevArgs == args {
                return prevResult
            }
            let result = compute()
            state = .memo(prevArgs: args, prevResult: result)
            return result
        }
    }
}

struct HeightLabel: View {
    let height: Float
    let time: Date

    let horizontalPadding: CGFloat = 6
    let verticalPadding: CGFloat = 3

    var formattedTime: String {
        time.formatted(date: .omitted, time: .shortened)
    }

    var formattedHeight: String {
        height.formatFeet()
    }

    var body: some View {
        return VStack {
            Text(formattedTime)
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.init(top: verticalPadding, leading: horizontalPadding, bottom: 0, trailing: horizontalPadding))
            Text(formattedHeight)
                .padding(.init(top: 0, leading: horizontalPadding, bottom: verticalPadding, trailing: horizontalPadding))
        }
        .fontDesign(.rounded)
        .font(.caption)
        .background(.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 4, height: 4)))
        .monospacedDigit()
    }
}

struct WithID<T>: Identifiable {
    let value: T
    let id = UUID()
}
