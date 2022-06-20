let () =
  let open Sihl.Command in
  Printexc.record_backtrace true;
  register Command_init.t;
  register Command_dev.t;
  register Command_shell.t;
  register Command_test.t;
  register Command_test.cov;
  register Command_migrate.t;
  register Command_migrate.gen;
  register Command_migrate.down;
  Sihl.Command.run ()
;;
