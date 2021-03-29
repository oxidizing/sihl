let () = Caml.Random.self_init ()

let rec chars result n =
  if n > 0
  then chars (List.cons (Char.chr (Caml.Random.int 255)) result) (n - 1)
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
        | None -> raise @@ Exception "Invalid number of bytes provided")
      | _ -> Lwt.return None)
;;
