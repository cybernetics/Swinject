/*:
# Swinject Sample for iOS
*/

import Swinject

/*:
## Basic Use
*/

protocol AnimalType {
    var name: String? { get }
    func sound() -> String
}

class Cat: AnimalType {
    let name: String?
    
    init(name: String?) {
        self.name = name
    }
    
    func sound() -> String {
        return "Meow!"
    }
}

protocol PersonType {
    func play() -> String
}

class PetOwner: PersonType {
    let pet: AnimalType
    
    init(pet: AnimalType) {
        self.pet = pet
    }
    
    func play() -> String {
        let name = pet.name ?? "someone"
        return "I'm playing with \(name). \(pet.sound())"
    }
}

// Create a container and register service and component pairs.
let container = Container()
container.register(AnimalType.self) { _ in Cat(name: "Mimi") }
container.register(PersonType.self) { r in PetOwner(pet: r.resolve(AnimalType.self)!) }

// The person is resolved to a PetOwner with a Cat.
let person = container.resolve(PersonType.self)!
print(person.play())

/*:
## Named Registration
*/

class Dog: AnimalType {
    let name: String?
    
    init(name: String?) {
        self.name = name
    }
    
    func sound() -> String {
        return "Bow wow!"
    }
}

// Add more registrations to the container already containing the PetOwner with the Cat.
container.register(AnimalType.self, name: "dog") { _ in Dog(name: "Hachi") }
container.register(PersonType.self, name: "doggy") { r in PetOwner(pet: r.resolve(AnimalType.self, name: "dog")!) }

// Resolve the service with the registration name to differentiate from the cat owner.
let doggyPerson = container.resolve(PersonType.self, name:"doggy")!
print(doggyPerson.play())

/*:
## Injection Patterns
*/

class InjectablePerson: PersonType {
    var pet: AnimalType? {
        didSet {
            log = "Injected by property."
        }
    }
    var log = ""
    
    init() { }
    
    init(pet: AnimalType) {
        self.pet = pet
        log = "Injected by initializer."
    }
    
    func setPet(pet: AnimalType) {
        self.pet = pet
        log = "Injected by method."
    }
    
    func play() -> String {
        return log
    }
}

// Initializer injection
container.register(PersonType.self, name: "initializer") { r in
    InjectablePerson(pet: r.resolve(AnimalType.self)!)
}

let initializerInjection = container.resolve(PersonType.self, name:"initializer")!
print(initializerInjection.play())

// Property injection 1 (in the component factory)
container.register(PersonType.self, name: "property1") { r in
    let person = InjectablePerson()
    person.pet = r.resolve(AnimalType.self)
    return person
}

let propertyInjection1 = container.resolve(PersonType.self, name:"property1")!
print(propertyInjection1.play())

// Property injection 2 (in the initCompleted callback)
container.register(PersonType.self, name: "property2") { _ in InjectablePerson() }
    .initCompleted { r, p in
        let injectablePerson = p as! InjectablePerson
        injectablePerson.pet = r.resolve(AnimalType.self)
    }

let propertyInjection2 = container.resolve(PersonType.self, name:"property2")!
print(propertyInjection2.play())

// Method injection 1 (in the component factory)
container.register(PersonType.self, name: "method1") { r in
    let person = InjectablePerson()
    person.setPet(r.resolve(AnimalType.self)!)
    return person
}

let methodInjection1 = container.resolve(PersonType.self, name:"method1")!
print(methodInjection1.play())

// Method injection 2 (in the initCompleted callback)
container.register(PersonType.self, name: "method2") { _ in InjectablePerson() }
    .initCompleted { r, p in
        let injectablePerson = p as! InjectablePerson
        injectablePerson.setPet(r.resolve(AnimalType.self)!)
    }

let methodInjection2 = container.resolve(PersonType.self, name:"method2")!
print(methodInjection2.play())

/*:
## Circular Dependency
*/

internal protocol ParentType: AnyObject { }
internal protocol ChildType: AnyObject { }

internal class Mother: ParentType {
    let child: ChildType?
    
    init(child: ChildType?) {
        self.child = child
    }
}

internal class Daughter: ChildType {
    weak var parent: ParentType?
}

// Use initCompleted callback to set the circular dependency to avoid infinite recursion.
container.register(ParentType.self) { r in Mother(child: r.resolve(ChildType.self)!) }
container.register(ChildType.self) { _ in Daughter() }
    .initCompleted { r, c in
        let daughter = c as! Daughter
        daughter.parent = r.resolve(ParentType.self)
    }

let mother = container.resolve(ParentType.self) as! Mother
let daughter = mother.child as! Daughter

// The mother and daughter are referencing each other.
print(mother === daughter.parent)

/*:
## Injection with Arguments
*/

class Horse: AnimalType {
    let name: String?
    var running = false
    
    init(name: String, running: Bool) {
        self.name = name
        self.running = running
    }
    
    func sound() -> String {
        return "Whinny!"
    }
}

// The factory closure can take arguments.
// Note that the container already has an AnimalType without a registration name,
// but the factory with the arguments is recognized as a different registration to resolve.
container.register(AnimalType.self) { _, arg1, arg2 in Horse(name: arg1, running: arg2) }

// The arguments to the factory are specified on the resolution.
let horse = container.resolve(AnimalType.self, arg1: "Lucky", arg2: true) as! Horse
print(horse.name!)
print(horse.running)

/*:
## Self-binding
*/

class SelfieBoy {
    func takePhoto() -> String {
        return "Selfie!"
    }
}

// Register SelfieBoy as both service and component types.
container.register(SelfieBoy.self) { r in SelfieBoy() }

let selfieBoy = container.resolve(SelfieBoy.self)!
print(selfieBoy.takePhoto())

/*:
## Container Hierarchy
*/

let parentContainer = Container()
parentContainer.register(AnimalType.self, name: "cat") { _ in Cat(name: "Mimi") }

let childContainer = Container(parent: parentContainer)
childContainer.register(AnimalType.self, name: "dog") { _ in Dog(name: "Hachi") }

// The registration on the parent container is resolved on the child container.
let cat = childContainer.resolve(AnimalType.self, name: "cat")
print(cat != nil)

// The registration on the child container is not resolved on the parent container.
let dog = parentContainer.resolve(AnimalType.self, name: "dog")
print(dog == nil)

/*:
## Shared Singleton Container
*/

// The shared container can be used if it is ok to depend on the singleton container.
Container.defaultContainer.register(AnimalType.self) { _ in Cat(name: "Mew") }

let mew = Container.defaultContainer.resolve(AnimalType.self)!
print(mew.name!)

