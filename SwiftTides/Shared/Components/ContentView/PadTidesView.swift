//
//  PadPortraitLayout.swift
//  SwiftTides
//
//  Created by Michael Parlee on 4/10/21.
//

import SwiftUI

struct PadTidesView: View {
  @EnvironmentObject var appState: AppState
  @EnvironmentObject var config: ConfigHelper
  
  @State private var cursorLocation: CGPoint = .zero
  
  @Binding var pageIndex: Int
  @Binding var selectedTideDay: SingleDayTideModel?
  
  var body: some View {
    let dragGesture = DragGesture(minimumDistance: 0)
      .onChanged {
        self.cursorLocation = $0.location
      }
      .onEnded { _ in
        self.cursorLocation = .zero
      }

    let pressGesture = LongPressGesture(minimumDuration: 0.2)

    let pressDrag = pressGesture.sequenced(before: dragGesture)
    
    let headerWidth: CGFloat = 0.3
    let headerHeight: CGFloat = 1/15
    let chartWidth: CGFloat = 0.6
    let chartHeight: CGFloat = 1/4
    
    return GeometryReader { proxy in
      VStack {
        HStack(alignment: .top) {
          VStack {
            HeaderView(showsLocation: false)
              .frame(
                width: proxy.size.width * headerWidth,
                height: proxy.size.height * headerHeight
              )
              .padding()
            if let tideData = appState.tidesForDays[pageIndex] {
              if tideData.events != nil {
                TideEventsView(tide: tideData)
                  .padding(.bottom, 40)
              }
            }
          }
          .frame(height: proxy.size.height * chartHeight)
          .background(Image("background-gradient").resizable())
          .clipShape(RoundedRectangle(cornerRadius: 3.0))
          if let tideData = selectedTideDay?.tideDataToChart {
            ChartView(tide: tideData)
              .gesture(pressDrag)
              .modifier(LabeledChartViewModifier(tide: tideData, labelInset: 15))
              .modifier(
                InteractiveChartViewModifier(
                  tide: tideData, currentIndex: $pageIndex, cursorLocation: $cursorLocation))
              .modifier(
                LocationDateViewModifier(date: selectedTideDay?.day ?? Date())
              )
              .frame(
                width: proxy.size.width * chartWidth,
                height: proxy.size.height * chartHeight
              )
              .clipShape(RoundedRectangle(cornerRadius: 3.0))
          }
        }
        MonthView(selectedTideModel: $selectedTideDay)
      }
    }
  }
}

//struct PadPortraitLayout_Previews: PreviewProvider {
//    static var previews: some View {
//        PadPortraitView()
//    }
//}