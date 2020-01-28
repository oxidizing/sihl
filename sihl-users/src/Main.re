module Sihl = {
  module Core = SihlCore.SihlCore;
};

module Routes = {
  let get = () => [];
};

module App = {
  let name = "User Management App";
  let routes = Routes.get();
  let start = () => {
    Sihl.Core.Log.info("Starting app " ++ name, ());
  };
};

App.start();
