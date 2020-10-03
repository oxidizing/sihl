open Base
open Lwt.Syntax
module Sig = Schedule_service_sig

module Default : Sig.SERVICE = struct
  let schedule _ schedule =
    let should_stop = ref false in
    let stop_schedule () = should_stop := true in
    Logs.debug (fun m -> m "SCHEDULE: Scheduling %s" (Schedule_core.label schedule));
    let scheduled_function = Schedule_core.scheduled_function schedule in
    let rec loop () =
      let now = Ptime_clock.now () in
      let duration = Schedule_core.run_in schedule ~now in
      Logs.debug (fun m ->
          m
            "SCHEDULE: Running schedule %s in %f seconds"
            (Schedule_core.label schedule)
            duration);
      let* () =
        Lwt.catch
          (fun () -> scheduled_function ())
          (fun exn ->
            Logs.err (fun m ->
                m
                  "Exception caught while running schedule, this is a bug in your \
                   scheduled function. %s"
                  (Exn.to_string exn));
            Lwt.return ())
      in
      let* () = Lwt_unix.sleep duration in
      if !should_stop
      then (
        let () =
          Logs.debug (fun m ->
              m "SCHEDULE: Stop schedule %s" (Schedule_core.label schedule))
        in
        Lwt.return ())
      else loop ()
    in
    loop () |> ignore;
    stop_schedule
  ;;

  let start ctx = Lwt.return ctx
  let stop _ = Lwt.return ()
  let lifecycle = Core.Container.Lifecycle.create "schedule" ~start ~stop

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end
