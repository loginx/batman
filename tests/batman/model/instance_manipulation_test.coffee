{TestStorageAdapter, AsyncTestStorageAdapter} = if typeof require isnt 'undefined' then require './model_helper' else window

QUnit.module "Batman.Model instance loading"
  setup: ->
    class @Product extends Batman.Model
      @encode 'name', 'cost'

    @adapter = new AsyncTestStorageAdapter(@Product)
    @adapter.storage =
      'products1': {name: "One", cost: 10, id:1}

    @Product.persist @adapter

asyncTest "instantiated instances can load their values", ->
  product = new @Product(1)
  product.load (err, product, env) =>
    throw err if err
    equal product.get('name'), 'One'
    equal product.get('id'), 1
    ok env
    QUnit.start()

asyncTest "instantiated instances error upon load if they don't exist", ->
  product = new @Product(1110000) # Non existent primary key.
  equal @Product.get('loaded.length'), 0
  product.load (err, product) =>
    ok err
    equal @Product.get('loaded.length'), 0
    QUnit.start()

asyncTest "instantiated instances should accept options for load", 1, ->
  product = new @Product(1)
  spyOn @adapter, 'read'

  product.load {foo: "bar"}, (err, product) =>
    throw err if err
    deepEqual @adapter.read.lastCallArguments[1], {foo: "bar"}
    QUnit.start()

asyncTest "loading instances should add them to the all set", ->
  product = new @Product(1)
  equal @Product.get('all').length, 0
  product.load (err, product) =>
    equal @Product.get('all').length, 1
    QUnit.start()

asyncTest "loading instances should add them to the all set if no callbacks are given", ->
  product = new @Product(1)
  equal @Product.get('all').length, 0
  product.load()
  delay =>
    equal @Product.get('all').length, 1

asyncTest "loading instances which error should put the model in the error state", ->
  product = new @Product(11) # non existent
  equal @Product.get('all').length, 0
  product.load (err, passedProduct) =>
    ok err
    equal product.get("lifecycle.state"), "error"
    QUnit.start()

asyncTest "callbacks passed to load should be pipelined into the same request", ->
  product = new @Product(1)
  spyOn @adapter, 'read'
  product.load firstLoad = createSpy()
  product.load secondLoad = createSpy()
  product.load (err, passedProduct) =>
    throw err if err
    equal passedProduct, product
    # Callback order is not guaranteed
    setTimeout =>
      for load in [firstLoad, secondLoad]
        ok !load.lastCallArguments[0]
        equal load.lastCallArguments[1], product
      equal @adapter.read.callCount, 1
      QUnit.start()
    , 0

asyncTest "load should pipeline even if no callbacks are given", ->
  product = new @Product(1)
  spyOn @adapter, 'read'
  product.load()
  product.load firstLoad = createSpy()
  product.load()
  product.load secondLoad = createSpy()
  product.load (err, passedProduct) =>
    throw err if err
    equal passedProduct, product
    # Callback order is not guaranteed
    setTimeout =>
      for load in [firstLoad, secondLoad]
        ok !load.lastCallArguments[0]
        equal load.lastCallArguments[1], product
      equal @adapter.read.callCount, 1
      QUnit.start()
    , 0

test "callbacks passed to load with options should not be pipelined into the same request", ->
  product = new @Product(1)
  spyOn @adapter, 'read'
  product.load {id: 1}, firstLoad = createSpy()
  QUnit.raises (-> product.load({id: 2}, (err, product) -> throw err if err))
  QUnit.raises (-> product.load({id: 1}, (err, product )-> throw err if err))

asyncTest "load calls in an accessor will have no sources", ->
  obj = Batman()
  product = new @Product(1)
  callCount = 0
  obj.accessor 'foo', =>
    callCount += 1
    product.load (err, product) ->
      throw err if err
      delay ->
        equal callCount, 1
  obj.get('foo')
  equal obj.property('foo').sources.length, 0

QUnit.module "Batman.Model instance saving"
  setup: ->
    class @Product extends Batman.Model
      @encode 'name', 'cost'

    @adapter = new AsyncTestStorageAdapter(@Product)
    @Product.persist @adapter

asyncTest "model instances should save", ->
  product = new @Product()
  product.save (err, product, env) =>
    throw err if err?
    ok product.get('id') # We rely on the test storage adapter to add an ID, simulating what might actually happen IRL
    ok env
    QUnit.start()

asyncTest "new instances should be added to the identity map", ->
  product = new @Product()
  equal @Product.get('loaded.length'), 0
  product.save (err, product) =>
    throw err if err?
    equal @Product.get('loaded').length, 1
    QUnit.start()

asyncTest "new instances should be added to the identity map even if no callback is given", ->
  product = new @Product()
  equal @Product.get('loaded.length'), 0
  product.save()
  delay =>
    throw err if err?
    equal @Product.get('loaded').length, 1

asyncTest "existing instances shouldn't be re added to the identity map", ->
  product = new @Product(10)
  product.load (err, product) =>
    throw err if err
    equal @Product.get('all').length, 1
    product.save (err, product) =>
      throw err if err?
      equal @Product.get('all').length, 1
      QUnit.start()

