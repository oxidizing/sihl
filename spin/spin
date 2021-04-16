(name spin-sihl)
(description "Sihl application")

(config project_name
  (input (prompt "Project name"))
  (default "app"))

(config project_slug
  (input (prompt "Project slug"))
  (default (slugify :project_name))
  (rules
    ("The project slug must be lowercase and contain ASCII characters and '-' only."
      (eq :project_slug (slugify :project_slug)))))

(config project_snake
  (default (snake_case :project_slug)))

(config create_switch
  (select
    (prompt "Do you want to create a local switch? (Do you want to install OPAM packages locally?")
    (values Yes No))
  (default false))

(config project_description
  (input (prompt "Description"))
  (default "A short, but powerful statement about your project")
  (rules
    ("The last character of the description cannot be a \".\" to comply with Opam"
      (neq . (last_char :project_description)))))

(config username
  (input (prompt "Name of the author")))

(config github_username
  (input (prompt "Github username"))
  (default :username))

(config database
  (select
    (prompt "Which database do yo use?")
    (values PostgreSql MariaDb))
  (default PostgreSql))

(config ci_cd
  (select
    (prompt "Which CI/CD do you use?")
    (values Github None))
  (default Github))

(config docker
  (select
    (prompt "Do you use Docker?")
    (values Yes No))
  (default Yes))

(ignore
  (files docker/*)
  (enabled_if (neq :docker Yes)))

(ignore
  (files github/*)
  (enabled_if (neq :ci_cd Github)))

; We need to do this because Dune won't copy .github during build
(post_gen
  (actions
    (run mv github .github))
  (enabled_if (eq :ci_cd Github)))

(post_gen
  (actions
    (run make switch)
    (run make build)
    (run make lock))
  (message "🎁  Installing packages in a switch. This might take a couple minutes.")
  (enabled_if (eq :create_switch Yes)))

(post_gen
  (actions
    (run make deps)
    (run make build)
    (run make lock))
  (message "🎁  Installing packages globally. This might take a couple minutes.")
  (enabled_if (eq :create_switch No)))

(example_commands
  (commands
    ("make deps" "Download runtime and development dependencies.")
    ("make build" "Build the dependencies and the project.")
    ("make test" "Starts the test runner.")
    ("make sihl" "Runs the app executable and lists available sub-commands.")
    ("make sihl migrate" "Executes database migrations.")
    ("make dev" "Starts the Sihl app in watch mode"))
  (enabled_if true))