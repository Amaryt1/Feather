//
//  Persistence.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import Combine
import CoreData
import Foundation
import OSLog

// MARK: - Storage
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer
	
    enum LoadState: Equatable { case waiting, loading, ready, failed(String) }
    @Published private(set) var state: LoadState = .waiting
    private let hasModel: Bool

    init(inMemory: Bool = false, modelOverride: URL? = nil, storeURL: URL? = nil) {
        let bundle = Bundle(for: Storage.self)
        let modelURL = modelOverride ?? bundle.url(forResource: "Feather", withExtension: "momd")
            ?? bundle.url(forResource: "Feather", withExtension: "mom")
        let model = modelURL.flatMap { NSManagedObjectModel(contentsOf: $0) }
        hasModel = model != nil
        // Keep the recovery UI constructible even if an incorrectly packaged IPA lost its model.
        container = NSPersistentContainer(name: "Feather", managedObjectModel: model ?? NSManagedObjectModel())
        if let description = container.persistentStoreDescriptions.first {
            if let storeURL { description.url = storeURL }
            if inMemory { description.type = NSInMemoryStoreType; description.url = nil }
            description.shouldAddStoreAsynchronously = true
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    @MainActor func load() {
        switch state { case .ready, .loading: return; default: break }
        guard hasModel else {
            state = .failed("نموذج قاعدة البيانات مفقود من حزمة التطبيق. تحقق من ملف IPA.")
            return
        }
        state = .loading
        container.loadPersistentStores { _, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    Logger(subsystem: "Feather", category: "Startup").error("Store load failed: \(error.domain, privacy: .public) \(error.code)")
                    self.state = .failed("تعذّر فتح المكتبة. لم تُحذف بياناتك. (\(error.domain) \(error.code))")
                } else {
                    self.state = .ready
                }
            }
        }
    }

	var context: NSManagedObjectContext {
		container.viewContext
	}
	
	func saveContext() {
		DispatchQueue.main.async {
			if self.context.hasChanges {
				try? self.context.save()
			}
		}
	}
	
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: (request as? NSFetchRequest<NSFetchRequestResult>)!)
		_ = try? context.execute(deleteRequest)
	}
	
	func countContent<T: NSManagedObject>(for type: T.Type) -> String {
		let request = T.fetchRequest()
		return "\((try? context.count(for: request)) ?? 0)"
	}

}
