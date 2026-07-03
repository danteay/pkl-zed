; Adapted from apple/tree-sitter-pkl queries/highlights.scm (v0.20.0),
; remapped to Zed theme captures (@string.escape, @boolean, @comment.doc, ...).
;
; NOTE: Zed gives precedence to the LAST matching pattern (unlike
; tree-sitter-highlight, where the first wins), so generic rules come first
; and specific overrides come last.

; Identifiers (generic)

(identifier) @variable

; Comments

(lineComment) @comment
(blockComment) @comment
(shebangComment) @comment
(docComment) @comment.doc

; Literals

(stringConstant) @string
(slStringLiteralExpr) @string
(mlStringLiteralExpr) @string

(intLiteralExpr) @number
(floatLiteralExpr) @number

(trueLiteralExpr) @boolean
(falseLiteralExpr) @boolean
(nullLiteralExpr) @constant.builtin

; Operators

"??" @operator
"@"  @operator
"="  @operator
"<"  @operator
">"  @operator
"!"  @operator
"==" @operator
"!=" @operator
"<=" @operator
">=" @operator
"&&" @operator
"||" @operator
"+"  @operator
"-"  @operator
"**" @operator
"*"  @operator
"/"  @operator
"~/" @operator
"%"  @operator
"|>" @operator

; Punctuation

"," @punctuation.delimiter
":" @punctuation.delimiter
"." @punctuation.delimiter
"?." @punctuation.delimiter

"(" @punctuation.bracket
")" @punctuation.bracket
"[" @punctuation.bracket
"]" @punctuation.bracket
"{" @punctuation.bracket
"}" @punctuation.bracket

; Keywords

"abstract" @keyword
"amends" @keyword
"as" @keyword
"class" @keyword
"else" @keyword
"extends" @keyword
"external" @keyword
"for" @keyword
"function" @keyword
"hidden" @keyword
"if" @keyword
"import" @keyword
"import*" @keyword
"in" @keyword
"is" @keyword
"let" @keyword
"local" @keyword
"module" @keyword
"new" @keyword
"open" @keyword
"out" @keyword
"typealias" @keyword
"when" @keyword

; Properties and parameters

(classProperty (identifier) @property)
(objectProperty (identifier) @property)

(parameterList (typedIdentifier (identifier) @variable.parameter))
(objectBodyParameters (typedIdentifier (identifier) @variable.parameter))

; Types

((identifier) @type
 (#match? @type "^[A-Z]"))

(clazz (identifier) @type)
(typeAlias (identifier) @type)

(typeArgumentList
  "<" @punctuation.bracket
  ">" @punctuation.bracket)

; Method definitions

(classMethod (methodHeader (identifier) @function.method))
(objectMethod (methodHeader (identifier) @function.method))

; Builtins (override the generic keyword/variable rules above)

(thisExpr) @variable.special
(outerExpr) @variable.special
"super" @variable.special

(moduleExpr "module" @type.builtin)
(importExpr "import" @function.builtin)
(importExpr "import*" @function.builtin)
"read" @function.builtin
"read?" @function.builtin
"read*" @function.builtin
"throw" @function.builtin
"trace" @function.builtin

; Annotations

(annotation "@" @attribute (qualifiedIdentifier (identifier) @attribute))

; String escapes and interpolation (override generic string/bracket rules)

(escapeSequence) @string.escape

(stringInterpolation
  "\\(" @punctuation.special
  ")" @punctuation.special) @embedded

(stringInterpolation
  "\\#(" @punctuation.special
  ")" @punctuation.special) @embedded

(stringInterpolation
  "\\##(" @punctuation.special
  ")" @punctuation.special) @embedded
