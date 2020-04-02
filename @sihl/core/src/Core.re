module Common = {
  module Async = Common_Async;
  module Base64 = Common_Base64;
  module Uuid = Common_Uuid;
  module Crypt = Common_Crypt;
  module Error = Common_Error;
  module Log = Common_Log;
  module Db = Common_Db;
  module Config = Common_Config;
  module Http = Common_Http;
  module Email = Common_Email;
};

module MakeApp = (Persistence: Common.Db.PERSISTENCE) => {
  module Repo = App_Repo.Make(Persistence);
  module Http = App_Http.Make(Persistence);
  module Main = App_Main.Make(Persistence);
  module Test = Main.Test;
  module Cli = App_Cli.Make(Persistence);
};
