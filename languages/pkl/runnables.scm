; Marks every Pkl module as evaluatable via the `pkl eval` tasks in
; tasks.json (bound by the pkl-eval tag).
;
; The run button is attached to the module's first top-level construct
; rather than the (module) root node: a root capture spans the whole file,
; and Zed's gutter indicator does not surface for it.
(
  (module . (_) @run)
  (#set! tag pkl-eval)
)
