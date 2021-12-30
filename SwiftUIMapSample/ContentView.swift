//
//  ContentView.swift
//  SwiftUIMapSample
//
//  Created by hiraoka on 2021/12/31.
//

import SwiftUI
import MapKit
import Combine

struct ContentView: View {

    @StateObject private var service: LocalSearchService = .init()

    var body: some View {
        NavigationView {

            Map(coordinateRegion: $service.boundingRegion, annotationItems: service.results) { item in
                MapMarker(coordinate: item.placemark.coordinate, tint: Color.pink)
            }
            .edgesIgnoringSafeArea([.horizontal, .bottom])
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(text: $service.searchQuery) {
            ForEach(service.suggestions) { suggestion in
                Button {
                    Task { await service.searchBySuggestion(suggestion) }
                } label: {
                    VStack(alignment: .leading) {
                        Text(suggestion.title)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption)
                        }
                    }
                }
                .searchCompletion(suggestion.title)
            }
        }
        .onSubmit(of: .search) {
            Task { await service.searchByQuery() }
        }
    }
}

final class LocalSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var results: [MKMapItem] = []
    @Published var boundingRegion: MKCoordinateRegion = MKCoordinateRegion(.world)

    private let completer: MKLocalSearchCompleter = .init()
    private var cancellable: AnyCancellable?

    override init() {
        super.init()
        cancellable = $searchQuery.assign(to: \.queryFragment, on: self.completer)
        completer.delegate = self
    }

    func searchBySuggestion(_ suggestion: MKLocalSearchCompletion) async {
        let request: MKLocalSearch.Request = .init(completion: suggestion)
        await search(using: request)
    }

    func searchByQuery() async {
        let request: MKLocalSearch.Request = .init()
        request.naturalLanguageQuery = searchQuery
        await search(using: request)
    }

    private func search(using request: MKLocalSearch.Request) async {
        let localSearch: MKLocalSearch = .init(request: request)
        do {
            let response = try await localSearch.start()
            results = response.mapItems
            if let location = response.mapItems.first?.placemark {
                boundingRegion = MKCoordinateRegion(center: location.coordinate,
                                                    latitudinalMeters: 12_00,
                                                    longitudinalMeters: 12_00)
            }
        } catch {
            print(error)
        }
    }

    // MARK: MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.suggestions = completer.results
    }
}

extension MKLocalSearchCompletion: Identifiable {}
extension MKMapItem: Identifiable {}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

