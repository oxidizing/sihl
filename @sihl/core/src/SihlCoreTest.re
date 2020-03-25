[%raw "require('isomorphic-fetch')"];

module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  open Jest;
  module Async = SihlCoreAsync;
  module SihlCoreMain = SihlCoreMain.Make(Persistence);
  module Integration = {
    let setupHarness = apps => {
      beforeAllPromise(_ => SihlCoreMain.Manager.startApps(apps));
      beforeEachPromise(_ => SihlCoreMain.Manager.clean());
      afterAllPromise(_ => SihlCoreMain.Manager.stop());
    };
  };
};
