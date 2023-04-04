
(* This file is free software, part of dolmen. See file "LICENSE" for more information. *)

(** AST requirement for the Smtlib format.
    The smtlib format is widely used among SMT solvers, and is the language
    of the smtlib benchmark library. Terms are expressed as s-expressions,
    and top-level directives include everything needed to use a prover
    in an interactive loop (so it includes directive for getting and setting options,
    getting information about the solver's internal model, etc...) *)

module type Id = sig
  include Dolmen_smtlib2_v6_script.Id
end

module type Term = sig
  include Dolmen_smtlib2_v6_script.Term
end
(** Implementation requirements for Smtlib terms. *)

module type Statement = sig
  include Dolmen_smtlib2_v6_script.Statement

  val sys_def : location -> id -> (string * term list) list -> (id * id * term list) list -> (string * term ) list -> t
  (** TODO  *)
    
  val sys_check : ?loc:location ->
    id ->
    (string * term list) list ->
    (string * (id * term)) list -> (id * term list) list -> t

  val declare_enum_sort :  location -> id -> (id list) -> t
  (** TODO  *)

end
(** implementation requirement for smtlib statements. *)

(** TODO: Verify that the View module was not used. (it has been deleted here) *)
