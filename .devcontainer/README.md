# Development with DevContainer (VS Code)

This project is set up to run in a DevContainer. DevContainers are based on Docker images. The image is the pool tool's build image (RHEL 9, OCaml 5.5.2, opam 2.6). This setup uses named volumes (`opam-5.5.2-2.6` for `/home/opam/.opam`, `build` for `/workspace/_build`, and `db-postgres` and `db-mariadb` for the database data) to speed up build time and keep data across rebuilds. When you are expecting problems and you want to clear everything, do not forget to delete them too. The `DATABASE_URL` points to PostgreSQL; change it in `.devcontainer/docker-compose.yml` to run with MariaDB (setup is prepared).

## Requirements

1. Ensure requirements are installed:
   1. Docker
   1. [Visual Studio Code](https://code.visualstudio.com/) (VS Code)
   1. VS Code Extension [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
1. Copy `.devcontainer/.env.example` to `.devcontainer/.env` and fill in your Git name and email, your GitHub username and a [fine-grained personal access token](https://github.com/settings/personal-access-tokens) for `uzh/sihl` with "Contents: Read and write". The `.env` file is gitignored. Inside the container, Git uses this token over HTTPS (also for `git@github.com:` remotes); your SSH keys and Git config are not mounted and the host's SSH agent is not forwarded.

## Start

Click on the icon similar to "><" in the bottom left corner and select `Dev Containers: Reopen in Container`. If any changes were made to files in `.devcontainer` folder the Container should be rebuilt (`Dev Containers: Rebuild Container`).

`make` inside the container is aliased to `.devcontainer/Makefile`, which forwards every target to the root `Makefile`, so it works from any directory.

## Customization

`DATABASE_URL`, `DATABASE_URL_TEST_MARIADB`, `DATABASE_URL_TEST_POSTGRESQL`, `DATABASE_POOL_SIZE`, and `SIHL_SECRET` are set by `.devcontainer/docker-compose.yml`. The tests use the `dev` database as `admin` for both drivers.

## Databases from the host

The databases are exposed on ports that don't clash with local installations:

| Database   | Host port | User / password    | Database |
| ---------- | --------- | ------------------ | -------- |
| PostgreSQL | 3347      | `admin`/`password` | `dev`    |
| MariaDB    | 3346      | `admin`/`password` | `dev`    |

## Database View

There is an `Adminer` container added to the development package. To be able to use it, follow these few steps:

1. Uncomment its line in the `.devcontainer/devcontainer.json` under `runServices`
1. Use `Dev Containers: Rebuild Container` that it will also create and startup the `Adminer` container
1. Open your web browser and open `localhost:8080`
