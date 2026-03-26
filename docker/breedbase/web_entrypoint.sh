#!/bin/bash

# A wrapper for perl commands that require a TTY
# (ex. piping db credentials into patching scripts for mx-run)
tty_wrapper() {
    command=$1
    wrapper="script --log-out /tmp/typescript --flush --quiet --return --command \"bash --noprofile --norc -eo pipefail -c '$command'\""
    echo "Running tty_wrapper: $wrapper"
    eval $wrapper
}

# An inelegent way to wait for the docker post_start
# command to finish setting up the container as root user
wait_for_post_start() {

  setup_log="/tmp/web_setup.log"
  first="true"

  while [ ! -f ${setup_log}.finished ]; do

    if [[ $first == "true" && -f $setup_log ]]; then
      cat $setup_log 2>/dev/null | sed -e '$a\' > ${setup_log}.seen
      cat ${setup_log}.seen
      first="false"
    elif [[ -f ${setup_log}.seen ]]; then
      # print unseen lines
      num_lines_seen=$(wc -l ${setup_log}.seen | cut -d ' ' -f 1)
      tail -n+$(expr 1 + $num_lines_seen) $setup_log 2> /dev/null
      # update seen lines
      cat $setup_log 2>/dev/null | sed -e '$a\' > ${setup_log}.seen
    fi

    sleep 1

  done

  # Print any lines left we haven't seen
  num_lines_seen=$(wc -l ${setup_log}.seen | cut -d ' ' -f 1)
  tail -n+$(expr 1 + $num_lines_seen) $setup_log 2> /dev/null
}

start_sgn_server() {

    echo "-------------------------------------------------------------------------"
    echo "Starting sgn server in $MODE mode."
    echo "-------------------------------------------------------------------------"

    # Allow errors now to not stop the script
    set +e

    if [ "$MODE" == "TESTING" ]; then

        # Expand out the args first, otherwise only the first arg is captured
        args="${@}"
        if [[ $args == "--interactive" && -e "/tmp/interactive.t" ]]; then
            echo "No testing arguments were given, setting up interactive mode."
            tty_wrapper "perl t/test_fixture.pl --dumpupdatedfixture /tmp/interactive.t"
            exit_status=$?
        else
            tty_wrapper "perl t/test_fixture.pl --carpalways -v $args"
            exit_status=$?
        fi

        echo "Exiting with status: $exit_status"
        exit $exit_status

    elif [ "$MODE" == "DEVELOPMENT" ]; then
        /home/production/cxgn/sgn/bin/sgn_server.pl --fork -r -p 8080

    elif [ "$MODE" == "PRODUCTION" ]; then

        echo "Updating main_production_site_url"
        cp sgn_local.conf /tmp/sgn_local.conf
        sed -E "s|(main_production_site_url ).*|\1  https://${DOMAIN_NAME}|g" /tmp/sgn_local.conf > sgn_local.conf
        rm -f /tmp/sgn_local.conf
        grep main_production_site_url sgn_local.conf || true

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

    echo "Running the docker post_start command as root"
    wait_for_post_start
    start_sgn_server $@
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
