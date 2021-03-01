(* This is the entry point to the Sihl app.

   The parts of your app come together here and are wired to the services. This
   is also the central registry for infrastructure services. *)

let commands = [ Command.Add_todo.run ]
let migrations = Database.Migration.all

(* Cleaners clean repositories and can be used before running tests to ensure
   clean state. All built-in services register their cleaners. *)
let cleaners = [ Todo.cleaner ]

(* Jobs can be put on the queue for the queue service to take care of. The queue
   service only processes jobs that have been registered. *)
let jobs = []

let services =
  [ Sihl.Database.Migration.PostgreSql.register ()
  ; Sihl_token.PostgreSql.register ()
  ; Sihl_email.Template.PostgreSql.register ()
  ; Sihl_user.PostgreSql.register ()
  ; Sihl_queue.PostgreSql.register ~jobs ()
  ; Service.PasswordResetService.register ()
  ; Sihl_email.Smtp.register ()
  ; Sihl.Schedule.register ()
  ; Sihl.Web.Http.register ~routers:Web.Route.all ()
  ]
;;

let () = Sihl.App.(empty |> with_services services |> run ~commands)
