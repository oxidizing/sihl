module UserListPage: {
  let createElement: Sihl.Admin.admin_page(list(Model.User.t));
};

module UserPage: {let createElement: Sihl.Admin.admin_page(Model.User.t);};
