module Async = Sihl.Core.Async;

let commands = Sihl.Core.Cli.registerCommands([Sihl.Users.Cli.createAdmin]);
Sihl.Core.Cli.execute(commands, Node.Process.argv);
