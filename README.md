# Breedbase

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/bff-afirms/breedbase_dockerfile/blob/master/LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/bff-afirms/breedbase_dockerfile.svg)](https://github.com/phac-nml/rebar/issues)
[![Test CI](https://github.com/BFF-AFIRMS/breedbase_dockerfile/actions/workflows/test.yml/badge.svg)](https://github.com/BFF-AFIRMS/breedbase_dockerfile/actions/workflows/test.yml)
[![Deployment CI](https://github.com/BFF-AFIRMS/breedbase_dockerfile/actions/workflows/deployment.yml/badge.svg)](https://github.com/BFF-AFIRMS/breedbase_dockerfile/actions/workflows/deployment.yml)
[![Dockerhub CI](https://github.com/BFF-AFIRMS/breedbase_dockerfile/actions/workflows/dockerhub.yml/badge.svg)](https://github.com/BFF-AFIRMS/breedbase_dockerfile/actions/workflows/dockerhub.yml)

<p align="center">
  <img src="Breedbase.png" alt="breedbase logo">
</p>

This repo contains the Dockerfile for the BFF-AFIRMS Breedbase webserver, and the docker compose files for joint deployment of the webserver and postgres database.

To learn more about Breedbase:

Access the [SGN repository](https://github.com/solgenomics/sgn) to contribute to the underlying codebase or submit new issues.  
Access the [manual](https://solgenomics.github.io/sgn/) to learn how to use breeDBase's many features.  
Access [breedbase.org](https://breedbase.org/) to explore a default instance of breeDBase.

## Table of Contents

1. [Install](#install)
2. [Deploy](#deploy)
    - [Quick Start](#quick-start)
    - [Production](#production)
    - [Development](#development)
    - [Testing](#testing)
3. [Updating](#updating)
4. [Debugging](#debugging)
5. [Miscellaneous](#miscellaneous)
6. [Credits](#credits)

## Install

1. **Install `docker`**

    Please follow the instructions at https://docs.docker.com/engine/install.  
    You will probably also need to [add your user to the docker group](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user).

1. **Install `docker compose`**

    - Debian/Ubuntu: `apt install docker-compose`

1. **Clone repository**

    ```bash
    git clone https://github.com/bff-afirms/breedbase_dockerfile
    cd breedbase_dockerfile
    ```

## Deploy

All deployment options involve first running setup to create credentials and data directories.

```bash
./setup --site-overlay treeimprovementbase
```

> The `--site-overlay` argument specifies which website skin to use.

```text
-----------------------------------------------------------------------------
2026-02-24 08:02:03     Beginning setup.
2026-02-24 08:02:03     Generating secure credentials: .env
2026-02-24 08:02:03     Creating data directories: data/
2026-02-24 08:02:03     Completed setup.
-----------------------------------------------------------------------------
```

There are four different options for deployment:

- [Quickstart](#quick-start): For those new to breedbase.
- [Production](#production): Run a secure, performant server.
- [Development](#development): Make changes to the applications.
- [Testing](#testing): Run the comprehensive test suite.

### Quick Start

1. **Deploy with docker compose.**

    ```bash
    docker compose up -d
    ```

1. **(Optional): Watch the startup logs.**

    ```bash
    docker compose logs -f breedbase
    ```

1. **Wait for the container to be HEALTHY**.

    Once the breedbase service has started, it must be in a healthy state before it can be accessed. This will take several minutes on first startup.

    ```bash
    docker compose ps breedbase
    ```

    ```text
    NAME            IMAGE                        COMMAND            SERVICE     CREATED         STATUS                   PORTS
    breedbase       bffafirms/breedbase:latest   "/entrypoint.sh"   breedbase   2 minutes ago   Up 2 minutes (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
    ```

1. **Access the breedbase application at: <http://localhost:8080>**

    Login with the following credentials.

    | username | password | role      |
    | -------- | -------- | --------- |
    | admin    | password | curator   |

### Production

After quick-start, deploying for production is the most straightforward. Production mode provides 3 features:

- Randomly generated passwords for default db and web accounts.
- Secures web application with HTTPS.
- Serves static files and js with Caddy for better browsing performance.

> Note: If you have already started the quickstart deployment, you will need to first run these steps:

```bash
# Stop containers
docker compose down
# Clean up data directory
mv data data_quickstart
# Regenerate data directory
./setup --site-overlay treeimprovementbase
```

You can then proceed to the following steps:

1. **Deploy with docker compose**

    ```bash
    docker compose -f compose.production.yml up -d
    ```

1. **Access the breedbase application at: <https://localhost>**

    > The password to log in to the admin account is in the `.env` file as `ADMIN_PASSWORD`.

### Development

Development mode will allow you to make changes to the application in real-time.

1. **Clone the submodules**

    ```bash
    git submodule update --init --recursive --progress
    ```

   > This will clone all the git repos that are needed for breedbase into a subdirectory called `cxgn/`. This directory will be mounted into the container during the compose step, but will still be accessible from the host for development work.

1. **Build Docker Containers**

    ```bash
    docker compose up -f compose.development.yml build
    ```

1. **Deploy with docker compose**

    ```bash
    docker compose up -f compose.development.yml up -d
    ```

1. **Wait for the container to be HEALTHY**.

    ```bash
    docker compose -f compose.development.yml ps breedbase
    ```

1. **Access the applications via web browser.**

    - Breedbase (Main Application): <http://localhost:8080>
    - Keycloak Login (Single-Sign On/OIDC Testing): <http://localhost:9080/auth/realms/Breedbase/account>
    - Keycloak Admin: http://localhost:9080/auth/admin/

    Login with the following credentials.

    | username | password | role            |
    | -------- | -------- | --------------- |
    | admin    | password | curator/admin   |

1. **Make changes to the code under `cxgn/sgn`.**

    - Changes to mason components (`mason`) will update on page refresh.
    - Changes to config files or libraries (`lib`) will trigger the server to restart, with changes going live once the restart is complete.

### Testing

Testing mode is for writing and debugging new tests.

1. **Clone the submodules**

    ```bash
    git submodule update --init --recursive --progress
    ```

Then choose either [Standalone](#standalone) or [Interactive](#interactive) mode from below.

#### Standalone

Tests can be run in `standalone` mode. For each test, a new database and web server will be created, ensuring reproducibility and isolation between tests.

> This mode can be very slow to start up and run.  
> For selenium (browser) tests, open the visualizer at: <http://localhost:8081/vnc.html>  
> The `-s` flag shows stderr, omit for cleaner output.

```bash
# Single
./run_test -s t/unit/CXGN/String
./run_test -s t/selenium2/search/stock.t

# Group
./run_test -s t/unit/CXGN
./run_test -s t/selenium2/search

# Category
./run_test -s t/unit/
./run_test -s t/unit_fixture
./run_test -s t/unit_mech
./run_test -s t/selenium2
```

For less noisy output, omit the `-s` flag that show stderr.

```bash
./run_test t/unit_fixture
```

#### Interactive

Tests can be run in `interactive` mode, where the same database and web server are re-used between tests for quick iteration. This is particulary useful when writing and troubleshooting new tests.

1. **Start up all containers in interactive mode.**

    ```bash
    ./run_test -i
    ```

2. **Open a separate terminal to run the remaining commands.**

3. **Wait for the web server container to be healthy.**

    ```bash
    docker compose -f compose.testing.yml ps breedbase

    NAME                                    IMAGE                        COMMAND                  SERVICE          CREATED              STATUS                        PORTS
    breedbase_dockerfile-breedbase-1   bff-afirms/breedbase:latest   "/entrypoint.sh --in…"   breedbase   About a minute ago   Up About a minute (healthy)   0.0.0.0:3010->3010/tcp, [::]:3010->3010/tcp, 8080/tcp
    ```

4. **Browse the testing environment at: <http://localhost:3010>**

    Login with the following credentials.

    | username | password | role      |
    | -------- | -------- | --------- |
    |janedoe   | secretpw | curator   |
    |johndoe   | secretpw | submitter |
    |freddy    | atgc     | user      |

5. **Connect to the test container.**

    ```bash
    docker compose -f compose.testing.yml exec breedbase bash

    # Find the name of the test database
    psql -l

    # Export the db as a variable (example)
    export TEST_DB_NAME=test_db_2026_2_25_22_22794
    ```

6. **Run tests in the container.**

    > For selenium (browser) tests, open the visualizer at: <http://localhost:8081/vnc.html>

    ```bash
    # Single
    perl t/test_fixture.pl t/unit/CXGN/String
    perl t/test_fixture.pl t/selenium2/search/stock.t

    # Group
    perl t/test_fixture.pl t/unit/CXGN
    perl t/test_fixture.pl t/selenium2/search

    # Category
    perl t/test_fixture.pl t/unit/
    perl t/test_fixture.pl t/unit_fixture
    perl t/test_fixture.pl t/unit_mech
    perl t/test_fixture.pl t/selenium2/01_list
    perl t/test_fixture.pl t/selenium2/02_trial
    ```

To troubleshoot selenium tests:

- Open the Selenium Hub: <http://localhost:4444/wd/hub/static/resource/hub.html>
- Click `Create Session` -> `Firefox`
- Open the Visualizer to see the Firefox window: <http://localhost:8081/vnc.html>

## Updating

To update to the latest changes from the [upstream repo](https://github.com/solgenomics/breedbase_dockerfile).

1. Update the `master` branch to have the latest changes from the [upstream repo](https://github.com/solgenomics/breedbase_dockerfile).

    ```bash
    git checkout master
    git remote add upstream https://github.com/solgenomics/breedbase_dockerfile
    git pull upstream master
    git pull upstream --tags
    ```

2. Checkout the commit or tag you want to update to.

    ```bash
    # sgn-447.0 = breedbase_dockerfile v1.98
    git checkout v1.98
    ```

3. Create a new branch off of `bff-afirms`.

    ```bash
    git checkout bff-afirms
    git submodule update --recursive --progress --init
    git checkout -b bff-afirms-sgn-447.0
    ```

4. Merge the upstream changes into the new branch.

    > Do not rebase!

    ```bash
    git checkout bff-afirms-sgn-447.0
    git merge master
    ```

5. Push to GitHub.

    ```bash
    git push --set-upstream origin bff-afirms-sgn-447.0
    ```

6. Open a pull request.

    ```yaml
    Base Repository: BFF-AFIRMS/breedbase_dockerfile
    Base: bff-afirms
    Compare: bff-afirms-sgn-447.0
    ```

    There will be a larger number of commits in the history, because the BFF-AFIRMS branch split off of the upstream at version `sgn-444.0`. These will be squashed into one final commit reflecting the single update.

7. Confirm that the tests all pass before `Squash and Merge`.

You have now successfully updated to the latest SGN changes while keeping the BFF-AFIRMS features.

## Debugging

Docker has a [wealth of command-line options](https://docs.docker.com/engine/reference/commandline/docker/) for working with your new containers. Some commonly used commands include:<br>

`docker ps -a` Will list all running containers and their details.<br>
`docker compose start breedbase` Will start both containers (web and db) if they have been stopped.<br>
`docker compose exec breedbase bash` Will open a new bash terminal within the web container.<br>
`docker compose logs breedbase` Will let you access webserver error output from your host.<br>
`docker compose stop breedbase` Will stop both containers (web and db), but will not remove them.<br>
`docker compose down`   Will remove both containers, but only if run within the breedbase_dockerfile directory.<br>

You can find the container id using

``` bash
docker ps
```

then

``` bash
docker exec -it <container_id> bash
```

You can use `lynx localhost:8080` to see if the server is running correctly within the container, and look at the error log using `tail -f /var/log/sgn/error.log` or `less /var/log/sgn/error.log`.

You can of course also find the IP address of the running container either in the container using `ip address` or from the host using `docker inspect <container_id>`.

## Miscellaneous

### Updating the database schema from the docker

Code updates sometimes require the database schema to be updated. This is done using so-called db patches. The db patches are in numbered directories in the the ```db/``` directory of the ```sgn``` repository.

The db patches can be run individually by changing into the specific directory, and then running the script using ```mx-run```, using the parameters as described in the ```perldoc``` for the scripts.

The database can be updated to the current level in one step (recommended method) by running the ```run_all_patches.pl``` script in the ```db/``` directory, which calls all the db patches individually. If you are using the standard docker compose setup, the command line is (options in square brackets are optional):

```bash
perl db/run_all_patches.pl -e admin [-s <startfrom>] [--test]
```

Note that for this to work, the $PERL5LIB environment variable should have the current directory included. If it isn't, run:

```bash
export PERL5LIB=$PERL5LIB:.
```

## Credits

The original [breedbase_dockerfile repository](https://github.com/solgenomics/breedbase_dockerfile) is built by Dr. Lukas Mueller's lab at the [Boyce Thompson Institute](https://btiscience.org/). For a full list of contributors, please  see [this link](https://github.com/solgenomics/breedbase_dockerfile/graphs/contributors).

This fork is maintained by [Katherine Eaton](https://ktmeaton.github.io/) through Dr. Barb Thomas' [Tree Improvement Lab](https://people.ales.ualberta.ca/barbthomas/) at the [University of Alberta](https://www.ualberta.ca/).

## License

Copyright 2026 University of Alberta

Licensed under the MIT License.
