let run =
  let open Lwt.Syntax in
  Sihl.Command.make
    ~name:"add-todo"
    ~help:"<todo description>"
    ~description:"Adds a new todo to the backlog"
    (fun args ->
      match args with
      | [ description ] ->
        let* _ = Todo.create description in
        Lwt.return ()
      | _ -> raise (Sihl.Command.Exception "Usage: <todo description>"))
;;
