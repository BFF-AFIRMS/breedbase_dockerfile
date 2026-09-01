# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

# Configuration file for JupyterHub
import os
import math
import sys
import docker
from dockerspawner import SystemUserSpawner
from pwd import getpwnam
import socket
import multiprocessing
import json
import textwrap
from tornado import web

c = get_config()  # noqa: F821

domain_name = os.getenv("DOMAIN_NAME")
project_name = os.getenv("DOCKER_NETWORK_NAME")

# Set if jupyterhub is not at the root of the url
c.JupyterHub.base_url = '/jupyter'

# Redirect users to home page rather than server spawner
c.JupyterHub.redirect_to_server = False
c.JupyterHub.default_url = '/jupyter/hub/home'

# Allow users to create a maximum of 3 named servers
c.JupyterHub.allow_named_servers = True
c.JupyterHub.named_server_limit_per_user = 3

# User containers will access hub by container name on the Docker network
c.JupyterHub.hub_ip = socket.gethostname()
c.JupyterHub.hub_port = 8080

# Persist hub data on volume mounted inside container
c.ConfigurableHTTPProxy.pid_file = "/tmp/jupyterhub-proxy.pid"
c.JupyterHub.cookie_secret_file = "/tmp/jupyterhub_cookie_secret"

# -----------------------------------------------------------------------------
# Spawner
# -----------------------------------------------------------------------------

class CustomDockerSpawner(SystemUserSpawner):
    def _options_form_default(self):
        max_cpu_cores = {multiprocessing.cpu_count()}
        max_mem_bytes = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES')
        max_mem_gib = math.floor(max_mem_bytes/(1024.**3))

        select_style="width: 100%; border-radius: 4px; padding: 8px; border-width: 1px"
        label_style="white-space: nowrap"

        with open("/tmp/conda_envs.json") as infile:
            result = json.loads(infile.read())
            rstudio_envs = result["rstudio_envs"] if "rstudio_envs" in result else {}
            rstudio_envs_html = ["<option value='/opt/conda'>Temporary</option>"]

            rstudio_envs_html += [
                f"<option value='{file_path}'>{name} ({file_path})</option>"
                for name,file_path in rstudio_envs.items() if file_path != "/opt/conda"
            ]
            rstudio_envs_html = "\n".join(rstudio_envs_html)

        return f"""
        <div style="min-width: 576px">
            <br/>
            <h3 >Resources</h3>
            <hr/>
            <div class="row">
                <div class="col-4">
                    <label style="{label_style}"><b>CPUs:</b></label>
                    <br>
                    <input type="number" name="cores" placeholder="1" min="1" max="{max_cpu_cores}" style="{select_style}">
                </div>

                <div class="col-4">
                    <label style="{label_style}"><b>Memory (GB):</b></label>
                    <br>
                    <input type="number" name="memory" placeholder="1" min="1" max="{max_mem_gib}" style="{select_style}">
                </div>

                <div class="col-4">
                    <label style="{label_style}"><b>GPUs (Experimental):</b></label>
                    <br>
                    <select name="gpus" style="{select_style}">
                        <option value="none">None</option>
                        <option value="all">All</option>
                    </select>
                </div>

            </div>

            <h3>Environment</h3>
            <hr/>

            <div class="row">
                <div class="col-12">
                    <label style="{label_style}"><b>Operating System:</b></label>
                    <br>
                    <select name="image" style="{select_style}">
                        <option value="bffafirms/jupyter-default:0.2.0">Default (Ubuntu 24.04)</option>
                    </select>
                </div>

                <div class="col-12" style="margin-top: 20px">
                    <label style="{label_style}"><b>RStudio Conda Environment*:</b></label>
                    <br>
                    <select name="rstudio_conda_env" style="{select_style}">
                        {rstudio_envs_html}
                    </select>
                </div>

                <div class="col-12">
                    <p style="font-size: 14px">
                        The "Temporary" environment is for testing, as packages you install in it will
                        not be saved if the server is stopped or restarted. For important analyses, please
                        create your own conda environment first.
                    </p>
                </div>
            </div>
        </div>
        """

    def options_from_form(self, formdata):
        options = {}

        options["image"] = formdata.get('image', ['bffafirms/jupyter-default:0.2.0'])[0]
        options["rstudio_conda_env"] = formdata.get('rstudio_conda_env', ['/opt/conda'])[0]
        options["gpus"] = formdata.get('gpus', ['all'])[0]

        options["cores"] = formdata.get('cores', ['1'])[0]
        try:
            options["cores"] = int(options["cores"])
        except ValueError:
            options["cores"] = 1

        options["memory"] = formdata.get('memory', ['1'])[0]
        try:
            options["memory"] = int(options["memory"])
        except ValueError:
            options["memory"] = 1

        return options


