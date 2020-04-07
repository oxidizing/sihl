module Make = (Persistence: SihlCore_Common.Db.PERSISTENCE) => {
  module Repo = SihlCore_App_Repo.Make(Persistence);
  module Http = SihlCore_App_Http.Make(Persistence);
  module Main = SihlCore_App_Main.Make(Persistence);
  module Test = Main.Test;
  module Cli = SihlCore_App_Cli.Make(Persistence);
};
