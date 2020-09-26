(* FIXME: arity of run_local reference is off, it's 1 when it should be 0
 *)
let rec run_local () =
  let x = run_local in
  let y = `Atom in
  y

(* FIXME: __MODULE__ is not being found, and ends up as an empty string
*)
let rec run_macros () =
  let z = __MODULE__ in
  z

module Nested = struct
  let x () = `compiler "caramel"

  let w () = `version `kind_of_working
end

let rec run_nested () =
  Nested.x ();
  Nested.w ()

(* FIXME: name resolution is wonky here and Nested.x is resolved to x.
 *)
let run_nested_ambiguous () =
  let x () = 1 in
  Nested.x ()
