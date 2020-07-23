
(* Option helpers *)
(* ************************************************************************ *)

module Options = struct

  let map f = function
    | None -> None
    | Some x -> Some (f x)

end

(* List helpers *)
(* ************************************************************************ *)

module Lists = struct

  let init n f =
    let rec aux acc i =
      if i > n then List.rev acc
      else aux (f i :: acc) (i + 1)
    in
    aux [] 1

  let replicate n x =
    let rec aux x acc n =
      if n <= 0 then acc else aux x (x :: acc) (n - 1)
    in
    aux x [] n

  let take_drop n l =
    let rec aux acc n = function
      | r when n <= 0 -> List.rev acc, r
      | [] -> raise (Invalid_argument "take_drop")
      | x :: r -> aux (x :: acc) (n - 1) r
    in
    aux [] n l

end

(* String manipulation *)
(* ************************************************************************ *)

module Strings = struct

  let to_list s =
    let rec aux s i acc =
      if i < 0 then acc
      else aux s (i - 1) (s.[i] :: acc)
    in
    aux s (String.length s - 1) []

  let is_suffix ~suffix s =
    let k = String.length suffix in
    let n = String.length s in
    if n < k then false
    else begin
      let s' = String.sub s (n - k) k in
      String.equal suffix s'
    end

end

(* Bitvector manipulation *)
(* ************************************************************************ *)

module Bitv = struct

  exception Invalid_char of char



  (* Bitv in binary forms *)

  let check_bin = function
    | '0' | '1' -> ()
    | c -> raise (Invalid_char c)

  let parse_binary s =
    assert (String.length s > 2 && s.[0] = '#' && s.[1] = 'b');
    let s = String.sub s 2 (String.length s - 2) in
    String.iter check_bin s;
    s


  (* Bitv in hexadecimal form *)

  let hex_to_bin = function
    | '0' -> "0000"
    | '1' -> "0001"
    | '2' -> "0010"
    | '3' -> "0011"
    | '4' -> "0100"
    | '5' -> "0101"
    | '6' -> "0110"
    | '7' -> "0111"
    | '8' -> "1000"
    | '9' -> "1001"
    | 'a' | 'A' -> "1010"
    | 'b' | 'B' -> "1011"
    | 'c' | 'C' -> "1100"
    | 'd' | 'D' -> "1101"
    | 'e' | 'E' -> "1110"
    | 'f' | 'F' -> "1111"
    | c -> raise (Invalid_char c)

  let parse_hexa s =
    assert (String.length s > 2 && s.[0] = '#' && s.[1] = 'x');
    let s = String.sub s 2 (String.length s - 2) in
    let b = Bytes.create (String.length s * 4) in
    String.iteri (fun i c ->
        Bytes.blit_string (hex_to_bin c) 0 b (i * 4) 4
      ) s;
    Bytes.to_string b




  (* bitv in decimal form *)

  let int_of_char = function
    | '0' -> 0
    | '1' -> 1
    | '2' -> 2
    | '3' -> 3
    | '4' -> 4
    | '5' -> 5
    | '6' -> 6
    | '7' -> 7
    | '8' -> 8
    | '9' -> 9
    |  c  -> raise (Invalid_char c)

  let char_of_int = function
    | 0 -> '0'
    | 1 -> '1'
    | 2 -> '2'
    | 3 -> '3'
    | 4 -> '4'
    | 5 -> '5'
    | 6 -> '6'
    | 7 -> '7'
    | 8 -> '8'
    | 9 -> '9'
    | _ -> assert false

  (* Implementation of division by 2 on strings, and
     of parsing a string-encoded decimal into a binary bitv,
     taken from
     https://stackoverflow.com/questions/11006844/convert-a-very-large-number-from-decimal-string-to-binary-representation/11007021#11007021 *)

  let divide_string_by_2 b start =
    let b' = Bytes.create (Bytes.length b - start) in
    let next_additive = ref 0 in
    for i = start to Bytes.length b - 1 do
      let c = int_of_char (Bytes.get b i) in
      let additive = !next_additive in
      next_additive := if c mod 2 = 1 then 5 else 0;
      let c' = c / 2 + additive in
      Bytes.set b' (i - start) (char_of_int c')
    done;
    b'

  let rec first_non_zero b start =
    if start >= Bytes.length b then
      None
    else if Bytes.get b start = '0' then
      first_non_zero b (start + 1)
    else
      Some start

  (* Starting from a bytes full of '0', fill it with bits
     coming from the given integer. *)
  let rec parse_int_aux b i n =
    if i < 0 || n <= 0 then b
    else begin
      if n mod 2 = 1 then Bytes.set b i '1';
      parse_int_aux b (i - 1) (n / 2)
    end

  (* Size (in characters) of a decimal integer under which
     int_of_string will work *)
  let int_size_threshold =
    match Sys.int_size with
    (* max_int should be 2147483647 (length 10) *)
    | 31 -> 9
    (* max_int should be 9,223,372,036,854,775,807 (length 19) *)
    | 63 -> 18
    (* weird case, be safe before anyting *)
    | _ -> 0

  let rec parse_decimal_aux res idx b start =
    if idx < 0 then
      res
    else if (Bytes.length b - start) <= int_size_threshold then begin
      match int_of_string (Bytes.to_string b) with
      | i -> parse_int_aux res idx i
      | exception Failure _ -> assert false
    end else begin
      (* if b is odd, set the bit in res to 1 *)
      let c = int_of_char (Bytes.get b (Bytes.length b - 1)) in
      if c mod 2 = 1 then Bytes.set res idx '1';
      (* divide b by 2 *)
      let b' = divide_string_by_2 b start in
      match first_non_zero b' 0 with
      | Some start' -> parse_decimal_aux res (idx - 1) b' start'
      | None -> res
    end

  let parse_decimal s n =
    assert (String.length s > 2 && s.[0] = 'b' && s.[1] = 'v');
    let b = Bytes.of_string (String.sub s 2 (String.length s - 2)) in
    let b' = parse_decimal_aux (Bytes.make n '0') (n - 1) b 0 in
    Bytes.to_string b'