def apply_user_options(spawner, user_options):

    try:
        # -------------------------------------------------------------------------
        # Parse User Options

        if not spawner.extra_host_config:
            spawner.extra_host_config = {}

        if "image" in user_options and isinstance(user_options["image"], str):
            spawner.image = user_options["image"]

        if "memory" in user_options and isinstance(user_options["memory"], int):
            spawner.extra_host_config["mem_limit"] = f"{user_options['memory']}g"

        if "cores" in user_options and isinstance(user_options["cores"], int):
            # Must set cpu_limit and host_config cpu_period to none
            spawner.extra_host_config["nano_cpus"] = user_options["cores"] * 1000000000
            spawner.cpu_limit = None
            spawner.extra_host_config["cpu_period"] = None

        if "gpus" in user_options and user_options["gpus"] == "all":
            spawner.extra_host_config["device_requests"] = [
                docker.types.DeviceRequest(
                    driver="nvidia",
                    count=-1, # Use all
                    capabilities=[["gpu"]],
                ),
            ]

        # -------------------------------------------------------------------------
        # Configure Applications

        username = spawner.user.name
        servername = spawner.name.lower()

        if servername == "" or servername is None:
            servername = "default-server"

        # Configure VSCode Extensions
        spawner.environment['CODE_EXTENSIONSDIR'] = f"/home/{username}/.local/share/jupyter/code-server/extensions"

        # Configure Conda
        with open("/tmp/condarc") as infile:
            contents = infile.read()
            contents = contents.replace("{username}", username)
        condarc_path = f"/data/jupyterhub/users/{username}.{servername}.condarc"
        with open(condarc_path, 'w') as outfile:
            outfile.write(contents + "\n")
        spawner.environment["CONDARC"] = "/tmp/.condarc"

        # Configure R and Rstudio
        if "rstudio_conda_env" in user_options and isinstance(user_options["rstudio_conda_env"], str):
            rstudio_conda_env = user_options["rstudio_conda_env"]
        else:
            rstudio_conda_env = "/opt/conda"

        # Raise error if trying to pick a conda environment in someone else's home directory
        if rstudio_conda_env.startswith("/home"):
            env_split = rstudio_conda_env.split("/")
            if len(env_split) >= 3 and env_split[1] == "home" and env_split[2] != username:
                raise Exception("You do not have permission to use a conda environment in another user's home directory.")

        # If using the temporary environment, it's ok to chown the conda environment
        if rstudio_conda_env == "/opt/conda":
            spawner.environment["CHOWN_EXTRA"] = "/opt/conda/lib/R"
            spawner.environment["CHOWN_EXTRA_OPTS"] = "-R"

        rsession_which_r = os.path.join(rstudio_conda_env, "bin", "R")
        rsession_ld_library_paths = f"{os.path.join(rstudio_conda_env, 'lib')}:{os.path.join(rstudio_conda_env, 'lib', 'R', 'lib')}"
        spawner.environment["R"] = rsession_which_r

        # R profiles
        with open(f"/data/jupyterhub/users/{username}.{servername}.profiles", 'w') as outfile:
            outfile.write(textwrap.dedent(f"""
            [*]
            r-version = {rsession_which_r}
            """))

        # Rserver conf
        with open(f"/data/jupyterhub/users/{username}.{servername}.rserver.conf", 'w') as outfile:
            outfile.write(textwrap.dedent(f"""
            rsession-which-r={rsession_which_r}
            rsession-path=/usr/lib/rstudio-server/bin/rsession.sh
            """))

        # Rprofile site
        rprofile_site_path = f"data/jupyterhub/users/{username}.{servername}.Rprofile.site"
        rprofile_site_local = os.path.join("/", rprofile_site_path)
        with open(rprofile_site_local, 'w') as outfile:
            outfile.write(textwrap.dedent(f"""
            options(download.file.method="curl")
            """))

        # Renviron
        with open(f"/data/jupyterhub/users/{username}.{servername}.Renviron.site", 'w') as outfile:
            outfile.write(textwrap.dedent(f"""
            R_LIBS_USER={os.path.join(rstudio_conda_env, 'lib/R/library')}
            RSTUDIO_WHICH_R={os.path.join(rstudio_conda_env, 'bin/R')}
            """))

        # Rsession
        rsession_file_path = f"/data/jupyterhub/users/{username}.{servername}.rsession.sh"
        with open(rsession_file_path, 'w') as outfile:
            outfile.write(f"#!/bin/bash\n\nconda run -p {rstudio_conda_env} /usr/lib/rstudio-server/bin/rsession\n")
        os.system(f"chmod +x {rsession_file_path}")

        spawner.mounts = [
            {'type': 'bind', 'source': os.path.join(project_path, f"data/jupyterhub/users/{username}.{servername}.condarc"),       'target': "/tmp/.condarc"},
            {'type': 'bind', 'source': os.path.join(project_path, f"data/jupyterhub/users/{username}.{servername}.rserver.conf"),  'target': "/etc/rstudio/rserver.conf"},
            {'type': 'bind', 'source': os.path.join(project_path, f"data/jupyterhub/users/{username}.{servername}.profiles"),      'target': "/etc/rstudio/profiles"},
            {'type': 'bind', 'source': os.path.join(project_path, f"data/jupyterhub/users/{username}.{servername}.rsession.sh"),   'target': "/usr/lib/rstudio-server/bin/rsession.sh"},
            {'type': 'bind', 'source': os.path.join(project_path, f"data/jupyterhub/users/{username}.{servername}.Renviron.site"), 'target': os.path.join(rstudio_conda_env, "lib/R/etc/Renviron.site")},
            {'type': 'bind', 'source': os.path.join(project_path, f"data/jupyterhub/users/{username}.{servername}.Rprofile.site"), 'target': os.path.join(rstudio_conda_env, "lib/R/etc/Rprofile.site")},
            # {'type': 'bind', 'source': '/path/on/host', 'target': '/path/on/container'},
        ]

        uid = getpwnam(username).pw_uid
        gid = getpwnam(username).pw_gid
        spawner.environment['NB_UID'] = uid
        spawner.environment['NB_GID'] = gid

        spawner.extra_host_config["cap_drop"] = ["ALL"]
        spawner.extra_host_config["cap_add"] = ["CAP_CHOWN", "CAP_SETGID", "CAP_SETUID"]
        spawner.extra_host_config["security_opt"] = ["no-new-privileges=true"]

        # Ownership permissions
        spawner.environment["CHOWN_HOME"] = "no"

    except Exception as e:
        error = web.HTTPError(403)
        error.jupyterhub_message = f"{repr(e)}"
        raise error

