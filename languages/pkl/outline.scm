(moduleClause
  "module" @context
  (qualifiedIdentifier) @name) @item

(clazz
  "class" @context
  (identifier) @name) @item

(typeAlias
  "typealias" @context
  (identifier) @name) @item

(classMethod
  (methodHeader
    "function" @context
    (identifier) @name)) @item

(objectMethod
  (methodHeader
    "function" @context
    (identifier) @name)) @item

(classProperty
  (identifier) @name) @item

(objectProperty
  (identifier) @name) @item
