//
//  SidebarView.swift
//  Data Inspector
//
//  Created by Axel Martinez on 13/11/24.
//

import SwiftUI
import SQLiteKit

struct SidebarView<T: SQLiteTable>: View {
    @EnvironmentObject var sqlManager: SQLiteManager
    
    @Binding var selection: T?
    
    @State private var dataObjects = [T]()
    @State private var error: SQLiteError? = nil
    @State private var showAlert = false
    
    var body: some View {
        VStack {
            List(selection: $selection) {
                switch(sqlManager.displayMode) {
                case .SwiftData:
                    if let models = dataObjects as? [Model], !models.isEmpty {
                        Section(header: Text("Models")) {
                            ForEach(models, id: \.self) { model in
                                HStack {
                                    Label(model.displayName, systemImage: "swiftdata")
                                    Spacer()
                                    Text("\(model.recordCount)")
                                }
                            }
                        }
                    }
                case .CoreData:
                    if let entities = dataObjects as? [Entity], !entities.isEmpty {
                        Section(header: Text("Entities")) {
                            ForEach(entities, id: \.self) { entity in
                                HStack {
                                    Label(entity.displayName, systemImage: "e.square")
                                    Spacer()
                                    Text("\(entity.recordCount)")
                                }
                            }
                        }
                    }
                default:
                    if !dataObjects.isEmpty {
                        Section(header: Text("Tables")) {
                            ForEach(dataObjects, id: \.self) { dataObject in
                                HStack {
                                    Label(dataObject.name, systemImage: "tablecells")
                                    Spacer()
                                    Text("\(dataObject.recordCount)")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        .alert(isPresented: $showAlert, error: error) { _ in
            Button("OK") {
                self.showAlert = false
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try opening a different file")
        }
        .onChange(of: sqlManager.openFileURL) { _,_ in
            Task(priority: .userInitiated) {
                do {
                    switch(sqlManager.displayMode) {
                    case .SwiftData:
                        if let models = try await self.sqlManager.getModels() as? [T] {
                            self.dataObjects = models
                        }
                        break
                    case .CoreData:
                        if let entities = try await self.sqlManager.getEntities() as? [T] {
                            self.dataObjects = entities
                        }
                        break
                    default:
                        if let tables = try await self.sqlManager.getTables() as? [T] {
                            self.dataObjects = tables
                        }
                        break
                    }
                    
                    self.selection = self.dataObjects.first
                } catch let error as SQLiteError {
                    self.error = error
                    self.showAlert = true
                }
            }
        }
    }
}

#Preview {
    @Previewable let manager = SQLiteManager()
    @Previewable @State var selection: Entity?
    
    SidebarView(selection: $selection).environmentObject(manager)
}
