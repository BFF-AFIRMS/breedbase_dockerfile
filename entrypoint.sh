#!/bin/bash

umask 002

# Check who is the owner of the local conf file
conf_user=$(ls -l sgn_local.conf | sed -E 's/\s+/ /g' | cut -d ' ' -f 3)
conf_group=$(ls -l sgn_local.conf | sed -E 's/\s+/ /g' | cut -d ' ' -f 4)
conf_username=$conf_user

# A wrapper for perl commands that require a TTY
# (ex. piping db credentials into patching scripts for mx-run)
tty_wrapper() {
    command=$1
    wrapper="script --log-out /tmp/typescript --flush --quiet --return --command \"bash --noprofile --norc -eo pipefail -c '$command'\""
    echo "Running tty_wrapper: $wrapper"
    eval $wrapper
}

# start system daemons that require root
start_system_services() {
    echo "-------------------------------------------------------------------------"
    echo "Starting system services"
    echo "-------------------------------------------------------------------------"

    sed -i s/localhost/$HOSTNAME/g /etc/slurm/slurm.conf
    /etc/init.d/postfix start
    /etc/init.d/cron start
    chown 106 /etc/munge/munge.key
    /etc/init.d/munge start
    /etc/init.d/slurmctld start
    /etc/init.d/slurmd start

    chown root /etc/crontab # in case it was mounted from local dir
}

# Make sure the owner of the  conf file exists on the system
initialize_user() {
    file_path=$1
    user_name=$2

    echo "-------------------------------------------------------------------------"
    echo "Initializing user: $file_path"
    echo "-------------------------------------------------------------------------"

    # make sure the file owner exists on the system
    file_user=$(ls -l $file_path | sed -E 's/\s+/ /g' | cut -d ' ' -f 3)
    file_group=$(ls -l $file_path | sed -E 's/\s+/ /g' | cut -d ' ' -f 4)

    # Create group
    if [[ ! $(getent group "$file_group") ]]; then
        echo "Creating group: $file_group:$user_name"
        groupadd -g $file_group $user_name
    else
        echo "Group $file_group already exists"
    fi

    if [[ ! $(getent passwd "$file_user") ]]; then
        echo "Creating user: $file_group:$user_name"
        useradd $user_name -u $file_user -g $file_group -m -s /bin/bash
    else
        echo "User $file_user already exists"
    fi

    echo "System user:" $(getent passwd "$file_user")
    echo "System group:" $(getent group "$file_group")

}

