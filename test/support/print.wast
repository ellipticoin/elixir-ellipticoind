(module
 (type $FUNCSIG$i (func (result i32)))
 (type $FUNCSIG$ii (func (param i32) (result i32)))
 (import "env" "print" (func $print (param i32) (result i32)))
 (table 0 anyfunc)
 (memory $0 1)
 (export "memory" (memory $0))
 (export "callPrint" (func $callPrint))
 (func $callPrint (; 1 ;)
  (drop
   (call $print
    (i32.const 99)
   )
  )
 )
)
