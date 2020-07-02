(* TODO, use own middleware abstraction *)
(* type t = Web_req.t -> Web_res.t Lwt.t -> Web_req.t -> Web_res.t Lwt.t *)
type t = unit -> Opium_kernel.Rock.Middleware.t
