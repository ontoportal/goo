# _Graph Oriented Objects_ for Ruby  (Goo)

*Goo* is a Ruby library that provides ORM-alike capabilities to interact with [RDF](http://en.wikipedia.org/wiki/Resource_Description_Framework)/[SPARQL](http://en.wikipedia.org/wiki/SPARQL) backends. *Goo* provides a DSL for defining schemas for objects and controls how they get validated, serialized, saved and retrieved from the triplestore. Using RDF and SPARQL for large-scale applications creates challenges in terms of both scalability and technology adoption. We designed Goo with two main objectives:

- *Goo* abstracts SPARQL in a way that developers do not need to be SPARQL experts to efficiently handle large RDF graphs.

- *Goo* was initially design to serve [BioPortal](http://bioportal.bioontology.org/) growing REST traffic. BioPortal's REST API provides access to hundreds of millions of Biomedical artifacts. Scalability and efficiency is at the core of *Goo's* design.


## Schema Definitions (DSL)

###Basic Definitions

*Goo* models are defined by extending [Resource](/docs/Goo/Base/Resource) and providing one [model]() definition and [attribute]() definitions. The example below provides defines a `User` model with two attributes `username` and `email`. In this model:

```
require 'goo'

class User < Goo::Base::Resource
  model :user, name_with: :username
  attribute :username, enforce: [:existence, :unique]
  attribute :email, enforce: [:existence, :email]
end
```

- `:name_with` tells this object to take the value of the `username` attribute to generate a URI that uniquely identifies an instance. `:name_with` also accepts a lambda function for flexible naming policies, for example: 

```ruby
name_with: lambda { |u| RDF::URI.new("http:// .... /some/uri}" }
```

- `:enforce` is the option to establish validations at the attribute level. It accepts an array of elements. In this example there are three different validations:

    * `:existence` to force the attribute to hold a value. This attribute cannot be `nil`.

    * `:unique` to force the value of the attribute to be unique across all the instances of the same type.

    * `:email` to force the value of the attribute to be an string that is a valid email.


### Object Dependencies

With `:enforce` one can tell *Goo* that that attribute should hold instance values of other *Goo* type.  For instance, say that: _A user can be assigned one or many roles_ and the `Role` model looks like this:


```ruby
class Role < Goo::Base::Resource
  model :role, name_with: :code
  attribute :code, enforce: [:existence, :unique]
end
```

We now add a new attribute `:roles` in `User`. The `:enforce` setting for this attribute include: `:list` to tell the system that this attribute can hold array values and `:role`; `:role` is a symbol that refers to some other *Goo* type. *Goo* will enforce all the values of this attribute to be instances of the `Role` type.

```ruby 
attribute :roles, enforce: [:list, :role, :existence]
#Notice that this attribute complements the above User definition.
```

We can also connect back `Role` to `User` using the `inverse` setting. Say you want to retrieve all the users that are assigned a certain role. To be able to navigate the graph both ways we need to provide the inverse relation. The following definition tells `Goo` that when looking at a `Role` instance one can retrieve users by inversing the attribute `roles` from the user instance.

```ruby
attribute :users, inverse: { on: User, attribute: :roles }
#Notice that this attribute complements the above Role definition.
```

### Validators List

The are a variety of built-in validators that can be used with the `enforce` option, these include: `:string`, `:date_time`, `:float`, `:integer`, `:list`, `:unique`, `:existence`, `:min`, `:max`, `:email`, `:uri`, `:boolean`. 

Optionally one also can provide a lambda for implementing custom validations.

### Other Model and Attribute Options

- `:namespace` both model and attribute definitions accept the `:namespace` option to refer to specific vocabularies in our application (see [Configuration](#Configuration) for namespace definitions). For instance:

```ruby
model :person, namespace: :foaf, name_with: ..
```

- `:default` to provide default values to an attribute via lambda functions. For instance:

```ruby
attribute :created, enforce: [ DateTime ],
        default: lambda { |record| DateTime.now }
```

- `:property`: this setting allow us to map attributes to RDF predicates and use different names. For instance, say we want to have an attribute named `parents` that maps to `rdfs:subClassOf` in the triple store:

```ruby
attribute :parents, namespace: :rdfs, property: :subClassOf,
                    enforce: [:class, :list]
```

##Saving, updating and deleting.

- Instance creation:

```ruby
u = User.new
u.username = "paul"
u.save 
#save throws NotValidException 
#in case any validator breaks
```

- Testing for valid objects: 

```ruby
u = User.new
u.name = "paul"
if !u.valid?
 puts u.errors
end
```

- Updating an instance:

```ruby
u = User.find("paul").first
#or
u = User.where(username: "paul").all

#update the object with an array of roles
u.roles = [Roles.find("admin").first]
u.save 
```

Note: `.find("paul")` can be used because `User` has `username` as `name_with` setting, in addition `username` is `unique`. This allow us to use this shortcut.

- Deleting:

```ruby
#delete `paul`
User.find("paul").first.delete

#delete all users
User.where.all.each do |u|
  u.delete
end
```

##Querying

*Goo's* provides a flexible API for querying the SPARQL backend. There are two main `Resource` calls for creating queries: `Resource.find` and `Resource.where` 

###Resource.find - searching single instances

- Getting a resource reference:

```ruby
u = User.find(RDF::URI.new("http://example.org/paul")).first
u.is_a?(User) #true
puts u.username #throws AttributeNotLoaded exception
```

*Goo* by default does not attach any attribute values to an instance when retrieving data. This is to improve efficiency by only retrieving the attributes we care about in our application. To change this behaviour we can always overload `find` our *Goo* types.

We can attach object attributes by chaining `include` calls:

```ruby
user_id = RDF::URI.new("http://example.org/paul")

#include username
u = User.find(user_id).include(:username).first

#include username and roles
u = User.find(user_id).include(:username, :roles).first

#equivalent
u = User.find(user_id).include(:username).include(:roles).first

#embed attributes from dependent objects
#from roles include their codes
u = User.find(user_id).include(roles: [:code]).first
puts u.roles[0].code #"admin"

#include all the attributes - except inverse attributes
admin = Role.find("admin").include(Role.attributes).first

#include all the attributes - including inverse
admin = Role.find("admin").include(Role.attributes(:all)).first

```

Note: `include` is also avalaible for the `Resource.where` API call.

###Resource.where - Graph Pattern Matching

`Resource.where` offers an easy way to perform complex graph matching operations.

```ruby
#retrieve all the users with name paul that have the admin role.
users = User.where(lastname: "paul", role: [ Role.find("admin").first ]).all

#same and attach attributes
users = User.where(lastname: "paul", role: Role.find("admin").first)
                    include(:username, :birthdate).all

```

The options passed into `where` reassembles a graph matching structure and can be read as follows;

```ruby
#match 'lastname' edges that sink into literal objects "paul"
[ lastname: "paul" ,
#AND match 'role' edges that sink into 'admin' objects.
role: Role.find("admin").first ]
```

*Goo* allows for more complex scenarios. Say we had an scenario where our models are `Student`, `Programs`, `Category` and `University` and the relations between types:

- Students enrol programs, ie: _Susan enrols Bioinformatics_
- Programs have categories. ie: _Bioinformatics has categories Biology and Computer Science_ 
- Programs belong to universities, ie: _Bioinformatics is at Stanford_

```ruby
#retrieve all student enrolled in a program that has categories 
# with  code "Biology" and "Chemistry"
students = Student.where(enrolled: [category: [ code: "Biology" ]])
                    .and(enrolled: [category: [ code: "Chemistry" ]]).all

#retrieve all students enrolled in a program that belongs to a university
#that is named "Stanford" and attach student names, and embed programs
#and programs should be retrieved with their names.
students = Student.where(enrolled: [university: [name: "Stanford"]])
            .include(:name)
            .include(enrolled: [:name]).all

#We can also perform OR operations. Retrieve programs that have
# category codes "Medicine" or "Engineering"
prs = Program.where(category: [code: "Medicine"])
                    .or(category: [code: "Engineering"]).all

#From these 4 students tell me who are enrolled in programs that 
#are categorized as Medicine AND Chemistry
medicine = Category.find("Medicine").first
chemistry = Category.find("Chemistry").first
st = Student.where(name: "Daniel")
              .or(name: "Louis")
              .or(name: "Lee")
              .or(name: "John")
              .and(enrolled: [category: medicine])
              .and(enrolled: [category: chemistry]).all
```

Note: for a slightly more complex but similar scenario see ./test/test_where.rb


###Filters and Range Queries
```ruby
#students born later than ...
f = Goo::Filter.new(:birth_date) > DateTime.parse('1978-01-03')
st = Student.where.filter(f).all

#students born between two dates
f = (Goo::Filter.new(:birth_date) <= DateTime.parse('1978-01-01'))
      .or(Goo::Filter.new(:birth_date) >= DateTime.parse('1978-01-07'))
st = Student.where.filter(f).all

#students enrolled in programs with more than 8 credits
f = Goo::Filter.new(enrolled: [ :credits ]) > 8
st = Student.where.filter(f).all
```

Say our scenario has an attribute `award` in `Student` to record a list of awards that a student has earned. Now we want to find all the students with no wining awards.

```ruby
#students without awards
f = Goo::Filter.new(:awards).unbound
st = Student.where.filter(f)
                  .include(:name)
                  .all
```


###Working with unknown attributes - schemaless objects

It is often the case when dealing with Linked Data and RDF that might not be able to map all RDF attributes into application attributes but still we might want to be able to retrieve them. Unknown or unmapped attributes can be retrieved with any of the retrieval methods (find or where) by including the symbol `:unmapped`. When doing so the models wil be retrieved with an attribute `@unmmaped`, that attribute is `Hash` where the keys are the RDF predicates of that resources and the values arrays of objects.

```ruby
 p = Person.find(RDF::URI.new(SOME_URI)).include(:unmapped).first
 p.unmmaped.each do |property,values|
   puts "handle unknown attributes"
 end
```

We can search on known attributes and at retrieve unmmaped predicates:

```ruby
sts = Student.where(enrolled: [university: [name: "Stanford"]])
            .include(:unmapped).all
```

This capability is important when dealing with scenarios of data integration of Linked Data resources.



##Configuration

##Advance Topics

###Collections and Named Graphs

###Caching and Indexing

###Fast retrieval of read-only objects

###Aggregators

###Profiler
