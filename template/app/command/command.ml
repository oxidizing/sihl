let multiply =
  Sihl.Command.make
    ~name:"multiply"
    ~help:"<int> <int>"
    ~description:"Multiplies two integers and prints the result"
    (function
      | [ n1; n2 ] ->
        (match int_of_string_opt n1, int_of_string_opt n2 with
        | Some n1, Some n2 ->
          print_endline @@ string_of_int @@ (n1 * n2);
          Lwt.return @@ Some ()
        | _ -> Lwt.return None)
      | _ -> Lwt.return None)
;;
