#= require singular_association

class Batman.BelongsToAssociation extends Batman.SingularAssociation
  associationType: 'belongsTo'
  proxyClass: Batman.BelongsToProxy
  indexRelatedModelOn: 'primaryKey'
  defaultOptions:
    saveInline: false
    autoload: true

  constructor: (model, label, options) ->
    if options?.polymorphic
      delete options.polymorphic
      return new Batman.PolymorphicBelongsToAssociation(arguments...)
    super
    @foreignKey = @options.foreignKey or "#{@label}_id"
    @primaryKey = @options.primaryKey or "id"
    @model.encode @foreignKey

  url: (recordOptions) ->
    if inverse = @inverse()
      root = Batman.helpers.pluralize(@label)
      id = recordOptions.data?[@foreignKey]
      helper = if inverse.isSingular then "singularize" else "pluralize"
      ending = Batman.helpers[helper](inverse.label)

      return "/#{root}/#{id}/#{ending}"

  encoder: ->
    association = @
    encoder =
      encode: false
      decode: (data, _, __, ___, childRecord) ->
        relatedModel = association.getRelatedModel()
        record = new relatedModel()
        record.fromJSON(data)
        record = relatedModel._mapIdentity(record)
        if association.options.inverseOf
          if inverse = association.inverse()
            if inverse instanceof Batman.HasManyAssociation
              # Rely on the parent's set index to get this out.
              childRecord.set(association.foreignKey, record.get(association.primaryKey))
            else
              record.set(inverse.label, childRecord)
        childRecord.set(association.label, record)
        record
    if @options.saveInline
      encoder.encode = (val) -> val.toJSON()
    encoder

  apply: (base) ->
    if model = base.get(@label)
      foreignValue = model.get(@primaryKey)
      if foreignValue isnt undefined
        base.set @foreignKey, foreignValue