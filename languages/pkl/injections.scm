; From apple/tree-sitter-pkl queries/injections.scm (v0.20.0).
; Imprecise on purpose: any call to a method named "Regex" is considered a
; regex, and the string delimiters are included in the injected range.
(
  ((unqualifiedAccessExpr
     (identifier) @_methodName
     (argumentList (slStringLiteralExpr) @injection.content))
    (#set! injection.language "regex"))
  (#eq? @_methodName "Regex"))
