# Development with DevContainer (VS Code)

## Requirements

This project is setup to run in a DevContainer. Ensure requirements to run in a DevContainer:

1. [Git](https://gitlab.uzh.ch/econ/it/engineering-public/-/wikis/git) installed
1. Source Tree for GitLab setup (see [Install user interface](https://gitlab.uzh.ch/econ/it/engineering-public/-/wikis/git#install-user-interface) and [Configure GitLab for Source Tree](https://gitlab.uzh.ch/econ/it/engineering-public/-/wikis/git#configure-gitlab-for-source-tree))
1. [Docker](/Technologies/Docker) installed
1. [Visual Studio Code](https://code.visualstudio.com/) (VS Code) installed
1. VS Code Extension [Remote Container](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) installed

Your SSH folder and Git config gets mapped to the container. You should be able to use SSH and Git inside the
container. Please ensure `~/.gitconfig` doesn't contain absolute paths (you may use the `~` profile prefix, i.e.
`excludesfile = ~/.gitignore_global`). **Please note:** You probably have to update Sourcetree settings. In its
settings "General" tab uncheck "Allow Sourcetree to modify your global Mercurial and Git configuration files".

## Start

Click on the icon similar to "><" in the bottom left corner and select `Remote-Containers: Reopen in Container`.
If any changes were made to files in `.devcontainer` folder the Container should be rebuilt (`Remote-Containers: Rebuild Container`)

## Database View

There is an `Adminer` container added to the development package. To be able to use it, follow these few steps:

1. Uncomment its line in the `.devcontainer/devcontainer.json` under `runServices`
1. Use `Remote-Containers: Rebuild Container` that it will also create and startup the `Adminer` container
1. Open your web browser and open `localhost:8080`
