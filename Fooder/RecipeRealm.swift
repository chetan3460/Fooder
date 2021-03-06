//
//  RecipeRealm.swift
//  Fooder
//
//  Created by Vladimir on 21.11.16.
//  Copyright © 2016 Vladimir Ageev. All rights reserved.
//

import SwiftyJSON
import RealmSwift

class RecipeRealm: Object{
   dynamic var id: Int = 0
   dynamic var vegeterian: Bool = false
   dynamic var  vegan: Bool = false
   dynamic var title: String = " "
   dynamic var imageURL: String = " "
   var ingridients = List<IngridientRealm>()
   dynamic var instructions: String?
   dynamic var readyInMinutes: Double = 0
   dynamic var servings: Int = 0
   dynamic var isFavorite = false
   dynamic var isCooked = false
   dynamic var isInList = false
    
   var extendedInstructions: [String]{
        get{
            return backupStrings.map { $0.stringValue }
        }
        set{
            backupStrings.removeAll()
            backupStrings.append(objectsIn: newValue.map({ RealmString(value: [$0]) }))
        }
    }
    
    private let backupStrings = List<RealmString>()
    convenience init(data: Recipe){
        self.init()
        
        for item in data.ingridients{
            if let objectInRealm = realm?.object(ofType: IngridientRealm.self, forPrimaryKey: item.id){
                self.ingridients.append(objectInRealm)
            }
            else{
                self.ingridients.append(IngridientRealm(data: item))
            }
            
        }
        
        self.id = data.id
        self.vegeterian = data.vegeterian
        self.vegan = data.vegan
        self.title = data.title
        self.imageURL = data.imageURL
        self.instructions = data.instructions
        self.readyInMinutes = data.readyInMinutes
        self.servings = data.servings
        self.extendedInstructions = data.extendedInstructions
    }
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    override static func ignoredProperties() -> [String] {
        return ["extendedInstructions"]
    }
}


class RealmString: Object {
    dynamic var stringValue = ""
}
