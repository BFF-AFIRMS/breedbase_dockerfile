#!/bin/bash
sed -i s/localhost/$HOSTNAME/g /etc/slurm/slurm.conf
/etc/init.d/postfix start
/etc/init.d/cron start
chown 106 /etc/munge/munge.key
/etc/init.d/munge start
/etc/init.d/slurmctld start
/etc/init.d/slurmd start
#/etc/init.d/postgres start

chown root /etc/crontab # in case it was mounted from local dir

# A wrapper for perl commands that require a TTY
# (ex. piping db credentials into patching scripts for mx-run)
tty_wrapper() {
    command=$1
    wrapper="script --log-out /tmp/typescript --flush --quiet --return --command \"bash --noprofile --norc -eo pipefail -c '$command'\""
    echo "Running tty_wrapper: $wrapper"
    eval $wrapper
}

# Make sure the owner of the sgn_local.conf file exists on the system
conf_user=$(ls -l sgn_local.conf | sed -E 's/\s+/ /g' | cut -d ' ' -f 3)
conf_group=$(ls -l sgn_local.conf | sed -E 's/\s+/ /g' | cut -d ' ' -f 4)
conf_username=$conf_user

if ! getent passwd "$conf_user" &> /dev/null; then

    conf_username=devel

    echo "-------------------------------------------------------------------------"
    echo "Initializing user ( $conf_user:$conf_group ) as $conf_username"
    echo "-------------------------------------------------------------------------"

    echo "$conf_username:x:$conf_user:$conf_group:,,,:/home/devel:/usr/sbin/nologin" >> /etc/passwd
    echo "$conf_username:x:$conf_group:" >> /etc/group
    mkdir -p /home/devel
    chown -R $conf_user:$conf_group /home/devel

    echo "System user:" $(getent passwd "$conf_user")
    echo "System group:" $(getent group "$conf_group")
fi


if [[ ! -z $SITE_OVERLAY && $SITE_OVERLAY != "" && -e /home/production/cxgn/$SITE_OVERLAY ]]; then
    echo "-------------------------------------------------------------------------"
    echo "Applying Site Overlay: $SITE_OVERLAY"
    echo "-------------------------------------------------------------------------"
    sudo -u $conf_username cp --force --archive --recursive --symbolic-link /home/production/cxgn/$SITE_OVERLAY/* /home/production/cxgn/sgn

    # Javascript cannot be symlinked, but be fully copied
    if [[ -d /home/production/cxgn/$SITE_OVERLAY/js/ ]]; then
        rsync -av /home/production/cxgn/$SITE_OVERLAY/js/* .
    fi
fi


if [ "${MODE}" = 'TESTING' ]; then

    echo "-------------------------------------------------------------------------"
    echo "Running in TESTING Mode"
    echo "-------------------------------------------------------------------------"

    # Expand out the args first, otherwise only the first arg is captured
    args="${@}"
    if [[ $args == "--interactive" && -e "/tmp/interactive.t" ]]; then
        echo "No testing arguments were given, setting up interactive mode."
        tty_wrapper "perl t/test_fixture.pl --dumpupdatedfixture /tmp/interactive.t"
    else
        tty_wrapper "perl t/test_fixture.pl --carpalways -v $args"
    fi
    exit $?
fi

umask 002

# load empty fixture and run any missing patches

echo "CHECKING IF A DATABASE NEEDS TO BE INSTALLED...";

if [[ $(psql -lqt -h ${PGHOST} -U ${PGUSER} ${PGDATABASE} | cut -d '|' -f1  | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//;' |  grep -w breedbase ) = '' ]]; then

    echo "-------------------------------------------------------------------------"
    echo "INSTALLING DATABASE"
    echo "-------------------------------------------------------------------------"
    
    echo "CREATING web_usr...";
    if [[ -z $WEB_USR_PASSWORD ]]; then
        WEB_USR_PASSWORD="postgres"
    fi
    psql -d postgres -c "CREATE USER web_usr PASSWORD '$WEB_USR_PASSWORD';"

    echo "CREATING breedbase DATABASE...";
    psql -d postgres -c "CREATE DATABASE breedbase; "

    if [ -e '/db_dumps/empty_breedbase.sql' ]
    then
        echo "LOADING empty_breedbase dump...";
        psql -f /db_dumps/empty_breedbase.sql

        if [[ ! -z $ADMIN_PASSWORD ]]; then
            echo "CREATING secure admin password";
            psql -c "update sgn_people.sp_person set password=sgn.crypt('$ADMIN_PASSWORD', sgn.gen_salt('bf', 6)) where first_name = 'admin'"
        fi
        echo "RUNNING patches...";
        tty_wrapper "db/run_all_patches.pl -e admin -p db"

        if [[ $SITE_OVERLAY != "" && -e db/$SITE_OVERLAY ]]; then
            echo "-------------------------------------------------------------------------"
            echo "RUNNING $SITE_OVERLAY patches"
            echo "-------------------------------------------------------------------------"
            tty_wrapper "db/run_all_patches.pl -e admin -p db/$SITE_OVERLAY"
        fi

    else
        echo "LOADING cxgn_fixture.sql dump...";
        psql -f t/data/fixture/cxgn_fixture.sql
        # The first patch the cxgn_fixture needs is 158 (AddCascadeDeletes. But that patch
        # fails for the test fixture (currently). Since the run_all_patches.pl script will
        # die immediately after a patch fails. Starting on patch 159 ensures it works.
        echo "RUNNING patches...";
        tty_wrapper "db/run_all_patches.pl -e janedoe -s 159 -p db"

        if [[ $SITE_OVERLAY != "" && -e db/$SITE_OVERLAY ]]; then
            echo "-------------------------------------------------------------------------"
            echo "RUNNING $SITE_OVERLAY patches"
            echo "-------------------------------------------------------------------------"
            tty_wrapper "db/run_all_patches.pl -e janedoe -p db/$SITE_OVERLAY"
        fi
    fi
   
fi

# create necessary dirs/permissions if we have a docker volume dir
# at /home/production/volume
if [[ -e /home/production/volume ]]; then
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

        if [[ ! -z $USER_GROUP_ID ]]; then
            chown -R $USER_GROUP_ID $dir_path
        fi
    done

    # Required otherwise the cache directory for solgs with have permissions errors
    # chmod -R +r /data/breedbase/public/tmp
else
    echo "/home/production/volume does not exist... not creating dirs";
fi

if [ "$MODE" == "DEVELOPMENT" ]; then
        /home/production/cxgn/sgn/bin/sgn_server.pl --fork -r -p 8080
else
    /etc/init.d/sgn start
    touch /var/log/sgn/error.log
    chmod 777 /var/log/sgn/error.log
    tail -f /var/log/sgn/error.log
fi

# for unigene page, compile drawcontig align program
#cd /home/production/cxgn/sgn/programs
#make
#cd /home/production/cxgn/sgn
