[%raw "require('isomorphic-fetch')"];
open Jest;
module Async = SihlCoreAsync;

module Integration = {
  let setupHarness = apps => {
    beforeAllPromise(_ => SihlCoreMain.Manager.startApps(apps));
    beforeEachPromise(_ => SihlCoreMain.Manager.clean());
    afterAllPromise(_ => SihlCoreMain.Manager.stop());
  };
};
