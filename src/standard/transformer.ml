
(* This file is free software, part of dolmen. See file "LICENSE" formore information *)

module Make
    (Loc    : Loc.S)
    (Ty     : sig
       type token
       type statement
       val env : string list
       val incremental : bool
       val error : int -> string
     end)
    (Lex    : Dolmen_intf.Lex.S with type token := Ty.token)
    (Parse  : Dolmen_intf.Parse.S with type token := Ty.token
                                   and type statement := Ty.statement) = struct


  (* Module Includes
     --------------- *)

  include Ty

  module Lexer = Lex
  module Parser = Parse


  (* Finding include files
     --------------------- *)

  let rec find_env file = function
    | [] -> None
    | var :: r ->
      begin match Sys.getenv var with
        | dir ->
          let f = Filename.concat dir file in
          if Sys.file_exists f then Some f
          else find_env file r
        | exception Not_found ->
          find_env file r
      end

  let find ?(dir="") file =
    if Filename.is_relative file then begin
      let f = Filename.concat dir file in
      if Sys.file_exists f then
        Some f
      else
          find_env file Ty.env
    end else if Sys.file_exists file then
      Some file
    else
      None


  (* Menhir state & checkpoint manipulations
     --------------------------------------- *)

  let state checkpoint =
     match (checkpoint : _ Parser.MenhirInterpreter.checkpoint) with
     | HandlingError env ->
       Parser.MenhirInterpreter.current_state_number env
     | _ -> assert false (* this cannot happen, I promise *)

  let error_message token checkpoint =
    let s = state checkpoint in
    match String.trim (Ty.error s) with
    | exception Not_found ->
      Format.dprintf "Syntax error"
    | "<YOUR SYNTAX ERROR MESSAGE HERE>" ->
      Format.dprintf "Syntax error"
    | msg ->
      begin match Misc.split_on_char '\n' msg with
        | production :: l ->
          let expected = String.concat " " l in
          begin match token with
            | Some tok ->
              let tok_descr = Lexer.descr tok in
              Format.dprintf
                "@[<v>@[<hv>while parsing %s,@ read %a,@]@ @[<hov 2>but expected %a@]@]"
                production Tok.print tok_descr
                Format.pp_print_text expected
            | None ->
              Format.dprintf
                "@[<v>while parsing %s@ @[<hov 2>expected %a@]@ but got %a@]"
                production Format.pp_print_text expected Format.pp_print_text
                "no token (this is weird, please report upstream, ^^)"
          end
        | _ ->
          Format.dprintf "Syntax error"
      end


  (* Parsing loop
     ------------ *)

  let parse_aux ~k_exn newline lexbuf checkpoint =
    (* Token supplier *)
    let last_token = ref None in
    let aux =
      Parser.MenhirInterpreter.lexer_lexbuf_to_supplier
        (Lexer.token newline) lexbuf
    in
    let supplier () =
      let (t, _, _) as res = aux () in
      last_token := Some t;
      res
    in
    (* Incremental loop *)
    let succeed res = res in
    let fail checkpoint =
      let pos = Loc.of_lexbuf lexbuf in
      let msg = error_message !last_token checkpoint in
      let () = k_exn () in
      raise (Loc.Syntax_error (pos, msg))
    in
    let loop = Parser.MenhirInterpreter.loop_handle succeed fail supplier in
    (* Run the loop *)
    let aux () =
      begin match loop (checkpoint Lexing.(lexbuf.lex_curr_p)) with
        | res -> res
        | exception ((Loc.Syntax_error _) as e) ->
          raise e
        | exception ((Loc.Lexing_error _) as e) ->
          raise e
        | exception Lexer.Error ->
          let pos = Loc.of_lexbuf lexbuf in
          let err = Lexing.lexeme lexbuf in
          let () = k_exn () in
          raise (Loc.Lexing_error (pos, err))
        | exception Parser.Error ->
          let pos = Loc.of_lexbuf lexbuf in
          let msg = Format.dprintf "" in
          let () = k_exn () in
          raise (Loc.Syntax_error (pos, msg))
        | exception e ->
          let pos = Loc.of_lexbuf lexbuf in
          let () = k_exn () in
          raise (Loc.Uncaught (pos, e))
      end
    in
    aux

  (* Instantiations of the parsing loop
     ---------------------------------- *)

  let parse_file file =
    let lexbuf, cleanup = Misc.mk_lexbuf (`File file) in
    let newline = Loc.newline file in
    let k_exn () = cleanup () in
    let aux = parse_aux ~k_exn newline lexbuf Parser.Incremental.file in
    let res = aux () in
    let () = cleanup () in
    res

  let parse_input i =
    let lexbuf, cleanup = Misc.mk_lexbuf i in
    let newline = Loc.newline (Misc.filename_of_input i) in
    if not Ty.incremental then begin
      (* If incremental mode is not supported, raise an error rather than
         do weird things. *)
      let msg = Format.dprintf ": @[<hov>%a@]"
          Format.pp_print_text "Input format does not support incremental parsing"
      in
      raise (Loc.Syntax_error (Loc.of_lexbuf lexbuf, msg))
    end;
    let k_exn () = Dolmen_line.consume lexbuf in
    let aux = parse_aux ~k_exn newline lexbuf Parser.Incremental.input in
    aux, cleanup

end

