#Refactoring Goo


##All as instance variables

New model. All objects are schema

`load_unbounded` creates the `@properties` instance variable with 

## Model/document the policy for loading objects.

- just one policy the same for 1 objects for many and for pages.

- dependent objects always return an URI unless asked with embed or dependents.

ontology.status.to_resource

- enums … in memory objects.


- iterative query templates for effient object loading.

##Inheritance for attributes

would help to implement notes. 
also for the use case issue < notes

## Use RDF.py for writing triples

##One strategy

Methods find, all, where return references with no data unless

##Other
- Update just modified attributes.
- All methods(find, where, all) do not load any attributes unless load_attrs is used.
- Freeze internals.
- Fail when trying to access a property that has not been loaded. 


##Mapping Queries

Preloading terms when querying mappings.

```
SELECT * WHERE {
?m terms [
		ontology <A>;
		term ?termA;
	];
	terms [
		ontology <B>;
		term ?termB
	]
```

how do I preload termA and termB and trackback that `?termA` values belong to ontology A and `?termB` values.



##Paper

###Load balancing - multiple KB.

better to do this with a proxy. outside of goo.
SPARQL LOAD BALANCER project.

includes the cache … it parses the updates and knows what cache entrances
to disable.

RESEARCH - subset of SPARQL update that can be detected for caches.

( Mappings ) x 2 , ( terms + metadata ) x 2

RUST

integrate 
https://github.com/etsy/statsd/
graphs
http://graphite.wikidot.com/

###Distributed updates - load balancing.

Can we have multiple backends ? Updates happen sincronously. When doing an upload of a large graph - take that node out of the reading queue.

###Noisy
how do we load objects with ranges with different types.

<a> location <london>
<b> location <london>

#Access control

property owner … for save operations.

##DSL OPTIONS


```
class Person < Goo::Base::Resource
  model :person_persist
  attribute :name, :unique => true
  attribute :multiple_vals, enforce: [ :list ]
  attribute :birth_date, enforce: [ :existence ]

  attribute :created, :instance_of => DateTime,
            :single_value=> true, :default => lambda { |record| DateTime.now }
            
  attribute :friends, :empty => false
  attribute :status ,  
  			:default => lambda { |record| StatusPersist.find("single") }, 
  			:one_value => true, :instance_of => :status

  def initialize(attributes = {})
    super(attributes)
  end
end
```