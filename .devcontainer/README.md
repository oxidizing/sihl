# Development with DevContainer (VS Code)

This project is setup to run in a DevContainer. DevContainers are based on Docker images. This setup uses cached volumes (`/home/opam/.opam`, `/workspace/_build`, and `/workspace/node_modules`) to speed up build time. When you are expecting problems and you want to clear everything, don not forget to delete them too. This DevContainer is configured to run with Postgres, change `DATABASE_URL` to run with MariaDB (setup is prepared).

## Requirements

1. Ensure requirements are installed:
   1. Docker
   1. [Visual Studio Code](https://code.visualstudio.com/) (VS Code)
   1. VS Code Extension [Remote Container](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
1. Your SSH folder and Git config gets mapped to the container. You should be able to use SSH and Git inside the container. Please ensure `~/.gitconfig` doesn't contain absolute paths (you may use the `~` profile prefix, i.e. `excludesfile = ~/.gitignore_global`). **Sourcetree note:** You probably have to update Sourcetree settings. In its settings "General" tab uncheck "Allow Sourcetree to modify your global Mercurial and Git configuration files".

## Start

Click on the icon similar to "><" in the bottom left corner and select `Remote-Containers: Reopen in Container`. If any changes were made to files in `.devcontainer` folder the Container should be rebuilt (`Remote-Containers: Rebuild Container`)

## Customization

Use the `.env.sample` file to further customize your installation. `DATABASE_URL`, `DATABASE_POOL_SIZE`, and `SIHL_SECRET` is already set by `.devcontainer/docker-compose.yml`.

## Database View

There is an `Adminer` container added to the development package. To be able to use it, follow these few steps:

1. Uncomment its line in the `.devcontainer/devcontainer.json` under `runServices`
1. Use `Remote-Containers: Rebuild Container` that it will also create and startup the `Adminer` container
1. Open your web browser and open `localhost:8080`
