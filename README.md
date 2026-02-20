<p align="center">
  <img src="Breedbase.png">
</p>

This repo contains the Dockerfile for the breeDBase webserver, and the docker compose files for joint deployment of the breeDBase webserver and postgres database.

To learn more about breeDBase:

Access the [SGN repository](https://github.com/solgenomics/sgn) to contribute to the underlying codebase or submit new issues.    
Access the [manual](https://solgenomics.github.io/sgn/) to learn how to use breeDBase's many features.    
Access [breedbase.org](https://breedbase.org/) to explore a default instance of breeDBase.

## Table of Contents

1. [Install](#install)
    - [Clone Repository](#clone-repository)
    - [Install docker](#install-docker)
    - [Install docker compose](#install-docker-compose)
2. [Deploy](#deploy)
    - [Deploy for Production](#deploy-for-production-with-docker-compose)   
    - [Deploy for Development](#deploy-for-development)
    - [Deploy for Testing](#deploy-for-testing)
3. [Access and Configure](#access-and-configure)
4. [Updating](#updating)
4. [Debugging](#debugging)
5. [Miscellaneous](#miscellaneous)

## Install

1. **Install `docker`**

    Please follow the instructions at https://docs.docker.com/engine/install.

1. **Install `docker compose`**

    - Debian/Ubuntu: `apt install docker-compose`
    - Windows: It can be installed with [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install).
    -  Please noe that [Docker Desktop](https://www.docker.com/products/docker-desktop) requires a paid license for research and commercial use.
    - Installing docker natively in Windows will conflict with VMWare and Virtualbox virtualization settings.

1. **Clone repository**

    ```bash
    git clone https://github.com/solgenomics/breedbase_dockerfile
    cd breedbase_dockerfile
    ```

## Deploy

For all deployment methods, first create a `.env` file with:

### Deploy for Production

1. **Run setup**

    > This will create data directories under `data/` and secure credentials in `.env`.
    ```bash
    ./setup
    ```

1. **Deploy with docker compose**

    ```
    docker compose -f docker-compose.production.yml up -d
    ```

    Follow [the instructions below](#access-and-configure) to access and configure your new breedbase deployment.

    > These settings include setting the env MODE to PRODUCTION and mounting fewer volumes from the host (won't use host `./cxgn` dir to overwrite `/home/production/cxgn` in the container).

### Deploy for Development

1. **Clone the submodules**

    ```bash
    git submodule update --init --recursive --progress
    ```
   
   > This will clone all the git repos that are needed for breedbase into a subdirectory called `cxgn/`. This directory will be mounted onto the devel container during the compose step, but will still be accessible from the host for development work.

2. **Create a `.env` file with dev credentials**

    ```bash
    echo "
    PGDATABASE=breedbase
    PGHOST=breedbase_db
    PGPASSWORD=postgres
    PGUSER=postgres" > .env
    ```


2. **Deploy with docker compose**

    ```
    docker compose up -d
    ```

    > This will deploy 2 containers, `breedbase_web` and `breedbase_db`, combined in a single service named `breedbase`. The deployment will set the container environment MODE to DEVELOPMENT, which will run the web server using Catalyst instead of Starman. In this configuration, the server will restart when any changes are detected in the config file or sgn perl libraries.

    Then follow [the instructions below](#access-and-configure) to access and configure your new breedbase deployment!

### Deploy for Testing

1. **Clone the submodules**

    ```bash
    git submodule update --init --recursive --progress
    ```

Then choose either [Standalone](#standalone) or [Interactive](#interactive) mode.

#### Standalone

Tests can be run in `standalone` mode. For each test, a new database and web server will be created, ensuring reproducibility and isolation between tests.

> Note: This mode can be very slow to start up and run.

```bash
docker compose -f docker-compose.test.yml run --use-aliases test_breedbase -c --nopatch --noserver t/unit
docker compose -f docker-compose.test.yml run --use-aliases test_breedbase -c t/unit_fixture
docker compose -f docker-compose.test.yml run --use-aliases test_breedbase -c t/unit_mech
docker compose -f docker-compose.test.yml run --use-aliases test_breedbase -c t/selenium2/search
```

> For selenium (browser) tests, open the visualizer at: <http://localhost:8081/vnc.html>

For less noisy output, cleanup `stderr` with:

```bash
docker compose -f docker-compose.test.yml run --use-aliases test_breedbase -c "--nopatch --noserver t/unit 2>/dev/null"
```

#### Interactive

Tests can be run in `interactive` mode, where the same database and web server are re-used between tests for quick iteration. This is particulary useful when writing and troubleshooting new tests.

1. **Start up all containers with docker compose**

    ```bash
    docker compose -f docker-compose.test.yml up -d
    ```

2. **Wait for the web server container to be healthy**

    ```bash
    docker compose -f docker-compose.test.yml ps test_breedbase

    NAME                                    IMAGE                        COMMAND                  SERVICE          CREATED              STATUS                        PORTS
    breedbase_dockerfile-test_breedbase-1   breedbase/breedbase:latest   "/entrypoint.sh --in…"   test_breedbase   About a minute ago   Up About a minute (healthy)   0.0.0.0:3010->3010/tcp, [::]:3010->3010/tcp, 8080/tcp
    ```

3. **Connect to the test container**

    ```bash
    docker compose -f docker-compose.test.yml exec test_breedbase bash
    ```

4. **Run unit tests interactively**

    ```bash
    # Single
    prove t/unit/CXGN/String

    # Group
    prove --recurse t/unit/CXGN 2>/dev/null

    # All
    prove --recurse t/unit/ prove --recurse t/unit/CXGN 2>/dev/null
    ```

5. **Run server and database tests**

    ```bash
    perl t/test_fixture.pl --nopatch --noserver t/unit_fixture 2>/dev/null
    perl t/test_fixture.pl --nopatch --noserver t/unit_mech 2>/dev/null
    ```

6. **Run browser tests**

    > For selenium (browser) tests, open the visualizer at: <http://localhost:8081/vnc.html>

    ```bash
    # Single
    perl t/test_fixture --nopatch --noserver t/selenium2/search/stock.t

    # Group
    perl t/test_fixture.pl --nopatch --noserver t/selenium2/01_list 2>/dev/null
    perl t/test_fixture.pl --nopatch --noserver t/selenium2/02_trial 2>/dev/null
    perl t/test_fixture.pl --nopatch --noserver t/selenium2/03_dataset 2>/dev/null
    perl t/test_fixture.pl --nopatch --noserver t/selenium2/breeders 2>/dev/null
    perl t/test_fixture.pl --nopatch --noserver t/selenium2/onto 2>/dev/null
    perl t/test_fixture.pl --nopatch --noserver t/selenium2/search 2>/dev/null
    perl t/test_fixture.pl --nopatch --noserver t/selenium2/stock 2>/dev/null
    perl t/test_fixture.pl --nopatch --noserver t/selenium2/tools 2>/dev/null
    ```

## Access and Configure

Once the breedbase service has started, it must be in a healthy state before it can be accessed. This can take several minutes on first startup.

```bash
docker compose ps breedbase
```

```text
NAME            IMAGE                        COMMAND            SERVICE     CREATED         STATUS                   PORTS
breedbase_web   breedbase/breedbase:latest   "/entrypoint.sh"   breedbase   2 minutes ago   Up 2 minutes (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
```

Once your breedbase service is healthy, you can access the application at http://localhost:8080.

### Production

When running in `PRODUCTION` mode, one account is available at startup:

| role      | username | password |
| --------- | -------- | -------- |
| curator   | admin    | password |

Please login and change the password of the admin user.

Most configuration is handled in the `sgn_local.conf` file. Just edit the corresponding configuration line in the file to change your database name, species, ontology, mason skin, etc.

### Development

When running in `DEVELOPMENT` mode, several accounts are available at startup:

| role      | username | password |
| --------- | -------- | -------- |
| curator   | janedoe  | secretpw |
| submitter | johndoe  | secretpw |
| user      | freddy   | atgc     |

The admin user `janedoe` can be used for creating new user accounts.

## Updating

To update with the latest changes from the [upstream repo](https://github.com/solgenomics/breedbase_dockerfile).

## Debugging

Docker has a [wealth of command-line options](https://docs.docker.com/engine/reference/commandline/docker/) for working with your new containers. Some commonly used commands include:<br>

`docker ps -a` Will list all running containers and their details.<br>
`docker compose start breedbase` Will start both containers (web and db) if they have been stopped.<br>
`docker compose exec breedbase bash` Will open a new bash terminal within the web container.<br>
`docker compose logs breedbase` Will let you access webserver error output from your host.<br>
`docker compose stop breedbase` Will stop both containers (web and db), but will not remove them.<br>
`docker compose down`   Will remove both containers, but only if run within the breedbase_dockerfile directory.<br>

You can find the container id using
```
docker ps
```
then
```
docker exec -it <container_id> bash
```

You can use `lynx localhost:8080` to see if the server is running correctly within the container, and look at the error log using `tail -f /var/log/sgn/error.log` or `less /var/log/sgn/error.log`.

You can of course also find the IP address of the running container either in the container using `ip address` or from the host using `docker inspect <container_id>`.


## Miscellaneous

### Running Breedbase behind a proxy server

In many situations, the Breedbase server will be installed behind a proxy server. While everything should run normally, there is an issue with ```npm```, and it needs to be specially configured. Create a file on the host server, let's say, ```npm_config.txt```, with the following lines in it:

```
strict-ssl=false
registry=http://registry.npmjs.org/
proxy=http://yourproxy.server.org:3128
https-proxy=http://yourproxy.server.org:3128
maxsockets=1
```
Of course, replace ```yourproxy.server.org:3128``` with your correct proxy server hostname and port.

When running the docker, mount this file (using the ```volumes``` option in ```docker compose``` or ```-v``` with ```docker run``` etc.) at the location ```/home/production/.npmrc``` in the docker. Then start your docker and now npm should be able to fetch dependencies from the registry.

### Updating the database schema from the docker

Code updates sometimes require the database schema to be updated. This is done using so-called db patches. The db patches are in numbered directories in the the ```db/``` directory of the ```sgn``` repository.

The db patches can be run individually by changing into the specific directory, and then running the script using ```mx-run```, using the parameters as described in the ```perldoc``` for the scripts.

The database can be updated to the current level in one step (recommended method) by running the ```run_all_patches.pl``` script in the ```db/``` directory, which calls all the db patches individually. If you are using the standard docker compose setup, the command line is (options in square brackets are optional):
```
    cd db;
    perl run_all_patches.pl -u postgres -p postgres -h breedbase_db -d
    breedbase -e admin [-s <startfrom>] [--test]
```

Note that for this to work, the $PERL5LIB environment variable should have the current directory included. If it isn't, run:
```
    export PERL5LIB=$PERL5LIB:.
```

### Deploying Services Individually

 * Individual deployment is generally not necessary or recommended. When possible deploy jointly with docker compose *

1. Install docker

  Debian/Ubuntu: `sudo apt install docker.io`

  For Mac/Windows: [Docker Desktop](https://www.docker.com/products/docker-desktop)

2. Deploy a Web Server

  This will create a Breedbase web server container. The -v flag is used to mount a local conf file and a couple of dirs from the host. Create the file and ris on your host if they don't exist and update the paths before running the command.

  ```
  docker run -d --name breedbase_web -p 8080:8080 -v /host/path/to/sgn_local.conf:/home/production/cxgn/sgn/sgn_local.conf -v /host/path/to/archive:/home/production/archive -v /host/path/to/public_breedbase:/home/production/public breedbase/breedbase:latest
  ```

3. Deploy a Postgres Database

  This will create an empty Breedbase postgres database container.

  ```
  docker run -d --name breedbase_db -p 5432:5432 breedbase/pg:latest
  ```

  For more information, visit: https://github.com/solgenomics/postgres_dockerfile

4. Connect containers via Docker Network

  Assuming you've named the Breedbase database container `breedbase_db`, in your `sgn_local.conf`, set the following:

  ```
  dbhost breedbase_db
  dbport 5432
  ```

  Create a network and add your containers

  ```
  docker network create -d bridge bb_bridge_network
  docker network connect bb_bridge_network breedbase_db
  docker network connect bb_bridge_network breedbase_web
  ```

  Finally access the application at http://localhost:8080