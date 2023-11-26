//
//  TVContentView.swift
//  SwiftTides
//
//  Created by Michael Parlee on 3/21/21.
//

import SwiftUI

struct TVContentView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.appStateInteractor) private var appStateInteractor: AppStateInteractor

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var config: ConfigHelper

    @State private var isPopoverShowing = false
    @State private var showingFavorites = false

    @State private var isFirstLaunch = true
    @State private var pageIndex: Int = 0
    @State private var selectedTideModel: SingleDayTideModel? = nil

    @GestureState private var translation: CGFloat = 0

    @State private var displayMonth = Calendar.current.component(.month, from: Date()) {
        didSet {
            backgroundRefreshTides()
        }
    }

    @State private var displayYear = Calendar.current.component(.year, from: Date())
    @State private var calculating = false

    fileprivate let monthDateFormatter = DateFormatter()

    var body: some View {
        VStack {
            if let tideData = selectedTideModel?.tideDataToChart {
                HStack {
                    Button(action: { goPrev() }) {
                        Image(systemName: "arrow.left")
                    }

                    titleView()

                    Button(action: { goNext() }) {
                        Image(systemName: "arrow.right")
                    }
                }.focusSection()

                ChartView(tide: tideData, background: .clear)
            } else if calculating {
                ProgressView {
                    Text("Reticulating splines...")
                }
            }
        }
        .onAppear {
            isFirstLaunch = false
            backgroundRefreshTides()
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder func titleView() -> some View {
        if let tideData = selectedTideModel?.tideDataToChart {
            VStack {
                Text(tideData.shortLocationName).font(.headline)
                Text(tideData.startTime.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
            }
        }
    }

    func go(dayDelta: Int) {
        if let current = selectedTideModel {
            let prevDay = Calendar.current.date(byAdding: .day, value: dayDelta, to: current.day)
            if let prev = appState.calendarTides.first(where: {
                $0.day == prevDay
            }) {
                selectedTideModel = prev
            } else {
                // TODO: move month & refresh
            }
        }
    }

    func goPrev() {
        go(dayDelta: -1)
    }

    func goNext() {
        go(dayDelta: 1)
    }

    fileprivate func backgroundRefreshTides() {
        calculating = true
        refreshTides()
    }

    fileprivate func refreshTides() {
        DispatchQueue.global(qos: .userInteractive).async {
            let tides = appStateInteractor.calculateCalendarTides(
                appState: appState, settings: appState.config.settings, month: displayMonth,
                year: displayYear
            )
            DispatchQueue.main.sync {
                appState.calendarTides = tides
                calculating = false
                if selectedTideModel == nil {
                    selectedTideModel = tides.first {
                        $0.day == Date().startOfDay()
                    }
                } else if displayMonth == Calendar.current.component(.month, from: Date()) {
                    if displayMonth != Calendar.current.component(.month, from: selectedTideModel!.day) {
                        selectedTideModel = tides.first {
                            $0.day == Date().startOfDay()
                        }
                    } else if displayMonth == Calendar.current.component(.month, from: selectedTideModel!.day) {
                        selectedTideModel = tides.first {
                            $0.tideDataToChart.startTime == selectedTideModel?.tideDataToChart.startTime
                        }
                    }
                } else if displayMonth == Calendar.current.component(.month, from: selectedTideModel!.day) {
                    selectedTideModel = tides.first {
                        $0.tideDataToChart.startTime == selectedTideModel?.tideDataToChart.startTime
                    }
                }
            }
        }
    }
}