asyncTest "existing instances should be updated with incoming attributes", ->
  @adapter.storage = {"products10": {name: "override"}}
  product = new @Product(id: 10, name: "underneath")
  product.load (err, product) =>
    throw err if err
    equal product.get('name'), 'override'
    QUnit.start()

asyncTest "model instances should accept options for save upon create", 1, ->
  product = new @Product()
  spyOn @adapter, 'create'

  product.save {neato: true}, (err, product) =>
    throw err if err?
    deepEqual @adapter.create.lastCallArguments[1], {neato: true}
    QUnit.start()

asyncTest "model instances should accept options for save upon update", 1, ->
  product = new @Product(10)
  spyOn @adapter, 'update'

  product.save {neato: true}, (err, product) =>
    deepEqual @adapter.update.lastCallArguments[1], {neato: true}
    throw err if err?
    QUnit.start()

asyncTest "model instances should throw if they can't be saved", ->
  product = new @Product()
  @adapter.create = (record, options, callback) -> callback(new Error("couldn't save for some reason"))
  product.save (err, product) =>
    ok err
    QUnit.start()

asyncTest "model instances shouldn't save if they don't validate", ->
  @Product.validate 'name', presence: yes
  product = new @Product()
  product.save (err, product) ->
    equal err.length, 1
    QUnit.start()

asyncTest "model instances should not be in error if they don't validate", ->
  @Product.validate 'name', presence: yes
  product = new @Product()
  product.save (err, product) ->
    notEqual product.get('lifecycle.state'), 'error'
    QUnit.start()

asyncTest "model instances should return to dirty if they don't validate", ->
  @Product.validate 'name', presence: yes
  product = new @Product()
  product.save (err, product) ->
    ok err
    product.set 'name', 'Chair'
    product.save (err, product) ->
      ok !err
      equal product.get('lifecycle.state'), 'clean'
      QUnit.start()

asyncTest "model instances shouldn't save if they have been destroyed", ->
  p = new @Product(10)
  p.destroy (err) =>
    throw err if err
    p.save (err) ->
      ok err
      p.load (err) ->
        ok err
        QUnit.start()

asyncTest "create method returns an instance of a model while saving it", ->
  result = @Product.create (err, product) =>
    ok !err
    ok product instanceof @Product
    QUnit.start()
  ok result instanceof @Product

asyncTest "string ids are coerced into integers when possible", ->
  product = new @Product
  product.save (err) =>
    throw err if err
    id = product.get('id')
    @Product.find ""+id, (err, foundProduct) ->
      equal foundProduct, product
      QUnit.start()

asyncTest "save calls in an accessor will have no sources", ->
  obj = Batman()
  product = new @Product(1)
  callCount = 0
  obj.accessor 'foo', =>
    callCount += 1
    product.save (err, product) ->
      throw err if err
      delay ->
        equal callCount, 1
  obj.get('foo')
  equal obj.property('foo').sources.length, 0

QUnit.module "Batman.Model instance destruction"
  setup: ->
    class @Product extends Batman.Model
      @encode 'name', 'cost'

    @adapter = new AsyncTestStorageAdapter(@Product)
    @Product.persist @adapter

asyncTest "model instances should be destroyable", ->
  @Product.find 10, (err, product) =>
    throw err if err
    equal @Product.get('all').length, 1

    product.destroy (err, record, env) =>
      throw err if err
      equal record, product
      ok env
      equal @Product.get('all').length, 0, 'instances should be removed from the identity map upon destruction'
      QUnit.start()

asyncTest "model instances should be accept options for destruction", 1, ->
  product = new @Product(10)
  oldDestroy = @adapter.destroy
  @adapter.destroy = (record, options, callback) ->
    deepEqual options, paranoid: true
    oldDestroy.apply(@, arguments)

  product.destroy {paranoid: true}, (err) =>
    throw err if err
    QUnit.start()

asyncTest "model instances which don't exist in the store shouldn't be destroyable", ->
  p = new @Product(11000)
  p.destroy (err) =>
    ok err
    QUnit.start()

asyncTest "destroy calls in an accessor will have no sources", ->
  obj = Batman()
  product = new @Product(10)
  callCount = 0
  obj.accessor 'foo', =>
    callCount += 1
    product.destroy (err) ->
      throw err if err
      delay ->
        equal callCount, 1
  obj.get('foo')
  equal obj.property('foo').sources.length, 0

QUnit.module "Batman.Model instance validation"
  setup: ->
    class @Product extends Batman.Model
      @encode 'name', 'cost'

    @adapter = new AsyncTestStorageAdapter(@Product)
    @Product.persist @adapter

asyncTest "validate calls in an accessor will have no sources", ->
  obj = Batman()
  product = new @Product(1)
  callCount = 0
  obj.accessor 'foo', =>
    callCount += 1
    product.validate (err) ->
      delay ->
        equal callCount, 1
  obj.get('foo')
  equal obj.property('foo').sources.length, 0
