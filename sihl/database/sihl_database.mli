(** Use this module to query the database, implement and run migrations, clean
    repositories, turn HTTP queries into SQL queries or for sane entity identifier
    handling. *)

(** {1 Installation}

    The database service uses {:https://github.com/paurkedal/ocaml-caqti} under the hood.
    Caqti can dynamically load the correct driver based on the [DATABASE_URL]
    (postgresql://).

    Caqti supports following databases (caqti drivers):

    - PostgreSQL (caqti-driver-postgresql)
    - MariaDB (caqti-driver-mariadb)
    - SQLite (caqti-driver-sqlite)

    {[
      module Log = Sihl.Log.Service.Make ()
      module Config = Sihl.Config.Service.Make (Log)
      module Db = Sihl.Database.Service.Make (Config) (Log)
    ]}

    Install one of the drivers listed above.

    [opam install caqti-driver-postgresql]

    Add the driver to your [done] file:

    [caqti-driver-postgresql] *)

(** {1 Usage}

    Register the database middleware, so other services can query the database with the
    context that contains the database pool.

    {[
      module DbMiddleware = Sihl.Web.Middleware.Db.Make (Service.Db)

      let middlewares = [ DbMiddleware.m () ]
    ]}

    The database service should be used mostly in repositories and not in services
    themselves.

    pizza_order_repo.ml:

    {[
      module MakePostgreSql (DbService : Sihl.Database.Service.Sig.SERVICE) :
        Pizza_order_sig.REPO = struct
        let find_request =
          Caqti_request.find_opt
            Caqti_type.string
            Model.t
            "SELECT uuid, customer, pizza, amount, status, confirmed, created_at, \
             updated_at FROM pizza_orders WHERE pizza_orders.uuid = ?::uuid"
        ;;

        let find ctx ~id =
          DbService.query ctx (fun connection ->
              let module Connection = (val connection : Caqti_lwt.CONNECTION) in
              Connection.find_opt get_request id |> Lwt_result.map_err Caqti_error.show)
        ;;
      end
    ]}

    pizza_order_service.ml:

    {[
      module Make (Repo : Pizza_order_sig.REPO) : Pizza_order_sig.SERVICE = struct
        let find ctx ~id = Repo.find ctx ~id
      end
    ]}

    Then you can use the service:

    {[
      module PizzaOrderRepo = Pizza_order_repo.MakePostgreSql (Service.Db)
      module PizzaOrderService = Pizza_order_service.Make (PizzaOrderRepo)
      let get_pizza_order =
        Sihl.Web.Route.get "/pizza-orders/:id" (fun ctx ->
            Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)
      let get_pizza_order =
        Sihl.Web.Route.get "/pizza-orders/:id" (fun ctx ->
            let id = Sihl.Web.Req.param ctx "id" in
            let pizza = PizzaOrderService.find ctx ~id in
            ...
            )
    ]} *)

module Service : Sig.SERVICE
module Ql = Ql
module View = View
module Id = Id
module Sig = Sig
