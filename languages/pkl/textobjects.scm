(classMethod) @function.around
(objectMethod) @function.around
(functionLiteralExpr) @function.around

(clazz) @class.around
(classBody (_) @class.inside)

(lineComment)+ @comment.around
(docComment)+ @comment.around
(blockComment) @comment.around
