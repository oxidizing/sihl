module type Sig = sig
  val insert : string -> unit Lwt.t
  val has : string -> bool Lwt.t
  val register_cleaner : unit -> unit
end

module InMemory : Sig = struct
  let store = Hashtbl.create 100

  let insert token =
    Hashtbl.add store token ();
    Lwt.return ()
  ;;

  let has token = Lwt.return @@ Hashtbl.mem store token

  let register_cleaner () =
    Sihl_core.Cleaner.register_cleaner (fun () -> Lwt.return (Hashtbl.clear store))
  ;;
end
