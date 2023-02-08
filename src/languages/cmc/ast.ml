
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

  val sys_def   : ?loc:location -> id -> term list -> term list -> term -> term -> t
  (** Defines a new function. [fun_def f args ret body] is such that
      applications of [f] are equal to [body] (module substitution of the arguments),
      which should be of type [ret]. *)
    
end
(** implementation requirement for smtlib statements. *)

(** TODO: Verify that the View module was not used. (it has been deleted here) *)
