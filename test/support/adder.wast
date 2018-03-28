;; This is program has one exported function `add` which
;; returns a zero error code and the the sum of two integers.

;; compile with
;; wast2wasm test/support/adder.wast -o test/support/adder.wasm


;; adder.c
;; char data[9] = {0, 0, 0, 5, 0, 0, 0, 0, 0};

;; char* add(char first, char second) {
;;  data[8] = first + second;

;;  return &data[0];
;; }

(module
 (table 0 anyfunc)
 (memory $0 1)
 (data (i32.const 16) "\00\00\00\05\00\00\00\00\00")
 (export "memory" (memory $0))
 (export "add" (func $add))
 (func $add (; 0 ;) (param $0 i32) (param $1 i32) (result i32)
  (i32.store8 offset=24
   (i32.const 0)
   (i32.add
    (get_local $1)
    (get_local $0)
   )
  )
  (i32.const 16)
 )
)
