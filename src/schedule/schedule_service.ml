open Base

let ( let* ) = Lwt.bind

module Make (Log : Log_sig.SERVICE) : Schedule_sig.SERVICE = struct
  let on_init _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let schedule ctx schedule =
    Log.debug (fun m ->
        m "SCHEDULE: Scheduling %s" (Schedule_core.label schedule));
    let scheduled_function = Schedule_core.scheduled_function schedule in
    let rec loop () =
      let now = Ptime_clock.now () in
      let duration = Schedule_core.run_in schedule ~now in
      Log.debug (fun m ->
          m "SCHEDULE: Running schedule %s in %f seconds"
            (Schedule_core.label schedule)
            duration);
      let* () =
        Lwt.catch
          (fun () -> scheduled_function ctx)
          (fun exn ->
            Log.err (fun m ->
                m
                  "Exception caught while running schedule, this is a bug in \
                   your scheduled function. %s"
                  (Exn.to_string exn));
            Lwt.return ())
      in
      let* () = Lwt_unix.sleep duration in
      loop ()
    in
    loop () |> ignore

  let register_schedules _ _ =
    Logs.warn (fun m ->
        m "SCHEDULE: Registration of schedules is not implemented");
    Lwt_result.return ()
end
