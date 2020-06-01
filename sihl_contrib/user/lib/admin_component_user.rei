module UserListPage: {
  let createElement: Sihl.Admin.admin_page(list(Sihl.User.t));
};

module UserPage: {let createElement: Sihl.Admin.admin_page(Sihl.User.t);};
