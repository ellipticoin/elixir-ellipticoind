;; This is program has one exported function `echo` which
;; returns a zero error code and the the integer that's passed to it.

;; compile with
;; wast2wasm test/support/echo.wast -o test/support/echo.wasm


;; echo.c
;;char data[8] = {5, 0, 0, 0, 0, 0, 0, 0, 0}; 

;;char* echo(char value) {
;;  data[8] = value; 
;;
;;  return &data[0];
;;}


(module
 (table 0 anyfunc)
 (memory $0 1)
 (data (i32.const 16) "\05\00\00\00\00\00\00\00")
 (export "memory" (memory $0))
 (export "echo" (func $echo))
 (func $echo (; 0 ;) (param $0 i32) (result i32)
  (i32.store8 offset=24
   (i32.const 0)
   (get_local $0)
  )
  (i32.const 16)
 )
)
