exception Exception of string

let name = "http"

module type Sig = sig
  val register
    :  ?middlewares:Rock.Middleware.t list
    -> Web.router
    -> Core_container.Service.t

  include Core_container.Service.Sig
end
