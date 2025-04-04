//
//  Persistence.swift
//  MirrorChild
//
//  Created by 赵嘉策 on 2025/4/3.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for preview
        let newUserProfile = UserProfile(context: viewContext)
        newUserProfile.name = "John Doe"
        newUserProfile.email = "john.doe@example.com"
        newUserProfile.createdAt = Date()
        
        let voiceSettings = VoiceSettings(context: viewContext)
        voiceSettings.accent = "American"
        voiceSettings.pitch = 1.0
        voiceSettings.speed = 1.0
        voiceSettings.voiceModel = "default"
        newUserProfile.voiceSettings = voiceSettings
        
        let conversation = Conversation(context: viewContext)
        conversation.date = Date()
        conversation.title = "First Conversation"
        conversation.userProfile = newUserProfile
        
        let userMessage = Message(context: viewContext)
        userMessage.content = "How do I make a phone call?"
        userMessage.isUserMessage = true
        userMessage.timestamp = Date().addingTimeInterval(-60)
        userMessage.conversation = conversation
        
        //Examples
        let assistantMessage = Message(context: viewContext)
        assistantMessage.content = "To make a phone call, tap on the green phone icon on your home screen. Then you can dial a number or select a contact."
        assistantMessage.isUserMessage = false
        assistantMessage.timestamp = Date()
        assistantMessage.conversation = conversation
        
        try? viewContext.save()
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MirrorChild")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - User Profile Management
    
    func saveUserProfile(name: String, email: String, appleUserId: String?) -> UserProfile {
        let viewContext = container.viewContext
        
        // Check if user profile already exists
        if let appleUserId = appleUserId, let existingProfile = fetchUserProfile(withAppleUserId: appleUserId) {
            existingProfile.name = name
            existingProfile.email = email
            try? viewContext.save()
            return existingProfile
        }
        
        // Create new profile
        let newProfile = UserProfile(context: viewContext)
        newProfile.name = name
        newProfile.email = email
        newProfile.appleUserId = appleUserId
        newProfile.createdAt = Date()
        
        // Create default voice settings
        let voiceSettings = VoiceSettings(context: viewContext)
        voiceSettings.accent = "Neutral"
        voiceSettings.pitch = 1.0
        voiceSettings.speed = 1.0
        voiceSettings.voiceModel = "default"
        newProfile.voiceSettings = voiceSettings
        
        try? viewContext.save()
        return newProfile
    }
    
    func fetchUserProfile(withAppleUserId appleUserId: String) -> UserProfile? {
        let viewContext = container.viewContext
        let fetchRequest: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "appleUserId == %@", appleUserId)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching user profile: \(error)")
            return nil
        }
    }
    
    // MARK: - Conversation Management
    
    func createConversation(forUserProfile userProfile: UserProfile, title: String) -> Conversation {
        let viewContext = container.viewContext
        
        let conversation = Conversation(context: viewContext)
        conversation.userProfile = userProfile
        conversation.title = title
        conversation.date = Date()
        
        try? viewContext.save()
        return conversation
    }
    
    func addMessage(toConversation conversation: Conversation, content: String, isUserMessage: Bool) -> Message {
        let viewContext = container.viewContext
        
        let message = Message(context: viewContext)
        message.content = content
        message.isUserMessage = isUserMessage
        message.timestamp = Date()
        message.conversation = conversation
        
        try? viewContext.save()
        return message
    }
    
    func fetchConversations(forUserProfile userProfile: UserProfile) -> [Conversation] {
        let viewContext = container.viewContext
        let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userProfile == %@", userProfile)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.date, ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching conversations: \(error)")
            return []
        }
    }
    
    func fetchMessages(forConversation conversation: Conversation) -> [Message] {
        let viewContext = container.viewContext
        let fetchRequest: NSFetchRequest<Message> = Message.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "conversation == %@", conversation)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Message.timestamp, ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching messages: \(error)")
            return []
        }
    }
}
