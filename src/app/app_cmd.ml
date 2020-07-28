module Sig = App_sig

module Make (Kernel : Sig.KERNEL) (App : Sig.APP) = struct
  module App = App_core.Make (Kernel) (App)

  let start =
    Cmd.create ~name:"start"
      ~description:
        "Start the Sihl app including all registered services and the \
         schedules." ~fn:(fun _ -> App.run ())
end
