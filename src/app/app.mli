module Sig = App_sig

val start : (module Sig.APP) -> (module Sig.APP) Lwt.t
