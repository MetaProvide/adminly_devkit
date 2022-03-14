# Adminly devkit
Environment and various scripts used for Adminly development

## Prerequisite
- [Docker](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Composer](https://getcomposer.org/)
- Bash
- [Nodejs v14](https://nodejs.org/)

### Quick note about docker-compose

Currently there is a bug in docker-compose v2 that makes it so the `./adminly-dev.sh` script doesn't work. To workaround this it's recommended to use docker-compose v1 for now. Docker-compose v1 can be installed using pip like so: `pip3 install --user docker-compose`. Make sure `$HOME/.local/bin` is in the beginning of your $PATH.

## Quick Start

1. Install the above dependencies on your computer
2. Create an `adminly` folder and enter it.
3. Clone this repo `git clone https://github.com/MetaProvide/adminly_devkit`
4. Enter the `adminly_devkit` folder and run `./adminly-dev.sh init`
5. Open the `.vscode/project.code-workspace` in VS Code
6. Launch the debugger (This is mainly so the nextcloud container doesn't complain about not connecting to the debug client)
7. Run `./adminly-dev.sh setup` to bring up and configure the container environment
8. Navigate to `http://localhost` and login with Username: `testsson` and Password: `test`
