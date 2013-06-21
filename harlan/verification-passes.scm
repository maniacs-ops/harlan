(library
  (harlan verification-passes)
  (export
    verify-harlan
    verify-parse-harlan
    verify-returnify
    verify-typecheck
    verify-expand-primitives
    verify-desugar-match
    verify-remove-danger
    verify-make-kernel-dimensions-explicit
    verify-make-work-size-explicit
    verify-optimize-lift-lets
    verify-optimize-fuse-kernels
    verify-remove-nested-kernels
    verify-returnify-kernels
    verify-lift-complex
    verify-optimize-lift-allocation
    verify-make-vector-refs-explicit
    verify-annotate-free-vars
    verify-lower-vectors
    verify-insert-let-regions
    verify-infer-regions
    verify-uglify-vectors
    verify-remove-let-regions
    verify-flatten-lets
    verify-hoist-kernels
    verify-generate-kernel-calls
    verify-compile-module
    verify-convert-types)
  (import
    (rnrs)
    (harlan helpers)
    (except (elegant-weapons helpers) ident?)
    (util verify-grammar)
    (cKanren mk))

(define (region-var? x)
  (or (symbol? x) (var? x)))
  
(grammar-transforms

  (%static
    (Type
      Var
      harlan-type
      (vec Type)
      (ptr Type)
      (ref Type)
      (adt Type)
      (struct (Var Type) *)
      (union (Var Type) *)
      ((Type *) -> Type))
    (C-Type
      harlan-c-type
      harlan-cl-type
      (ptr C-Type)
      (ref C-Type)
      (const-ptr C-Type)
      ((C-Type *) -> C-Type)
      Type)
    (Rho-Type
     Var
     harlan-type
     (vec Var Rho-Type)
     (ptr Rho-Type)
     (adt Rho-Type Var)
     (adt Rho-Type)
     ((Rho-Type *) -> Rho-Type))
    (Var ident)
    (Integer integer)
    (Binop binop)
    (Relop relop)
    (Float float)
    (String string)
    (Char char)
    (Boolean boolean)
    (Number number)
    (RegionVar region-var))
  
  (harlan
    (Start Module)
    (Module (module Decl +))
    (Decl
      (extern Var (Type *) -> Type)
      (fn Var (Var *) Value +) ;; depricated, use define instead
      (define (Var Var *) Value +))
    (Value
      char
      integer
      boolean
      float
      string
      ident
      (let ((Var Value) *) Value +)
      (let-region (RegionVar *) Value +)
      (begin Value * Value)
      (print Value)
      (print Value Value)
      (println Value)
      (println Value Value)
      (write-pgm Value Value)
      (assert Value)
      (set! Var Value)
      (while Value Value +)
      (if Value Value)
      (if Value Value Value)
      (return)
      (return Value)
      (vector Value +)
      (vector-r RegionVar Value +)
      (vector-ref Value Value)
      (kernel ((Var Value) +) Value * Value)
      (kernel-r RegionVar ((Var Value) +) Value * Value)
      (iota Value)
      (iota-r RegionVar Value)
      (length Value)
      (Binop Value Value)
      (Relop Value Value)
      (Var Value *)))

  (parse-harlan (%inherits Module)
    (Start Module)
    (Decl
      (extern Var (Type *) -> Type)
      (define-datatype Var TPattern *)
      (fn Var (Var *) Stmt))
    (TPattern
     (Var Type *))
    (Stmt
      (let ((Var Expr) *) Stmt)
      (let-region (RegionVar) Stmt)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (begin Stmt * Stmt)
      (print Expr)
      (print Expr Expr)
      (println Expr)
      (println Expr Expr)
      (write-pgm Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (do Expr)
      (while Expr Stmt)
      (return)
      (return Expr))
    (Expr
      (char Char)
      (num Integer)
      (float Float)
      (str String)
      (bool Boolean)
      (var Var)
      (vector Expr +)
      (vector-r RegionVar Expr +)
      (begin Stmt * Expr)
      (if Expr Expr Expr)
      (vector-ref Expr Expr)
      (unsafe-vector-ref Expr Expr)
      (lambda (Var *) Stmt * Expr)
      (let ((Var Expr) *) Expr)
      (kernel ((Var Expr) +) Expr)
      (kernel-r RegionVar ((Var Expr) +) Expr)
      (iota Expr)
      (iota-r RegionVar Expr)
      (length Expr)
      (int->float Expr)
      (make-vector Expr Expr)
      (match Expr EPattern *)
      (Binop Expr Expr)
      (Relop Expr Expr)
      (call Var Expr *))
    (EPattern
     (MPattern Expr))
    (MPattern
     (Var Var *)))

  (returnify (%inherits Module TPattern EPattern MPattern)
    (Start Module)
    (Decl
      (fn Var (Var *) Body)
      (define-datatype Var TPattern *)
      (extern Var (Type *) -> Type))
    (Body
      (begin Stmt * Body)
      (let ((Var Expr) *) Body)
      (let-region (RegionVar) Body)
      (if Expr Body)
      (if Expr Body Body)
      Ret-Stmt)
    (Ret-Stmt (return Expr) (return))
    (Stmt
      (let ((Var Expr) *) Stmt)
      (let-region (RegionVar) Stmt)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (begin Stmt * Stmt)
      (print Expr)
      (print Expr Expr)
      (println Expr)
      (println Expr Expr)
      (write-pgm Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (do Expr)
      (while Expr Stmt)
      Ret-Stmt)
    (Expr
      (char Char)
      (bool Boolean)
      (num Integer)
      (float Float)
      (str String)
      (var Var)
      (vector Expr +)
      (vector-r RegionVar Expr +)
      (begin Stmt * Expr)
      (if Expr Expr Expr)
      (vector-ref Expr Expr)
      (unsafe-vector-ref Expr Expr)
      (lambda (Var *) Stmt * Expr)
      (let ((Var Expr) *) Expr)
      (kernel ((Var Expr) +) Expr)
      (kernel-r RegionVar ((Var Expr) +) Expr)
      (iota Expr)
      (iota-r RegionVar Expr)
      (length Expr)
      (int->float Expr)
      (make-vector Expr Expr)
      (match Expr EPattern *)
      (Binop Expr Expr)
      (Relop Expr Expr)
      (call Var Expr *)))

  (typecheck (%inherits Module Ret-Stmt)
    (Start Module)
    (Decl
      (extern Var (Type *) -> Type)
      (define-datatype (Var Var) (Var Rho-Type *) *)
      (define-datatype Var (Var Rho-Type *) *)
      (fn Var (Var *) Rho-Type Body))
    (Body
      (begin Stmt * Body)
      (let ((Var Rho-Type Expr) *) Body)
      (let-region (RegionVar *) Body)
      (if Expr Body)
      (if Expr Body Body)
      Ret-Stmt)
    (Stmt
      (let ((Var Rho-Type Expr) *) Stmt)
      (let-region (RegionVar *) Stmt)
      (if Expr Stmt)
      (begin Stmt * Stmt)
      (if Expr Stmt Stmt)
      (print Rho-Type Expr)
      (print Rho-Type Expr Expr)
      (println Rho-Type Expr)
      (println Rho-Type Expr Expr)
      (write-pgm Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (do Expr)
      (while Expr Stmt)
      (return Expr))
    (Expr
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (bool Boolean)
      (var Rho-Type Var)
      (if Expr Expr Expr)
      (let ((Var Rho-Type Expr) *) Expr)
      (begin Stmt * Expr)
      (vector Rho-Type Expr +)
      (vector-r Rho-Type RegionVar Expr +)
      (vector-ref Rho-Type Expr Expr)
      (unsafe-vector-ref Rho-Type Expr Expr)
      (kernel Rho-Type (((Var Rho-Type) (Expr Rho-Type)) +) Expr)
      (kernel-r Rho-Type RegionVar (((Var Rho-Type) (Expr Rho-Type)) +) Expr)
      (iota Expr)
      (iota-r RegionVar Expr)
      (length Expr)
      (int->float Expr)
      (make-vector Rho-Type Expr Expr)
      (match Rho-Type Expr ((Var Var *) Expr) *)
      (Binop Rho-Type Expr Expr)
      (Relop Rho-Type Expr Expr)
      (call Expr Expr *)))

  (expand-primitives
    (%inherits Module Decl Body Ret-Stmt)
    (Start Module)
    (Stmt
      (let ((Var Rho-Type Expr) *) Stmt)
      (let-region (RegionVar) Stmt)
      (if Expr Stmt)
      (begin Stmt * Stmt)
      (if Expr Stmt Stmt)
      (print Expr)
      (print Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (do Expr)
      (for (Var Expr Expr Expr) Stmt)
      (while Expr Stmt)
      (return Expr))
    (Expr
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (bool Boolean)
      (var Rho-Type Var)
      (if Expr Expr Expr)
      (let ((Var Rho-Type Expr) *) Expr)
      (begin Stmt * Expr)
      (vector-ref Rho-Type Expr Expr)
      (unsafe-vector-ref Rho-Type Expr Expr)
      (kernel Rho-Type RegionVar (((Var Rho-Type) (Expr Rho-Type)) +) Expr)
      (length Expr)
      (int->float Expr)
      (make-vector Rho-Type RegionVar Expr)
      (vector Rho-Type RegionVar Expr +)
      (iota Expr)
      (iota-r RegionVar Expr)
      (match Rho-Type Expr ((Var Var *) Expr) *)
      (Binop Expr Expr)
      (Relop Expr Expr)
      (call Expr Expr *)))

  (desugar-match
   (%inherits Module Body Stmt Ret-Stmt)
    (Start Module)
    (Decl
      (extern Var (Type *) -> Type)
      (typedef Var Type)
      (fn Var (Var *) Rho-Type Body))
    (Expr
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (bool Boolean)
      (var Rho-Type Var)
      (empty-struct)
      (if Expr Expr Expr)
      (let ((Var Rho-Type Expr) *) Expr)
      (begin Stmt * Expr)
      (vector-ref Rho-Type Expr Expr)
      (unsafe-vector-ref Rho-Type Expr Expr)
      (kernel Rho-Type RegionVar (((Var Rho-Type) (Expr Rho-Type)) +) Expr)
      (length Expr)
      (int->float Expr)
      (make-vector Rho-Type RegionVar Expr)
      (vector Rho-Type RegionVar Expr +)
      (iota Expr)
      (iota-r RegionVar Expr)
      (Binop Expr Expr)
      (Relop Expr Expr)
      (field Expr Var)
      ;; Evaluates an expression and sticks it in a box in the region
      ;; given in Var.
      (box Var Rho-Type Expr)
      ;; Reads an expression out of the box.
      (unbox Rho-Type Var Expr)
      (c-expr C-Type Var)
      (call Expr Expr *)))
  
  (make-kernel-dimensions-explicit
    (%inherits Module Decl Body Stmt Ret-Stmt)
    (Start Module)
    (Expr
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (bool Boolean)
      (var Rho-Type Var)
      (empty-struct)
      (box Var Rho-Type Expr)
      (unbox Rho-Type Var Expr)
      (if Expr Expr Expr)
      (let ((Var Rho-Type Expr) *) Expr)
      (begin Stmt * Expr)
      (vector-ref Rho-Type Expr Expr)
      (unsafe-vector-ref Rho-Type Expr Expr)
      (kernel Rho-Type RegionVar Integer (Expr +)
              (((Var Rho-Type) (Expr Rho-Type) Integer) *) Expr)
      (kernel Rho-Type RegionVar Integer
              (((Var Rho-Type) (Expr Rho-Type) Integer) *) Expr)
      (length Expr)
      (int->float Expr)
      (make-vector Rho-Type RegionVar Expr)
      (vector Rho-Type RegionVar Expr +)
      (Binop Expr Expr)
      (Relop Expr Expr)
      (c-expr C-Type Var)
      (field Expr Var)
      (call Expr Expr *)))

  (make-work-size-explicit
    (%inherits Module Decl Body Stmt Ret-Stmt)
    (Start Module)
    (Expr
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (bool Boolean)
      (var Rho-Type Var)
      (empty-struct)
      (box Var Rho-Type Expr)
      (unbox Rho-Type Var Expr)
      (if Expr Expr Expr)
      (let ((Var Rho-Type Expr) *) Expr)
      (begin Stmt * Expr)
      (vector-ref Rho-Type Expr Expr)
      (unsafe-vector-ref Rho-Type Expr Expr)
      (kernel Rho-Type RegionVar (Expr +)
              (((Var Rho-Type) (Expr Rho-Type) Integer) *) Expr)
      (length Expr)
      (int->float Expr)
      (make-vector Rho-Type RegionVar Expr)
      (vector Rho-Type RegionVar Expr +)
      (Binop Expr Expr)
      (Relop Expr Expr)
      (c-expr C-Type Var)
      (field Expr Var)
      (call Expr Expr *)))

  (optimize-lift-lets
    (%inherits Module Decl Stmt Body Expr Ret-Stmt)
    (Start Module))

  (optimize-fuse-kernels
   (%inherits Module Decl Body Stmt Ret-Stmt Expr))
  
  (remove-danger
   (%inherits Module Decl Body Ret-Stmt Expr)
   (Start Module)
   (Stmt
     (let ((Var Rho-Type Expr) *) Stmt)
     (let-region (RegionVar) Stmt)
     (if Expr Stmt)
     (begin Stmt * Stmt)
     (if Expr Stmt Stmt)
     (print Expr)
     (print Expr Expr)
     (assert Expr)
     (set! Expr Expr)
     (do Expr)
     (for (Var Expr Expr Expr) Stmt)
     (while Expr Stmt)
     (error Var)
     (return Expr)))
  
  ;; This is really not true, the grammar does change.  Lazy!
  (remove-nested-kernels
    (%inherits Module Decl Stmt Body Expr Ret-Stmt)
    (Start Module))

  (returnify-kernels
   (%inherits Module Decl Body Ret-Stmt)
    (Start Module)
    (Stmt
      (print Expr)
      (print Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (kernel Rho-Type (Expr +)
              (((Var Rho-Type) (Expr Rho-Type) Integer) *) Stmt)
      (let ((Var Rho-Type Expr) *) Stmt)
      (let-region (RegionVar) Stmt)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (for (Var Expr Expr Expr) Stmt)
      (while Expr Stmt)
      (do Expr)
      (begin Stmt * Stmt)
      (error Var)
      Ret-Stmt)
    (Expr
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (bool Boolean)
      (var Rho-Type Var)
      (empty-struct)  
      (box Var Rho-Type Expr)
      (unbox Rho-Type Var Expr)
      (if Expr Expr Expr)
      (let ((Var Rho-Type Expr) *) Expr)
      (begin Stmt * Expr)
      (vector-ref Rho-Type Expr Expr)
      (length Expr)
      (int->float Expr)
      (make-vector Rho-Type RegionVar Expr)
      (vector Rho-Type RegionVar Expr +)
      (not Expr)
      (Binop Expr Expr)
      (Relop Expr Expr)
      (c-expr C-Type Var)
      (field Expr Var)
      (call Expr Expr *)))

  (lift-complex (%inherits Module Decl)
    (Start Module)
    (Body
      (begin Stmt * Body)
      (let ((Var Rho-Type Lifted-Expr) *) Body)
      (let ((Var Rho-Type) *) Body)
      (let-region (RegionVar *) Body)
      (if Triv Body)
      (if Triv Body Body)
      Ret-Stmt)
    (Ret-Stmt (return Triv) (return))
    (Stmt
      (let ((Var Rho-Type Lifted-Expr) *) Stmt)
      (let ((Var Rho-Type) *) Stmt)
      (let-region (RegionVar *) Stmt)
      (if Triv Stmt)
      (if Triv Stmt Stmt)
      (begin Stmt * Stmt)
      (print Triv)
      (print Triv Triv)
      (assert Triv)
      (set! Triv Triv)
      (kernel Rho-Type (Triv +)
              (((Var Rho-Type) (Triv Rho-Type) Integer) *) Stmt)
      (do Triv)
      (for (Var Triv Triv Triv) Stmt)
      (while Triv Stmt)
      (error Var)
      Ret-Stmt)
    (Lifted-Expr
      (make-vector Rho-Type RegionVar Triv)
      (vector Rho-Type RegionVar Triv +)
      (box Var Rho-Type Triv)
      Triv)
    (Triv
      (if Triv Triv Triv)
      (call Triv Triv *)
      (int->float Triv)
      (length Triv)
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (bool Boolean)
      (var Rho-Type Var)
      (empty-struct)  
      (unbox Rho-Type Var Triv)
      (c-expr C-Type Var)
      (vector-ref Rho-Type Triv Triv)
      (not Triv)
      (field Triv Var)
      (Binop Triv Triv)
      (Relop Triv Triv)))

  (optimize-lift-allocation
   (%inherits Module Decl Body Ret-Stmt Lifted-Expr Stmt Triv))

  (make-vector-refs-explicit
    (%inherits Module Decl Body Ret-Stmt Lifted-Expr)
    (Start Module)
    (Stmt
      (print Triv)
      (print Triv Triv)
      (assert Triv)
      (set! Triv Triv)
      (kernel Rho-Type (Triv +) Stmt)
      (let ((Var Rho-Type Lifted-Expr) *) Stmt)
      (let ((Var Rho-Type) *) Stmt)
      (let-region (RegionVar *) Stmt)
      (if Triv Stmt)
      (if Triv Stmt Stmt)
      (for (Var Triv Triv Triv) Stmt)
      (while Triv Stmt)
      (do Triv)
      (begin Stmt * Stmt)
      (error Var)
      Ret-Stmt)
    (Triv
      (bool Boolean)
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (var Rho-Type Var)
      (empty-struct)  
      (box Var Rho-Type Triv)
      (unbox Rho-Type Var Triv)
      (int->float Triv)
      (length Triv)
      (addressof Triv)
      (deref Triv)
      (if Triv Triv Triv)
      (call Triv Triv *)
      (c-expr C-Type Var)
      (vector-ref Rho-Type Triv Triv)
      (not Triv)
      (field Triv Var)
      (Binop Triv Triv)
      (Relop Triv Triv)))

  (annotate-free-vars (%inherits Module Decl Body Lifted-Expr Triv Ret-Stmt)
    (Start Module)
    (Stmt
      (error Var)
      (print Triv)
      (print Triv Triv)
      (assert Triv)
      (set! Triv Triv)
      (kernel Rho-Type
        (Triv +)
        (free-vars (Var Rho-Type) *)
        Stmt)
      (let ((Var Rho-Type Lifted-Expr) *) Stmt)
      (let ((Var Rho-Type) *) Stmt)
      (let-region (RegionVar *) Stmt)
      (if Triv Stmt)
      (if Triv Stmt Stmt)
      (for (Var Triv Triv Triv) Stmt)
      (while Triv Stmt)
      (do Triv)
      (begin Stmt * Stmt)
      Ret-Stmt))

  (lower-vectors (%inherits Module Body Decl Triv Ret-Stmt Stmt)
    (Start Module)
    (Lifted-Expr
     (make-vector Rho-Type RegionVar Triv)
     (box RegionVar Rho-Type)
     Triv))

  (insert-let-regions (%inherits Module Body Lifted-Expr Triv Ret-Stmt)
    (Start Module)
    (Decl
      (extern Var (Type *) -> Type)
      (fn Var (Var *) Type
          (input-regions ((RegionVar *) *))
          (output-regions (RegionVar *))
          Stmt))
    (Stmt
      (error Var)
      (print Triv)
      (print Triv Triv)
      (assert Triv)
      (set! Triv Triv)
      (kernel Type
        (Triv +)
        (free-vars (Var Type) *)
        Stmt)
      (let ((Var Type Lifted-Expr) *) Stmt)
      (let ((Var Type) *) Stmt)
      (let-region (RegionVar *) Stmt)
      (if Triv Stmt)
      (if Triv Stmt Stmt)
      (for (Var Triv Triv Triv) Stmt)
      (while Triv Stmt)
      (do Triv)
      (begin Stmt * Stmt)
      Ret-Stmt))

  (infer-regions (%inherits Module Ret-Stmt)
    (Start Module)
    (Decl
      (extern Var (Rho-Type *) -> Rho-Type)
      (fn Var (Var *) Type
          (input-regions ((Var *) *))
          (output-regions (Var *))
          Body))
    (Body
      (begin Stmt * Body)
      (let ((Var Rho-Type Lifted-Expr) *) Body)
      (let ((Var Rho-Type) *) Body)
      (let-region (Var) Body)
      (if Triv Body)
      (if Triv Body Body)
      Ret-Stmt)
    (Stmt
      (print Triv)
      (print Triv Triv)
      (assert Triv)
      (set! Triv Triv)
      (kernel
        (Triv +)
        (free-vars (Var Rho-Type) *)
        Stmt)
      (let ((Var Rho-Type Lifted-Expr) *) Stmt)
      (let ((Var Rho-Type) *) Stmt)
      (let-region (Var) Stmt)
      (if Triv Stmt)
      (if Triv Stmt Stmt)
      (for (Var Triv Triv Triv) Stmt)
      (while Triv Stmt)
      (do Triv)
      (begin Stmt * Stmt)
      (error Var)
      Ret-Stmt)
    (Lifted-Expr
      (make-vector Rho-Type Triv)
      Triv)
    (Triv
      (bool Boolean)
      (char Char)
      (int Integer)
      (u64 Number)
      (float Float)
      (str String)
      (var Rho-Type Var)
    (empty-struct)  
      (int->float Triv)
      (length Triv)
      (addressof Triv)
      (deref Triv)
      (if Triv Triv Triv)
      (call Triv Triv *)
      (c-expr C-Type Var)
      (vector-ref Rho-Type Triv Triv)
      (not Triv)
      (Binop Triv Triv)
      (Relop Triv Triv)))

  (uglify-vectors (%inherits Module)
    (Start Module)
    (Decl
      (extern Var (Type *) -> Type)
      (global Var Type Expr)
      (typedef Var Type)
      (fn Var (Var *) Type Body))
    (Body
      (begin Stmt * Body)
      (let ((Var Type Expr) *) Body)
      (let ((Var Type) *) Body)
      (let-region (Var *) Body)
      (if Expr Body)
      (if Expr Body Body)
      Ret-Stmt)
    (Ret-Stmt (return Expr) (return))
    (Stmt
      (print Expr)
      (print Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (kernel (Expr +) 
        (free-vars (Var Type) *)
        Stmt)
      (let ((Var Type Expr) *) Stmt)
      (let ((Var Type) *) Stmt)
      (let-region (Var *) Stmt)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (for (Var Expr Expr Expr) Stmt)
      (while Expr Stmt)
      (do Expr)
      (begin Stmt +)
      (error Var)
      Ret-Stmt)
    (Expr
      (bool Boolean)
      (char Char)
      (int Integer)
      (u64 Number)
      (str String)
      (float Float)
      (var Type Var)
      (empty-struct)  
      (alloc Expr Expr)
      (region-ref Type Expr Expr)
      (c-expr C-Type Var)
      (if Expr Expr Expr)
      (call Expr Expr *)
      (cast Type Expr)
      (sizeof Type)
      (addressof Expr)
      (deref Expr)
      (vector-ref Type Expr Expr)
      (length Expr)
      (not Expr)
      (field Expr Var)
      (Relop Expr Expr)
      (Binop Expr Expr)))

  (remove-let-regions (%inherits Module Decl Ret-Stmt Expr)
    (Start Module)
    (Body
      (begin Stmt * Body)
      (let ((Var Type Expr) *) Body)
      (let ((Var Type) *) Body)
      (if Expr Body)
      (if Expr Body Body)
      Ret-Stmt)
    (Stmt
      (error Var)
      (print Expr)
      (print Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (kernel (Expr +) 
        (free-vars (Var Type) *)
        Stmt)
      (let ((Var Type Expr) *) Stmt)
      (let ((Var Type) *) Stmt)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (for (Var Expr Expr Expr) Stmt)
      (while Expr Stmt)
      (do Expr)
      (begin Stmt +)
      Ret-Stmt))


  (flatten-lets (%inherits Module Decl Ret-Stmt)
    (Start Module)
    (Body
      (begin Stmt * Body)
      (if Expr Body)
      (if Expr Body Body)
      Ret-Stmt)
    (Stmt
      (print Expr)
      (print Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (kernel (Expr +)
       (free-vars (Var Type) *) Stmt)
      (let Var Type Expr)
      (let Var Type)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (for (Var Expr Expr Expr) Stmt)
      (while Expr Stmt)
      (do Expr)
      (begin Stmt +)
      (error Var)
      Ret-Stmt)
    (Expr
      (bool Boolean)
      (char Char)
      (int Integer)
      (u64 Number)
      (str String)
      (float Float)
      (var Type Var)
    (empty-struct)  
      (alloc Expr Expr)
      (region-ref Type Expr Expr)
      (c-expr Type Var)
      (if Expr Expr Expr)
      (call Expr Expr *)
      (cast Type Expr)
      (sizeof Type)
      (addressof Expr)
      (deref Expr)
      (vector-ref Type Expr Expr)
      (length Expr)
      (not Expr)
      (field Expr Var)
      (Relop Expr Expr)
      (Binop Expr Expr)))

  (hoist-kernels (%inherits Module Body Ret-Stmt)
    (Start Module)
    (Decl
      CommonDecl
      (gpu-module Kernel *)
      (global Var Type Expr))
    (Kernel
      CommonDecl
      (kernel Var ((Var Type) *) Stmt))
    (CommonDecl
     (fn Var (Var *) ((Type *) -> Type) Body)
     (typedef Var Type)
     (extern Var (Type *) -> Type))
    (Stmt 
      (print Expr)
      (print Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (apply-kernel Var (Expr +) Expr *)
      (let Var Type Expr)
      (let Var Type)
      (begin Stmt * Stmt)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (for (Var Expr Expr Expr) Stmt)
      (while Expr Stmt)
      (do Expr)
      (error Var)
      Ret-Stmt)
    (Expr
      (bool Boolean)
      (char Char)
      (int Integer)
      (u64 Number)
      (str String)
      (float Float)
      (var Type Var)
      (var C-Type Var)
      (empty-struct)
      (alloc Expr Expr)
      (region-ref Type Expr Expr)
      (c-expr C-Type Var)
      (if Expr Expr Expr)
      (field Expr Var)
      (deref Expr)
      (call Expr Expr *)
      (cast Type Expr)
      (sizeof Type)
      (addressof Expr)
      (vector-ref Type Expr Expr)
      (not Expr)
      (Relop Expr Expr)
      (Binop Expr Expr)))

  (generate-kernel-calls
    (%inherits Module Kernel Decl Expr Body Ret-Stmt CommonDecl)
    (Start Module)
    (Stmt
      (error Var)
      (print Expr)
      (print Expr Expr)
      (assert Expr)
      (set! Expr Expr)
      (let Var C-Type Expr)
      (let Var C-Type)
      (begin Stmt * Stmt)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (for (Var Expr Expr Expr) Stmt)
      (while Expr Stmt)
      (do Expr)
      Ret-Stmt))

  (compile-module
    (%inherits Kernel Body Ret-Stmt)
    (Start Module)
    (Module (Decl *))
    (Decl
      CommonDecl
      (include String)
      (gpu-module Kernel *)
      (global Var Type Expr)
      (typedef Var Type))
    (CommonDecl
     (func Type Var ((Var Type) *) Body)
     (typedef Var Type)
     (extern Type Var (Type *))
     (extern Var (Type *) -> Type))
    (Stmt
      (print Expr)
      (print Expr Expr)
      (set! Expr Expr)
      (if Expr Stmt)
      (if Expr Stmt Stmt)
      (let Var C-Type Expr)
      (let Var C-Type)
      (begin Stmt * Stmt)
      (for (Var Expr Expr Expr) Stmt)
      (while Expr Stmt)
      (do Expr)
      Ret-Stmt)
    (Expr
      (bool Boolean)
      (char Char)
      (int Integer)
      (u64 Number)
      (str String)
      (float Float)
      (var Var)
    (empty-struct)  
      (alloc Expr Expr)
      (region-ref Type Expr Expr)
      (c-expr Var)
      (deref Expr)
      (field Expr Var)
      (field Expr Var Type)
      (call Expr Expr *)
      (assert Expr)
      (cast Type Expr)
      (if Expr Expr Expr)
      (sizeof Type)
      (addressof Expr)
      (vector-ref Expr Expr)
      (not Expr)
      (Relop Expr Expr)
      (Binop Expr Expr)))

  (convert-types (%inherits Module Stmt Body Ret-Stmt)
    (Start Module)
    (Decl
      CommonDecl
      (include String)
      (gpu-module Kernel *)
      (global C-Type Var Expr))
    (CommonDecl
     (func C-Type Var ((Var C-Type) *) Body)
     (typedef Var C-Type)
     (extern C-Type Var (C-Type *)))
    (Kernel
      CommonDecl
      (kernel Var ((Var Type) *) Stmt))
    (Expr
      (bool Boolean)
      (char Char)
      (int Integer)
      (u64 Number)
      (str String)
      (float Float)
      (var Var)
      (empty-struct)
      (alloc Expr Expr)
      (region-ref Type Expr Expr)
      (c-expr Var)
      (deref Expr)
      (field Expr Var)
      (field Expr Var C-Type)
      (call Expr Expr *)
      (assert Expr)
      (if Expr Expr Expr)
      (cast C-Type Expr)
      (sizeof C-Type)
      (addressof Expr)
      (vector-ref Expr Expr)
      (not Expr)
      (Relop Expr Expr)
      (Binop Expr Expr)))

  )
)
