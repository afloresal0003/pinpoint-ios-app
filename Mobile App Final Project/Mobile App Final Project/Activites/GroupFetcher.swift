//
//  GroupFetcher.swift
//  Mobile App Final Project
//
//  Created by Anthony Flores-Alvarez on 12/1/24.
//

import FirebaseFirestore

class GroupFetcher: ObservableObject {
    @Published var group: Group?
    private var db = Firestore.firestore()

    func fetchGroup(by groupId: String) {
        db.collection("groups").document(groupId).getDocument { (document, error) in
            if let document = document, document.exists {
                do {
                    let group = try document.data(as: Group.self)
                    DispatchQueue.main.async {
                        self.group = group // Update the state on the main thread
                    }
                } catch {
                    print("Error decoding group: \(error.localizedDescription)")
                }
            } else {
                print("Group not found or error fetching document: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}