c.JupyterHub.spawner_class      = CustomDockerSpawner
c.SystemUserSpawner.run_as_root = True
c.Spawner.apply_user_options    = apply_user_options
c.DockerSpawner.allowed_images  = [
    "bffafirms/jupyter-default:0.2.0",
    "bffafirms/jupyter-default:0.1.0",
]


def post_stop_hook(spawner):
    username = spawner.user.name
    servername = spawner.name.lower()

    file_prefix = f"/data/jupyterhub/users/{username}.{servername}"
    files_to_cleanup = [
        f"{file_prefix}{file_suffix}"
        for file_suffix in [".Renviron.site", ".Rprofile.site", ".condarc", ".profiles", ".rserver.conf", ".rsession.sh"]
    ]
    for file_path in files_to_cleanup:
        if os.path.exists(file_path):
            os.remove(file_path)

c.DockerSpawner.post_stop_hook = post_stop_hook

# Connect containers to this Docker network
network_name = os.environ["DOCKER_NETWORK_NAME"]
c.DockerSpawner.use_internal_ip = True
c.DockerSpawner.network_name = network_name

# Explicitly set notebook directory because we'll be mounting a volume to it.
# as the authenticated user's home directory.
c.DockerSpawner.notebook_dir = os.path.join("/home", "{username}")

