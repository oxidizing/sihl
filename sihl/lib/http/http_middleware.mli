val create :
  name:string ->
  filter:
    ((Opium.Std.Request.t, Opium.Std.Response.t) Opium.Std.Rock.Service.t ->
    Opium.Std.Request.t ->
    (Opium.Std.Response.t, Core_error.t) result Lwt.t) ->
  Opium.Std.Rock.Middleware.t