apply_site_overlay() {

    if [[ ! -z $SITE_OVERLAY && $SITE_OVERLAY != "" && -e /home/production/cxgn/$SITE_OVERLAY ]]; then

        echo "-------------------------------------------------------------------------"
        echo "Applying Site Overlay: $SITE_OVERLAY"
        echo "-------------------------------------------------------------------------"

        # Match the conf user
        conf_user=$(ls -l sgn_local.conf | sed -E 's/\s+/ /g' | cut -d ' ' -f 3)
        echo "Symlinking files as $conf_user"
        sudo -u $conf_user cp --force --archive --recursive --symbolic-link /home/production/cxgn/$SITE_OVERLAY/* /home/production/cxgn/sgn

        # Javascript cannot be symlinked, must be fully copied
        # match js user
        if [[ -d /home/production/cxgn/$SITE_OVERLAY/js/ ]]; then
            js_user=$(ls -l js/package.json | sed -E 's/\s+/ /g' | cut -d ' ' -f 3)
            echo "Overwriting js files as $js_user"
            sudo -u $js_user rsync -avI /home/production/cxgn/$SITE_OVERLAY/js/* js/
        fi
    fi
}

initialize_database() {

    echo "-------------------------------------------------------------------------"
    echo "Initializing Database"
    echo "-------------------------------------------------------------------------"

    # load empty fixture and run any missing patches
    if [[ $(psql -lqt -h ${PGHOST} -U ${PGUSER} ${PGDATABASE} | cut -d '|' -f1  | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//;' |  grep -w breedbase ) = '' ]]; then

        # Create user
        echo "Creating database user: web_usr";
        if [[ -z $WEB_USR_PASSWORD || $WEB_USR_PASSWORD == "" ]]; then
            WEB_USR_PASSWORD="postgres"
        fi
        psql -d postgres -c "CREATE USER web_usr PASSWORD '$WEB_USR_PASSWORD';"

        # Create database
        echo "Creating database: $PGDATABASE";
        psql -d postgres -c "CREATE DATABASE $PGDATABASE;"

        # Load starting db
        patch_user=""
        patch_start=""
        if [ -e '/db_dumps/empty_breedbase.sql' ]
        then
            echo "Loading empty_breedbase dump";
            psql -f /db_dumps/empty_breedbase.sql

            if [[ ! -z $ADMIN_PASSWORD && $ADMIN_PASSWORD != "" ]]; then
                echo "Creating secure admin password";
                psql -c "update sgn_people.sp_person set password=sgn.crypt('$ADMIN_PASSWORD', sgn.gen_salt('bf', 6)) where first_name = 'admin'"
            fi
            patch_user="admin"
            patch_start="1"
        else
            echo "Loading cxgn_fixture dump";
            psql -f t/data/fixture/cxgn_fixture.sql
            # The first patch the cxgn_fixture needs is 158 (AddCascadeDeletes. But that patch
            # fails for the test fixture (currently). Since the run_all_patches.pl script will
            # die immediately after a patch fails. Starting on patch 159 ensures it works.
            patch_user="janedoe"
            patch_start="159"
        fi

        # Run default patches
        echo "Running default patches.";     
        tty_wrapper "db/run_all_patches.pl -e $patch_user -s $patch_start -p /home/production/cxgn/sgn/db/"

        # Run site overlay patches
        if [[ $SITE_OVERLAY != "" && -e /home/production/cxgn/$SITE_OVERLAY/patches ]]; then
            echo "Running $SITE_OVERLAY patches"
            tty_wrapper "db/run_all_patches.pl -e $patch_user -p /home/production/cxgn/$SITE_OVERLAY/patches"
        fi
    else
        echo "Database $PGDATABASE already exists.";
    fi
}

initialize_javascript() {

    echo "-------------------------------------------------------------------------"
    echo "Initializing javascript"
    echo "-------------------------------------------------------------------------"

    cd js
    js_user=$(ls -l package.json | sed -E 's/\s+/ /g' | cut -d ' ' -f 3)
    sudo -u $js_user HOME=/tmp npm run build
    cd -
}

initialize_volumes() {
    # create necessary dirs/permissions if we have a docker volume dir
    # at /home/production/volume
    echo "-------------------------------------------------------------------------"
    echo "Initializing Volumes"
    echo "-------------------------------------------------------------------------"

    for dir_name in archive blast cache cluster logs pgdata public public/images tmp; do
        dir_path=/home/production/volume/${dir_name}
        if [[ ! -e $dir_path ]]; then
            echo "Creating volume: $dir_path"
            mkdir -p $dir_path
        else
            echo "Located volume: $dir_path"
        fi
        chmod 770 $dir_path

        # Who should be owner? Whoever is runing the server?
        #if [[ ! -z $USER_GROUP_ID ]]; then
        #    chown -R $USER_GROUP_ID $dir_path
        #fi
    done

    # Required otherwise the cache directory for solgs with have permissions errors
    # chmod -R +r /data/breedbase/public/tmp
}

start_sgn_server() {

    echo "-------------------------------------------------------------------------"
    echo "Starting sgn server in $MODE mode."
    echo "-------------------------------------------------------------------------"
    
    if [ "$MODE" == "TESTING" ]; then
        # Expand out the args first, otherwise only the first arg is captured
        args="${@}"
        if [[ $args == "--interactive" && -e "/tmp/interactive.t" ]]; then
            echo "No testing arguments were given, setting up interactive mode."
            tty_wrapper "perl t/test_fixture.pl --dumpupdatedfixture /tmp/interactive.t"
        else
            tty_wrapper "perl t/test_fixture.pl --carpalways -v $args"
        fi
        exit $?

    elif [ "$MODE" == "DEVELOPMENT" ]; then
        /home/production/cxgn/sgn/bin/sgn_server.pl --fork -r -p 8080

    elif [ "$MODE" == "PRODUCTION" ]; then
        /etc/init.d/sgn start
        touch /var/log/sgn/error.log
        chmod 777 /var/log/sgn/error.log
        tail -f /var/log/sgn/error.log
    else
        echo "Unknown server mode, exiting".
        exit 1
    fi
}

_main() {

    start_system_services
    initialize_user sgn_local.conf sgn
    apply_site_overlay
    initialize_database
    initialize_javascript
    initialize_volumes
    start_sgn_server
}

# check to see if this file is being run or sourced from another script
_is_sourced() {
	# https://unix.stackexchange.com/a/215279
	[ "${#FUNCNAME[@]}" -ge 2 ] \
		&& [ "${FUNCNAME[0]}" = '_is_sourced' ] \
		&& [ "${FUNCNAME[1]}" = 'source' ]
}

if ! _is_sourced; then
	_main "$@"
fi