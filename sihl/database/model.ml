type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t
type connection = (module Caqti_lwt.CONNECTION)
