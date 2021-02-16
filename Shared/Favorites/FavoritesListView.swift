//
//  FavoritesView.swift
//  SwiftTides
//
//  Created by Michael Parlee on 1/11/21.
//

import SwiftUI
import ShralpTideFramework
import MapKit

struct FavoritesListView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var config: ConfigHelper
  @Environment(\.appStateInteractor) private var interactor: AppStateInteractor
  
  @Binding private var isShowing: Bool
  
  init(isShowing: Binding<Bool>) {
    self._isShowing = isShowing
  }
  
  var body: some View {
    UITableView.appearance().backgroundColor = .clear
    UITableViewCell.appearance().backgroundColor = .clear

    return ZStack {
      Image("background-gradient")
        .resizable()
      List {
        Section(footer: FavoritesListFooter()) {
          if appState.tides.count > 1 {
            ForEach (appState.tides, id: \.stationName) { (tide: SDTide) in
              FavoriteRow(tide: tide, isShowingFavorites: $isShowing)
            }
            .onDelete(perform: { (offsets: IndexSet) in
              let tideStation: SDTide = appState.tides[offsets.first!]
              if (config.settings.legacyMode) {
                interactor.removeFavoriteLegacyLocation(name: tideStation.stationName)
              } else {
                interactor.removeFavoriteStandardLocation(name: tideStation.stationName)
              }
              interactor.updateState(appState: appState, settings: config.settings)
            })
          } else {
            FavoriteRow(tide: appState.tides[0], isShowingFavorites: $isShowing)
          }
        }
        .listRowBackground(Color.clear)
      }
      .listStyle(GroupedListStyle())
    }
    .accentColor(.white)
    .ignoresSafeArea()
  }
}

enum ActiveSheet: Identifiable {
    case map, list
    
    var id: Int {
        hashValue
    }
}

struct FavoritesListFooter: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var config: ConfigHelper
  
  @State private var selectingFromMap = false
  @State private var selectingFromList = false
  @State private var centerCoordinate = CLLocationCoordinate2D()
  @State var activeSheet: ActiveSheet?

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.black.opacity(0.6))
      HStack {
        Button(action: { activeSheet = .map }) {
          Image(systemName: "location.fill")
            .font(.system(size: 18))
        }
        Spacer()
        Button(action: { activeSheet = .list }) {
          Image(systemName: "globe")
            .font(.system(size: 18))
        }
      }
      .padding()
      .sheet(item: $activeSheet) { item in
        switch item {
        case .map:
          MapSelectionView(centerCoordinate: $centerCoordinate, activeSheet: $activeSheet)
            .environmentObject(appState)
            .environmentObject(config)
        case .list:
          RegionSelectionView(title: "Select station", activeSheet: $activeSheet)
            .environmentObject(appState)
            .environmentObject(config)
        }
      }
    }
  }
}

