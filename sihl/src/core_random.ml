let () = Stdlib.Random.self_init ()

module Uuid : sig
  type t

  val create : unit -> string
  val of_string : ?pos:int -> string -> t option
  val to_binary_string : t -> string
end = struct
  include Uuidm

  let random_state = Random.State.make_self_init ()
  let create () = Uuidm.v4_gen random_state () |> Uuidm.to_string
end

let rec chars result n =
  if n > 0
  then chars (List.cons (Char.chr (Stdlib.Random.int 255)) result) (n - 1)
  else result |> List.to_seq |> String.of_seq
;;

let bytes nr = chars [] nr

let base64 nr =
  Base64.encode_string ~alphabet:Base64.uri_safe_alphabet (bytes nr)
;;

exception Exception of string

let random_cmd =
  Core_command.make
    ~name:"random"
    ~help:"<number of bytes>"
    ~description:
      "Generates a random string with the given length in bytes. The string is \
       base64 encoded. Use the generated value for SIHL_SECRET."
    (function
    | [ n ] ->
      (match int_of_string_opt n with
       | Some n ->
         print_endline @@ base64 n;
         Lwt.return @@ Some ()
       | None -> failwith "Invalid number of bytes provided")
    | _ -> Lwt.return None)
;;
