(* This is the entry point to the Sihl app.

   The parts of your app come together here and are wired to the services. This
   is also the central registry for infrastructure services. *)

let migrations = Database.Migration.all

(* Cleaners clean repositories and can be used before running tests to ensure
   clean state. All built-in services register their cleaners. *)
let cleaners = [ Todo.cleaner ]

(* Jobs can be put on the queue for the queue service to take care of. The queue
   service only processes jobs that have been registered. *)
let jobs = []

let services =
  [ Service.Migration.register ~migrations ()
  ; Service.Token.register ()
  ; Service.EmailTemplate.register ()
  ; Service.MarketingEmail.register ()
  ; Service.TransactionalEmail.register ()
  ; Service.User.register ()
  ; Service.PasswordResetService.register ()
  ; Service.Queue.register ~jobs ()
  ; Sihl.Schedule.register ()
  ; Sihl.Web.Http.register ~routers:[ Routes.Api.router; Routes.Site.router ] ()
  ]
;;

let () =
  Sihl.App.(
    empty |> with_services services |> run ~commands:[ Command.Add_todo.run ])
;;
