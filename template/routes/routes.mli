val global_middlewares : Rock.Middleware.t list

module Site : sig
  val hello : Sihl.Web.router
  val middlewares : Rock.Middleware.t list
end

module Api : sig
  val hello : Sihl.Web.router
  val middlewares : Rock.Middleware.t list
end

val router : Sihl.Web.router