end

(* Fuzzy search maps *)
(* ************************************************************************ *)

module Fuzzy_Map = struct

  module S = Spelll
  module I = S.Index

  (** We use fuzzy maps in order to give suggestions in case of typos.
        Since such maps are not trivial to extend to Dolmen identifiers,
        we map strings (identifier names) to list of associations. *)
  type 'a t = (Dolmen.Std.Id.t * 'a) list I.t

  let eq id (x, _) = Dolmen.Std.Id.equal id x

  let empty = I.empty

  let rec seq_to_list_ s = match s() with
    | Seq.Nil -> []
    | Seq.Cons (x,y) -> x :: seq_to_list_ y

  let get t id =
    let s = Dolmen.Std.Id.(id.name) in
    match seq_to_list_ (I.retrieve ~limit:0 t s) with
    | [l] -> l
    | [] -> []
    | _ -> assert false

  let mem t id =
    List.exists (eq id) (get t id)

  let find t id =
    snd @@ List.find (eq id) (get t id)

  let add t id v =
    let l = get t id in
    let l' =
      if List.exists (eq id) (get t id) then l
      else (id, v) :: l
    in
    I.add t Dolmen.Std.Id.(id.name) l'

  (** Return a list of suggestions for an identifier. *)
  let suggest t ~limit id =
    let s = Dolmen.Std.Id.(id.name) in
    let l = seq_to_list_ (I.retrieve ~limit t s) in
    List.flatten @@ List.map (List.map fst) l

end

(* Fuzzy search hashtables *)
(* ************************************************************************ *)

module Fuzzy_Hashtbl = struct

  (** Fuzzy hashtables are just references to fuzzy maps. *)
  type 'a t = 'a Fuzzy_Map.t ref

  let create () =
    ref Fuzzy_Map.empty

  let find r id =
    Fuzzy_Map.find !r id

  let add r id v =
    r := Fuzzy_Map.add !r id v

  let suggest r ~limit id =
    Fuzzy_Map.suggest !r ~limit id

end