# Remove containers once they are stopped
c.DockerSpawner.remove = True

# For debugging arguments passed to spawned containers
c.DockerSpawner.debug = True

# Mount any additional host directories as desired
project_path = os.environ["PROJECT_PATH"]

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

db_user =  os.environ["DB_USER"]
db_password = os.environ["DB_PASSWORD"]
db_name = os.environ["DB_NAME"]
db_host = os.environ["DB_HOST"]
c.JupyterHub.db_url = f"postgresql://{db_user}:{db_password}@{db_host}/{db_name}"

# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------

# Disallow admin users by default
c.Authenticator.admin_users = []

c.JupyterHub.authenticator_class = "generic-oauth"

# OAuth2 application info
# -----------------------
c.GenericOAuthenticator.client_id = "jupyterhub"
c.GenericOAuthenticator.client_secret = os.getenv("JUPYTERHUB_CLIENT_SECRET")

# Identity provider info
# ----------------------
c.GenericOAuthenticator.authorize_url = f"https://{domain_name}/auth/realms/{project_name}/protocol/openid-connect/auth"
c.GenericOAuthenticator.oauth_callback_url = f"https://{domain_name}/jupyter/hub/oauth_callback"
c.GenericOAuthenticator.token_url = f"http://keycloak:9080/auth/realms/{project_name}/protocol/openid-connect/token"
c.GenericOAuthenticator.userdata_url = f"http://keycloak:9080/auth/realms/{project_name}/protocol/openid-connect/userinfo"
c.GenericOAuthenticator.scope = ["openid", "email", "groups"]
c.GenericOAuthenticator.username_claim = "preferred_username"
c.GenericOAuthenticator.auth_state_groups_key = "oauth_user.groups"
c.GenericOAuthenticator.enable_pkce = True
c.GenericOAuthenticator.auto_login = True
c.GenericOAuthenticator.logout_redirect_url = f"https://{domain_name}/logout/jupyter"

# Authorization
# -------------
c.GenericOAuthenticator.manage_groups = True
c.GenericOAuthenticator.allowed_groups = {"server_user", "admin"}
c.GenericOAuthenticator.admin_groups = {"admin"}

# -----------------------------------------------------------------------------
# Services

c.JupyterHub.services = [
    {
        'name': 'idle-culler',
        'command': [sys.executable, '-m', 'jupyterhub_idle_culler',
            '--cull-every=60',
            '--timeout=3600',
            '--max-age=604800',
        ],
    }
]

c.JupyterHub.load_roles = [
    {
        "name": "jupyterhub-idle-culler-role",
        "scopes": [
            "list:users",
            "read:users:activity",
            "read:servers",
            "delete:servers",
        ],
        # assignment of role's permissions to:
        "services": ["idle-culler"],
    }
]
