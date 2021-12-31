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
    @State private var error: Error?

    var body: some View {
        NavigationView {
            VStack {
                if let error = error?.localizedDescription {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Map(coordinateRegion: $service.boundingRegion, annotationItems: service.results) { item in
                    MapMarker(coordinate: item.placemark.coordinate, tint: Color.pink)
                }
                .edgesIgnoringSafeArea([.horizontal, .bottom])
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(text: $service.searchQuery) {
            ForEach(service.suggestions) { suggestion in
                Button {
                    Task {
                        do {
                            try await service.searchBySuggestion(suggestion)
                        } catch {
                            self.error = error
                        }
                    }
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
            Task {
                do {
                    try await service.searchByQuery()
                } catch {
                    self.error = error
                }
            }
        }
    }
}

final class LocalSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []
    @Published private(set) var results: [MKMapItem] = []
    @Published var boundingRegion: MKCoordinateRegion = MKCoordinateRegion(.world)

    private let completer: MKLocalSearchCompleter = .init()
    private var cancellable: AnyCancellable?

    override init() {
        super.init()
        cancellable = $searchQuery.assign(to: \.queryFragment, on: self.completer)
        completer.delegate = self
    }

    func searchBySuggestion(_ suggestion: MKLocalSearchCompletion) async throws {
        let request: MKLocalSearch.Request = .init(completion: suggestion)
        try await search(using: request)
    }

    func searchByQuery() async throws {
        let request: MKLocalSearch.Request = .init()
        request.naturalLanguageQuery = searchQuery
        try await search(using: request)
    }

    private func search(using request: MKLocalSearch.Request) async throws {
        let localSearch: MKLocalSearch = .init(request: request)
        let response = try await localSearch.start()
        results = response.mapItems
        if let location = response.mapItems.first?.placemark {
            boundingRegion = MKCoordinateRegion(center: location.coordinate,
                                                latitudinalMeters: 12_00,
                                                longitudinalMeters: 12_00)
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

