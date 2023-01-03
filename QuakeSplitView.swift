//
//  QuakeSplitView.swift
//  Earthquakes
//
//  Created by Creo Innovare on 1/2/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import SwiftUI
import CoreData

struct QuakeSplitView: View {
    var quakesProvider: QuakesProvider = .shared
    
    @AppStorage("lastUpdated")
    private var lastUpdated = Date.distantFuture.timeIntervalSince1970
    
    @FetchRequest(sortDescriptors: [SortDescriptor(\.time, order: .reverse)])
    private var quakes: FetchedResults<Quake>
    
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    @State private var selectMode: SelectMode = .inactive
    #endif
    @State private var selection: Set<String> = []
    @State private var isLoading = false
    @State private var error: QuakeError?
    @State private var hasError = false
    
    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                ForEach(quakes, id: \.code) { quake in
                    NavigationLink(destination: QuakeDetail(quake: quake)) {
                        QuakeRow(quake: quake)
                    }
                }
                .onDelete(perform: deleteQuakes)
            }
            .listStyle(SidebarListStyle())
            .navigationTitle(title)
            .toolbar(content: toolbarContent)
            #if os(iOS)
            .environment(\.editMode, $editMode)
            .refreshable {
                await fetchQuakes()
            }
            #else
            .frame(minWidth: 320)
            #endif

            EmptyView()
        } // end NavigationStack
        
    } // end View
}

extension QuakeSplitView {
    var title: String {
        #if os(iOS)
        if selectMode.isActive || selection.isEmpty {
            return "Earthquakes"
        } else {
            return "\(selection.count) Selected"
        }
        #else
        return "Earthquakes"
        #endif
    }

    private func deleteQuakes(at offsets: IndexSet) {
        let objectIDs = offsets.map { quakes[$0].objectID }
        quakesProvider.deleteQuakes(identifiedBy: objectIDs)
        selection.removeAll()
    }

    private func deleteQuakes(for codes: Set<String>) async {
        do {
            let quakesToDelete = quakes.filter { codes.contains($0.code) }
            try await quakesProvider.deleteQuakes(quakesToDelete)
        } catch {
            self.error = error as? QuakeError ?? .unexpectedError(error: error)
            self.hasError = true
        }
        selection.removeAll()
        #if os(iOS)
        editMode = .inactive
        #endif
    }

    private func fetchQuakes() async {
        isLoading = true
        do {
            try await quakesProvider.fetchQuakes()
            lastUpdated = Date().timeIntervalSince1970
        } catch {
            self.error = error as? QuakeError ?? .unexpectedError(error: error)
            self.hasError = true
        }
        isLoading = false
    }
}

// MARK: Toolbar Content

extension QuakeSplitView {
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        #if os(iOS)
        toolbarContent_iOS()
        #else
        toolbarContent_macOS()
        #endif
    }

    #if os(iOS)
    @ToolbarContentBuilder
    private func toolbarContent_iOS() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if editMode == .active {
                SelectButton(mode: $selectMode) {
                    if selectMode.isActive {
                        selection = Set(quakes.map { $0.code })
                    } else {
                        selection = []
                    }
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton(editMode: $editMode) {
                selection.removeAll()
                editMode = .inactive
                selectMode = .inactive
            }
        }

        ToolbarItemGroup(placement: .bottomBar) {
            RefreshButton {
                Task {
                    await fetchQuakes()
                }
            }
            .disabled(isLoading || editMode == .active)

            Spacer()
            ToolbarStatus(
                isLoading: isLoading,
                lastUpdated: lastUpdated,
                quakesCount: quakes.count
            )
            Spacer()

            if editMode == .active {
                DeleteButton {
                    Task {
                        await deleteQuakes(for: selection)
                    }
                }
                .disabled(isLoading || selection.isEmpty)
            }
        }
    }
    #else
    @ToolbarContentBuilder
    private func toolbarContent_macOS() -> some ToolbarContent {
        ToolbarItemGroup(placement: .status) {
            ToolbarStatus(
                isLoading: isLoading,
                lastUpdated: lastUpdated,
                quakesCount: quakes.count
            )
        }

        ToolbarItemGroup(placement: .navigation) {
            RefreshButton {
                Task {
                    await fetchQuakes()
                }
            }
            .disabled(isLoading)
            Spacer()
            DeleteButton {
                Task {
                    await deleteQuakes(for: selection)
                }
            }
            .disabled(isLoading || selection.isEmpty)
        }
    }
    #endif
}


struct QuakeSplitView_Previews: PreviewProvider {
    static var previews: some View {
        QuakeSplitView()
    }
}
