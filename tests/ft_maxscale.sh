#! /bin/bash
MYNAME=$(basename $0)
MYBASENAME=$(basename $0 .sh)
MYDIR=$(dirname $0)
VERBOSE=""
VERSION="0.0.1"
LOG_OPTION="--wait"

CONTAINER_SERVER=""
CONTAINER_IP=""
CMON_CLOUD_CONTAINER_SERVER=""
CLUSTER_NAME="${MYBASENAME}_$$"
MAXSCALE_IP=""

CONTAINER_NAME1="${MYBASENAME}_11_$$"
CONTAINER_NAME2="${MYBASENAME}_12_$$"
CONTAINER_NAME9="${MYBASENAME}_19_$$"


cd $MYDIR
source include.sh

#
# Prints usage information and exits.
#
function printHelpAndExit()
{
cat << EOF
Usage: $MYNAME [OPTION]... [TESTNAME]
 Test script for s9s to check various error conditions.

 -h, --help       Print this help and exit.
 --verbose        Print more messages.
 --print-json     Print the JSON messages sent and received.
 --log            Print the logs while waiting for the job to be ended.
 --print-commands Do not print unit test info, print the executed commands.
 --reset-config   Remove and re-generate the ~/.s9s directory.
 --server=SERVER  Use the given server to create containers.

EOF
    exit 1
}

ARGS=$(\
    getopt -o h \
        -l "help,verbose,print-json,log,print-commands,reset-config,server:" \
        -- "$@")

if [ $? -ne 0 ]; then
    exit 6
fi

eval set -- "$ARGS"
while true; do
    case "$1" in
        -h|--help)
            shift
            printHelpAndExit
            ;;

        --verbose)
            shift
            VERBOSE="true"
            OPTION_VERBOSE="--verbose"
            ;;

        --log)
            shift
            LOG_OPTION="--log"
            ;;

        --print-json)
            shift
            OPTION_PRINT_JSON="--print-json"
            ;;

        --print-commands)
            shift
            DONT_PRINT_TEST_MESSAGES="true"
            PRINT_COMMANDS="true"
            ;;

        --reset-config)
            shift
            OPTION_RESET_CONFIG="true"
            ;;

        --server)
            shift
            CONTAINER_SERVER="$1"
            shift
            ;;

        --)
            shift
            break
            ;;
    esac
done

if [ -z "$OPTION_RESET_CONFIG" ]; then
    printError "This script must remove the s9s config files."
    printError "Make a copy of ~/.s9s and pass the --reset-config option."
    exit 6
fi

if [ -z "$CONTAINER_SERVER" ]; then
    printError "No container server specified."
    printError "Use the --server command line option to set the server."
    exit 6
fi

#
# This will register the container server. 
#
function registerServer()
{
    local class

    print_title "Registering Container Server"

    #
    # Creating a container.
    #
    mys9s server \
        --register \
        --servers="lxc://$CONTAINER_SERVER" 

    check_exit_code_no_job $?

    mys9s server --list --long
    check_exit_code_no_job $?

    #
    # Checking the class is very important.
    #
    class=$(\
        s9s server --stat "$CONTAINER_SERVER" \
        | grep "Class:" | awk '{print $2}')

    if [ "$class" != "CmonLxcServer" ]; then
        failure "Created server has a '$class' class and not 'CmonLxcServer'."
        exit 1
    fi
    
    #
    # Checking the state... TBD
    #
    mys9s tree --cat /$CONTAINER_SERVER/.runtime/state
}

function createCluster()
{
    #
    # Creating a Cluster.
    #
    print_title "Creating a Cluster on LXC"

    mys9s cluster \
        --create \
        --cluster-name="$CLUSTER_NAME" \
        --cluster-type=galera \
        --provider-version="5.6" \
        --vendor=percona \
        --cloud=lxc \
        --nodes="$CONTAINER_NAME1" \
        --containers="$CONTAINER_NAME1" \
        $LOG_OPTION 

    check_exit_code $?
}

#
# This test will add a MaxScale node.
#
function testAddMaxScale()
{
    print_title "Adding a MaxScale Node"
    
    #
    # Adding maxscale to the cluster.
    #
    mys9s cluster \
        --add-node \
        --cluster-id=1 \
        --nodes="maxscale://$CONTAINER_NAME9" \
        --containers="$CONTAINER_NAME9" \
        $LOG_OPTION
    
    check_exit_code $?

    #
    #
    #
    print_title "Checking MaxScale State"
    MAXSCALE_IP=$(maxscale_node_name)

    wait_for_node_state "$MAXSCALE_IP" "CmonHostOnline"
    if [ $? -ne 0 ]; then
        failure "MaxScale $MAXSCALE_IP is not in CmonHostOnline state"
        mys9s node --list --long
        mys9s node --stat $MAXSCALE_IP
    else
        mys9s node --stat $MAXSCALE_IP
    fi
}

function testStopMaxScale()
{
    #
    #
    #
    print_title "Stopping Node"

    mys9s container --stop --wait "$CONTAINER_NAME9"
    check_exit_code $?

    #
    # Checking that the MaxScale goes into offline state.
    #
    print_title "Waiting HapProxy to go Off-line"
    wait_for_node_state "$MAXSCALE_IP" "CmonHostOffLine"

    if [ $? -ne 0 ]; then
        failure "MaxScale $MAXSCALE_IP is not in CmonHostOffLine state"
        mys9s node --list --long
        mys9s node --stat $MAXSCALE_IP
    else
        mys9s node --stat $MAXSCALE_IP
    fi
}

function testStartMaxScale()
{
    #
    #
    #
    print_title "Starting Node"

    mys9s container --start --wait "$CONTAINER_NAME9"
    check_exit_code $?

    #
    # Checking that the MaxScale goes into offline state.
    #
    print_title "Waiting HapProxy to go On-line"
    wait_for_node_state "$MAXSCALE_IP" "CmonHostOnline"

    if [ $? -ne 0 ]; then
        failure "MaxScale $MAXSCALE_IP is not in CmonHostOnLine state"
        mys9s node --list --long
        mys9s node --stat $MAXSCALE_IP
    else
        mys9s node --stat $MAXSCALE_IP
    fi
}

function destroyContainers()
{
    #
    #
    #
    print_title "Destroying Containers"

    mys9s container --delete --wait "$CONTAINER_NAME1"
    mys9s container --delete --wait "$CONTAINER_NAME9"
}

#
# Running the requested tests.
#
startTests
reset_config
grant_user

if [ "$1" ]; then
    for testName in $*; do
        runFunctionalTest "$testName"
    done
else
    runFunctionalTest registerServer
    runFunctionalTest createCluster
    runFunctionalTest testAddMaxScale
    runFunctionalTest testStopMaxScale
    runFunctionalTest testStartMaxScale
    runFunctionalTest destroyContainers
fi

endTests
