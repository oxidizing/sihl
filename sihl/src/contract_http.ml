exception Exception of string

let name = "http"

module type Sig = sig
  val register
    :  ?not_found_handler:
         (Opium.Request.t -> (Opium.Headers.t * Opium.Body.t) Lwt.t)
    -> ?middlewares:Rock.Middleware.t list
    -> Web.router
    -> Core_container.Service.t

  include Core_container.Service.Sig
end
