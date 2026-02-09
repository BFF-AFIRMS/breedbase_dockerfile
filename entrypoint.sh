#!/bin/bash

set -e

# If we are not running as a custom user, run as a new 1000:1000 user
if [[ -z $USER_GROUP_ID ]]; then
    USER_GROUP_ID="1000:1000"
fi

USER_ID=$(echo "$USER_GROUP_ID" | cut -d ":" -f 1)
GROUP_ID=$(echo "$USER_GROUP_ID" | cut -d ":" -f 2)

docker_initialize_user() {

    echo "-------------------------------------------------------------------------"
    echo "Initializing user ( $USER_GROUP_ID $whoami)"
    echo "-------------------------------------------------------------------------"

    # Downstream steps such as javascript will error if the user is unknown to the system
	if ! getent passwd "$USER_ID" &> /dev/null; then
        echo "Adding group $GROUP_ID to system as: sgn"
        addgroup sgn

        echo "Adding user $USER_GROUP_ID to system as: sgn"
        useradd -u $USER_ID -g sgn -m sgn -d /home/sgn
	fi

    echo "System user:" $(getent passwd "$USER_ID")
    echo "System group:" $(getent group "$USER_ID")

}

# used to start system daemons that require root
docker_start_system_services() {
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

    umask 002

}

docker_initialize_db() {

    echo "-------------------------------------------------------------------------"
    echo "Initializing Database"
    echo "-------------------------------------------------------------------------"

    echo "CHECKING IF A DATABASE NEEDS TO BE INSTALLED...";

    if [[ $(psql -lqt -h ${PGHOST} -U ${PGUSER}  | cut -d '|' -f1  | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//;' |  grep -w breedbase || true ) = '' ]]; then
        echo "INSTALLING DATABASE...";
        echo "CREATING web_usr...";
        psql -d postgres -c "CREATE USER web_usr PASSWORD 'postgres';"
        echo "CREATING breedbase DATABASE...";
        
        psql -d postgres -c "CREATE DATABASE breedbase; "
        # work around run_all_patches.pl "what the heck - no TTY??" error
        # https://github.com/solgenomics/sgn/blob/39144f63dfd33a72b7c8f47fc036c3736cc07f07/.github/workflows/test.yml#L57
        # https://github.com/actions/runner/issues/241#issuecomment-842566950
        if [ -e '/db_dumps/empty_breedbase.sql' ]; then
            echo "LOADING empty_breedbase dump...";
            psql -f /db_dumps/empty_breedbase.sql
        else
            echo "LOADING cxgn_fixture.sql dump...";
            psql -f t/data/fixture/cxgn_fixture.sql
        fi  
    fi

    set +e
    if [ -e '/db_dumps/empty_breedbase.sql' ]; then
        echo "PATCHING DATABASE WITH admin...";
        script --log-out /tmp/typescript --flush --quiet --return --command "bash --noprofile --norc -eo pipefail -c 'run_all_patches.pl -e admin -p /home/production/cxgn/sgn/db'"
    else
        echo "PATCHING DATABASE WITH janedoe...";
        # Run with -n to not die on failing patches, because AddCascadeDeletes fails
        script --log-out /tmp/typescript --flush --quiet --return --command "bash --noprofile --norc -eo pipefail -c 'run_all_patches.pl -e janedoe -p /home/production/cxgn/sgn/db -n'"
    fi
    set -e
}

docker_initialize_directories() {

    # Define default permissions for newly created files
    umask 002

    echo "-------------------------------------------------------------------------"
    echo "Initializing Directories"
    echo "-------------------------------------------------------------------------"

    if [[ -e /home/production/volume ]]; then
        for dir_name in archive blast cache cluster logs public public/images tmp ; do
            dir_path=/home/production/volume/${dir_name}
            if [[ ! -e $dir_path ]]; then
                echo "Creating volume: $dir_path"
                mkdir -p $dir_path
            else
                echo "Located volume: $dir_path"
            fi
	        chmod 770 $dir_path
        done
        chown -R $USER_GROUP_ID /home/production/volume
    else
        echo "/home/production/volume does not exist... not creating dirs";
    fi

    # If we are running in production, (not mounting local paths) fix javascript permissions
    if [ "$MODE" == "PRODUCTION" ]; then
        echo "Changing owner of cxgn/sgn/js to: $USER_GROUP_ID"
        chown -R $USER_GROUP_ID /home/production/cxgn/sgn/js

        echo "Changing owner of cxgn/sgn/static to: $USER_GROUP_ID"
        chown -R $USER_GROUP_ID /home/production/cxgn/sgn/static/

        echo "Changing owner of cxgn/local-lib to: $USER_GROUP_ID"
        chown -R $USER_GROUP_ID /home/production/cxgn/local-lib
    fi

    # Create directory for system logs
    mkdir -p /var/log/sgn
    chown -R $USER_GROUP_ID /var/log/sgn


}

docker_npm_build() {

    echo "-------------------------------------------------------------------------"
    echo "NPM Build"
    echo "-------------------------------------------------------------------------"
    
    cd /home/production/cxgn/sgn/js
    HOME=/home/sgn npm run build
    cd -

}

docker_start_server() {
    if [ "${MODE}" == "TESTING" ]; then
        echo "-------------------------------------------------------------------------"
        echo "Starting SGN Tests"
        echo "-------------------------------------------------------------------------"

        exec perl t/test_fixture.pl --carpalways -v "${@}"

    elif [ "$MODE" == "DEVELOPMENT" ]; then
        echo "-------------------------------------------------------------------------"
        echo "Starting SGN Development Server"
        echo "-------------------------------------------------------------------------"

        /home/production/cxgn/sgn/bin/sgn_server.pl --fork -r -p 8080

    else
        echo "-------------------------------------------------------------------------"
        echo "Starting SGN Production Server"
        echo "-------------------------------------------------------------------------"

        /etc/init.d/sgn start
        touch /var/log/sgn/error.log
        chmod 777 /var/log/sgn/error.log
        tail -f /var/log/sgn/error.log

    fi

    # Stream server logs
    touch /var/log/sgn/error.log
    chmod 777 /var/log/sgn/error.log
    tail -f /var/log/sgn/error.log
}

_main() {

    # These setup steps need to be performed as root
    if [ "$(id -u)" = '0' ]; then
        docker_initialize_user
        docker_start_system_services
        docker_initialize_directories
		# restart script as non-root (www-data) user
        # this process is modelled after the postgres docker entrypoint
		exec gosu $USER_GROUP_ID "$BASH_SOURCE" "$@"
	fi

    # These steps should be performed as a non-root user
    docker_initialize_db
    docker_npm_build
    docker_start_server
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