
S9S=$(which s9s)
FAILED="no"
TEST_SUITE_NAME=""
TEST_NAME=""
DONT_PRINT_TEST_MESSAGES=""
PRINT_COMMANDS=""

TERM_NORMAL="\033[0;39m"
TERM_BOLD="\033[1m"
XTERM_COLOR_RED="\033[0;31m"
XTERM_COLOR_GREEN="\033[0;32m"
XTERM_COLOR_ORANGE="\033[0;33m"
XTERM_COLOR_BLUE="\033[0;34m"
XTERM_COLOR_PURPLE="\033[0;35m"
XTERM_COLOR_CYAN="\033[0;36m"
XTERM_COLOR_LIGHT_GRAY="\033[0;37m"
XTERM_COLOR_DARK_GRAY="\033[1;30m"
XTERM_COLOR_LIGHT_RED="\033[1;31m"
XTERM_COLOR_LIGHT_GREEN="\033[1;32m"
XTERM_COLOR_YELLOW="\033[1;33m"
XTERM_COLOR_LIGHT_BLUE="\033[1;34m"
XTERM_COLOR_LIGHT_PURPLE="\033[1;35m"
XTERM_COLOR_LIGHT_CYAN="\033[1;36m"
XTERM_COLOR_WHITE="\033[1;37m"

TERM_COLOR_TITLE="\033[1m\033[37m"
CMON_CONTAINER_NAMES=""

if [ -x ../s9s/s9s ]; then
    S9S="../s9s/s9s"
fi

function color_command()
{
    sed \
        -e "s#\(--.\+\)=\([^\\]*\)[\ ]#\x1b\[0;33m\1\x1b\[0;39m=\"\x1b\[1;35m\2\x1b\[0;39m\" #g" \
        -e "s#\(--[^\\\ ]\+\)#\x1b\[0;33m\1\x1b\[0;39m#g"
}

function prompt_string
{
    local dirname=$(basename $PWD)

    echo "$USER@$HOSTNAME:$dirname\$"
}

function mys9s_singleline()
{
    local prompt=$(prompt_string)
    local nth=0

    if [ "$PRINT_COMMANDS" ]; then
        echo -ne "$prompt ${XTERM_COLOR_YELLOW}s9s${TERM_NORMAL} "

        for argument in "$@"; do
            #if [ $nth -gt 0 ]; then
            #    echo -e "\\"
            #fi

            if [ $nth -eq 0 ]; then
                echo -ne "${XTERM_COLOR_BLUE}$argument${TERM_NORMAL}"
            elif [ $nth -eq 1 ]; then
                echo -ne " ${XTERM_COLOR_ORANGE}$argument${TERM_NORMAL}"
            else
                echo -ne " $argument" | color_command
            fi

            let nth+=1
        done
    
        echo ""
    fi

    $S9S --color=always "$@"
}

function mys9s_multiline()
{
    local prompt=$(prompt_string)
    local nth=0

    if [ "$PRINT_COMMANDS" ]; then
        echo ""
        echo -ne "$prompt ${XTERM_COLOR_YELLOW}s9s${TERM_NORMAL} "

        for argument in "$@"; do
            if [ $nth -gt 0 ]; then
                echo -e "\\"
            fi

            if [ $nth -eq 0 ]; then
                echo -ne "${XTERM_COLOR_BLUE}$argument${TERM_NORMAL} "
            elif [ $nth -eq 1 ]; then
                echo -ne "    ${XTERM_COLOR_ORANGE}$argument${TERM_NORMAL} "
            else
                echo -ne "    $argument " | color_command
            fi

            let nth+=1
        done
    
        echo ""
        echo ""
    fi

    $S9S --color=always "$@"
}

function mys9s()
{
    local n_arguments=0
    local argument

    for argument in $*; do
        let n_arguments+=1
    done

    if [ "$n_arguments" -lt 4 ]; then
        mys9s_singleline "$@"
    else
        mys9s_multiline "$@"
    fi
}

#
# Prints a title line that looks nice on the terminal and also on the web.
#
function print_title()
{
    if [ -t 1 ]; then
        echo ""
        echo -e "$TERM_COLOR_TITLE$*\033[0;39m"
        echo -e "\033[1m\
-------------------------------------------------------------------------------\
-\033[0;39m"
    else
        echo "</pre>"
        echo ""
        echo "<h3>$*</h3>"
        echo "<pre>"
    fi
}

#
# This function should be called before the functional tests are executed.
# Currently this only prints a message for the user, but this might change.
#
function startTests ()
{
    local container_list_file="/tmp/${MYNAME}.containers"

    TEST_SUITE_NAME=$(basename $0 .sh)

    echo "Starting test $TEST_SUITE_NAME"
    
    echo -n "Checking if jq is installed..."
    if [ -z "$(which jq)" ]; then
        echo "[INSTALLING]"
        sudo apt install jq
    else
        echo "[OK]"
    fi

    echo -n "Checking if s9s is installed..."
    if [ -z "$S9S" ]; then
        echo " [FAILED]"
        exit 7
    else 
        echo " [OK]"
    fi

    echo -n "Searching for pip-container-create..."
    if [ -z $(which pip-container-create) ]; then
        echo " [FAILED]"
        exit 7
    else 
        echo " [OK]"
    fi

    if [ -f "$container_list_file" ]; then
        echo "Removing '$container_list_file'."
        rm -f "$container_list_file"
    fi

#    if [ -z "$DONT_PRINT_TEST_MESSAGES" ]; then
        echo ""
        echo "***********************"
        echo "* $TEST_SUITE_NAME"
        echo "***********************"
#    fi
}

#
# This function should be called when the function tests are executed. It prints
# a message about the results and exits with the exit code that is true if the
# tests are passed and false if at least one test is failed.
#
function endTests ()
{
    if isSuccess; then
        if [ -z "$DONT_PRINT_TEST_MESSAGES" ]; then
            echo "SUCCESS: $(basename $0 .sh)"
        else
            print_title "Report"
            echo -en "${XTERM_COLOR_GREEN}"
            echo -n  "Test $(basename $0) is successful."
            echo -en "${TERM_NORMAL}"
            echo ""
        fi
          
        exit 0
    else
        if [ -z "$DONT_PRINT_TEST_MESSAGES" ]; then
            echo "FAILURE: $(basename $0 .sh)"
        else
            print_title "Report"
            echo -en "${XTERM_COLOR_RED}"
            echo -n  "Test $(basename $0) has failed."
            echo -en "${TERM_NORMAL}"
            echo ""
        fi
    
        exit 1
    fi
}

#
# This is the BASH function that executes a functional test. The functional test
# itself should be implemented as a BASH function.
#
function runFunctionalTest ()
{
    TEST_NAME=$1

    if ! isSuccess; then
        if [ -z "$DONT_PRINT_TEST_MESSAGES" ]; then
            printf "  %-26s: SKIPPED\n" $1
        fi

        return 1
    else
        $1
    fi

    if [ -z "$DONT_PRINT_TEST_MESSAGES" ]; then
        if ! isSuccess; then
            printf "  %-26s: FAILURE\n" $1
        else 
            printf "  %-26s: SUCCESS\n" $1
        fi
    fi
}

#
# Returns true if none of the tests failed before, false if some bug was
# detected.
#
function isSuccess 
{
    if [ "$FAILED" == "no" ]; then
        return 0
    fi

    return 1
}

#
# Returns true if the --verbose option was provided.
#
function isVerbose 
{
    if [ "$VERBOSE" == "true" ]; then
        return 0
    fi

    return 1
}

#
# Prints the message passed as command line options if the test is executet in
# verbose mode (the --verbose command line option was provided).
#
function printVerbose 
{
    isVerbose && echo "$@" >&2
}

#
# Prints a message about the failure and sets the test failed state.
#
function failure
{
    if [ "$TEST_SUITE_NAME" -a "$TEST_NAME" ]; then
        echo -e "$TEST_SUITE_NAME::$TEST_NAME(): ${XTERM_COLOR_RED}$1${TERM_NORMAL}"
    else
        echo "FAILURE: $1"
    fi

    FAILED="true"
}

#
# Prints a message about the failure and sets the test failed state.
#
function success()
{
    echo -e "${XTERM_COLOR_GREEN}$1${TERM_NORMAL}"
}


#
# This will check the exit code passed as an argument and print the logs
# of the last failed job if the exit code is not 0.
#
function check_exit_code()
{
    local do_not_exit
    local exitCode
    local jobId
    local password_option=""

    if [ -n "$CMON_USER_PASSWORD" ]; then
        password_option="--password='$CMON_USER_PASSWORD'"
    fi

    #
    # Command line options.
    #
    while true; do
        case "$1" in 
            --do-not-exit)
                shift
                do_not_exit="true"
                ;;

            *)
                break
                ;;
        esac
    done

    exitCode="$1"

    #
    # Checking...
    #
    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}"

        jobId=$(\
            s9s job --list --batch $password_option | \
            grep FAIL | \
            tail -n1 | \
            awk '{print $1}')

        if [ "$jobId" -a "$LOG_OPTION" != "--log" ]; then
            echo "A job is failed. The test script will now try to list the"
            echo "job messages of the failed job. Here it is:"
            mys9s job \
                --log \
                $password_option \
                --debug \
                --job-id="$jobId"
        fi

        if [ "$do_not_exit" ]; then
            return 1
        else
            exit $exitCode
        fi
    fi

    return 0
}

function check_exit_code_no_job()
{
    local exitCode="$1"

    if [ "$exitCode" -ne 0 ]; then
        failure "The exit code is ${exitCode}."
        return 1
    fi

    return 0
}

function check_container()
{
    local container_name="$1"
    local container_ip
    local owner

    #
    # Checking the container IP.
    #
    container_ip=$(\
        s9s server \
            --list-containers \
            --batch \
            --long  "$container_name" \
        | awk '{print $6}')
    
    if [ -z "$container_ip" ]; then
        failure "The container was not created or got no IP."
        s9s container --list --long
        exit 1
    fi

    if [ "$container_ip" == "-" ]; then
        failure "The container got no IP."
        s9s container --list --long
        exit 1
    fi
  
    owner=$(\
        s9s container --list --long --batch "$container_name" | \
        awk '{print $4}')

    if [ "$owner" != "$USER" ]; then
        failure "The owner is '$owner', should be '$USER'"
        exit 1
    fi

    if ! is_server_running_ssh "$container_ip" "$owner"; then
        failure "User $owner can not log in to $container_ip"
        exit 1
    else
        echo "check_container(): " \
            "SSH access granted for user '$USER' on $container_ip."
    fi
}

#
# This function will check if a core file is created and fails the test if so.
#
function checkCoreFile 
{
    for corefile in data/core /tmp/cores/*; do 
        if [ -e "$corefile" ]; then
            failure "Some core file(s) found."
            ls -lha $corefile
        fi
    done
}

function find_line()
{
    local text="$1"
    local line="$2"
    local tmp

    while true; do
        tmp=$(echo "$text" | sed -e 's/  / /g')
        if [ "$tmp" == "$text" ]; then
            break
        fi

        text="$tmp"
    done

    while true; do
        tmp=$(echo "$line" | sed -e 's/  / /g')
        if [ "$tmp" == "$line" ]; then
            break
        fi

        line="$tmp"
    done

    printVerbose "text: $text"
    printVerbose "line: $line"

    echo "$text" | grep --quiet "$line"
    return $?
}

#
# $1: the file in which the output messages are stored.
# $2: the message to find.
#
function checkMessage()
{
    local file="$1"
    local message="$2"

    if [ -z "$file" ]; then
        failure "Internal error: checkMessage() has no file name"
        return 1
    fi

    if [ -z "$message" ]; then
        failure "Internal error: checkMessage() has no message"
        return 1
    fi

    if grep -q "$message" "$file"; then
        return 0
    fi

    failure "Text '$message' missing from output"
    return 1
}

#
# Prints an error message to the standard error. The text will not mixed up with
# the data that is printed to the standard output.
#
function printError()
{
    local datestring=$(date "+%Y-%m-%d %H:%M:%S")

    echo -e "$*" >&2

    if [ "$LOGFILE" ]; then
        echo -e "$datestring ERROR $MYNAME($$) $*" >>"$LOGFILE"
    fi
}


function cluster_state()
{
    local clusterId="$1"

    s9s cluster --list --cluster-id=$clusterId --cluster-format="%S"
}        

function node_state()
{
    local nodeName="$1"
        
    s9s node --list --batch --long --node-format="%S" "$nodeName"
}

function node_ip()
{
    local nodeName="$1"
        
    s9s node --list --batch --long --node-format="%A" "$nodeName"
}

function container_ip()
{
    local is_private

    while [ -n "$1" ]; do
        case "$1" in
            --private)
                shift
                is_private="true"
                ;;

            *)
                break
                ;;
        esac
    done


    if [ -z "$is_private" ]; then
        s9s container --list --batch --long --container-format="%A" "$1"
    else
        s9s container --list --batch --long --container-format="%a" "$1"
    fi
}

#
# This function will wait for a node to pick up a state and stay in that state
# for a while.
#
function wait_for_node_state()
{
    local nodeName="$1"
    local expectedState="$2"
    local state
    local waited=0
    local stayed=0

    if [ -z "$nodeName" ]; then
        printError "Expected a node name."
        return 6
    fi

    if [ -z "$expectedState" ]; then 
        printError "Expected state name."
        return 6
    fi

    while true; do
        state=$(node_state "$nodeName")
        if [ "$state" == $expectedState ]; then
            let stayed+=1
        else
            let stayed=0

            #
            # Would be crazy to timeout when we are in the expected state, so we
            # do check the timeout only when we are not in the expected state.
            #
            if [ "$waited" -gt 120 ]; then
                return 1
            fi
        fi

        if [ "$stayed" -gt 10 ]; then
            return 0
        fi

        let waited+=1
        sleep 1
    done

    return 2
}

function haproxy_node_name()
{
    s9s node --list --long --batch |\
        grep '^h' | \
        awk '{print $5 }'
}

function maxscale_node_name()
{
    s9s node --list --long --batch |\
        grep '^x' | \
        awk '{print $5 }'
}

function proxysql_node_name()
{
    s9s node --list --long --batch |\
        grep '^y' | \
        awk '{print $5 }'
}

# $1: Name of the node.
# Returns the "container_id" property for the given node.
function node_container_id()
{
    local node_name="$1"

    s9s node --list --node-format "%v\n" "$node_name"
}

#
# Checks the container IDs of the specified nodes.
#
function check_container_ids()
{
    local node_ip
    local node_ips
    local container_id
    local filter=""

    while [ "$1" ]; do
        case "$1" in 
            --galera-nodes)
                shift
                filter="^g"
                ;;

            --postgresql-nodes)
                shift
                filter="^p"
                ;;

            --replication-nodes)
                shift
                filter="^s"
                ;;

            *)
                break
                ;;
        esac
    done

    if [ -z "$filter" ]; then
        failure "check_container_ids(): Missing command line option."
        return 1
    fi

    #
    # Checking the container ids.
    #
    node_ips=$(s9s node --list --long | grep "$filter" | awk '{ print $5 }')
    for node_ip in $node_ips; do
        print_title "Checking Node $node_ip"

        container_id=$(node_container_id "$node_ip")
        echo "      node_ip: $node_ip"
        echo " container_id: $container_id"
            
        if [ -z "$container_id" ]; then
            failure "The container ID was not found."
        fi

        if [ "$container_id" == "-" ]; then
            failure "The container ID is '-'."
        fi
    done
}

#
# This function waits until the host goes into CmonHostShutDown state and then
# waits if it remains in that state for a while. A timeout is implemented and 
# the return value shows if the node is indeed in the CmonHostShutDown state.
#
function wait_for_node_shut_down()
{
    wait_for_node_state "$1" "CmonHostShutDown"
    return $?
}

#
# This function waits until the host goes into CmonHostOnline state and then
# waits if it remains in that state for a while. A timeout is implemented and 
# the return value shows if the node is indeed in the CmonHostOnline state.
#
function wait_for_node_online()
{
    wait_for_node_state "$1" "CmonHostOnline"
    return $?
}

#
# This function waits until the host goes into CmonHostOffLine state and then
# waits if it remains in that state for a while. A timeout is implemented and 
# the return value shows if the node is indeed in the CmonHostOffLine state.
#
function wait_for_node_offline()
{
    wait_for_node_state "$1" "CmonHostOffLine"
    return $?
}

#
# This function waits until the host goes into CmonHostFailed state and then
# waits if it remains in that state for a while. A timeout is implemented and 
# the return value shows if the node is indeed in the CmonHostFailed state.
#
function wait_for_node_failed()
{
    wait_for_node_state "$1" "CmonHostFailed"
    return $?
}

function wait_for_cluster_state()
{
    local clusterName
    local expectedState
    local state
    local waited=0
    local stayed=0
    local user_option
    local password_option
    local controller_option

    while [ -n "$1" ]; do
        case "$1" in 
            --system)
                shift
                user_option="--cmon-user=system"
                password_option="--password=secret"
                ;;

            --controller)
                controller_option="--controller=$2"
                shift 2
                ;;

            *)
                break
                ;;
        esac
    done

    clusterName="$1"
    expectedState="$2"

    if [ -z "$clusterName" ]; then
        printError "Expected a cluster name."
        return 6
    fi

    if [ -z "$expectedState" ]; then 
        printError "Expected state name."
        return 6
    fi

    while true; do
        state=$(s9s cluster \
            --list \
            --cluster-format="%S" \
            --cluster-name="$clusterName" \
            $user_option \
            $controller_option \
            $password_option)

        #echo "***         state: '$state'" >&2
        #echo "*** expectedState: '$expectedState'" >&2
        if [ "$state" == $expectedState ]; then
            let stayed+=1
        else
            let stayed=0

            #
            # Would be crazy to timeout when we are in the expected state, so we
            # do check the timeout only when we are not in the expected state.
            #
            if [ "$waited" -gt 120 ]; then
                return 1
            fi
        fi

        if [ "$stayed" -gt 10 ]; then
            return 0
        fi

        let waited+=1
        sleep 1
    done

    return 2
}

function wait_for_cluster_started()
{
    wait_for_cluster_state $* "STARTED"
    return $?
}

function get_container_ip()
{
    local container_name="$1"

    s9s container \
        --list \
        --long \
        --batch \
        "$container_name" \
    | \
        awk '{print $6}'
}

#
# $1: the server name
# $2: The username
#
function is_server_running_ssh()
{
    local serverName
    local owner
    local keyfile
    local keyOption
    local isOK
    local option_current_user

    while true; do
        case "$1" in 
            --current-user)
                shift
                option_current_user="true"
                ;;

            *)
                break
        esac
    done

    serverName="$1"
    owner="$2"
    keyfile="$3"

    if [ "$keyfile" ]; then
        keyOption="-i $keyfile"
    fi

    if [ "$option_current_user" ]; then
        isOk=$(\
            ssh -o ConnectTimeout=1 \
                -o UserKnownHostsFile=/dev/null \
                -o StrictHostKeyChecking=no \
                -o LogLevel=quiet \
                $keyOption \
                "$owner@$serverName" \
                2>/dev/null -- echo OK)
    else
        isOk=$(sudo -u $owner -- \
            ssh -o ConnectTimeout=1 \
                -o UserKnownHostsFile=/dev/null \
                -o StrictHostKeyChecking=no \
                -o LogLevel=quiet \
                $keyOption \
                "$serverName" \
                2>/dev/null -- echo OK)
    fi

    if [ "$isOk" == "OK" ]; then
        return 0
    fi

    return 1
}

#
# $2: the server name
#
# Waits until the server is accepting SSH connections. There is also a timeout
# implemented here.
#
function wait_for_server_ssh()
{
    local serverName="$1"
    local OWNER="$2"
    local nTry=0
    local nSuccess=0

    while true; do
        if is_server_running_ssh "$serverName" $OWNER; then
            printVerbose "Server '$serverName' is reachable."
            let nSuccess+=1
        else
            printVerbose "Server '$serverName' is not reachable."
            let nSuccess=0

            # 120 x 5 = 10 minutes
            if [ "$nTry" -gt 180 ]; then
                printVerbose "Server '$serverName' did not came alive."
                return 1
            fi
        fi

        if [ "$nSuccess" -gt 3 ]; then
            printVerbose "Server '$serverName' is stable."
            return 0
        fi

        sleep 5
        let nTry+=1
    done

    return 0
}

#
# $1: The name of the container or just leave it empty for the default name.
#
# Creates and starts a new virtual machine node.
#
function create_node()
{
    local ip
    local retval
    local verbose_option=""
    local option_autodestroy=""
    local container_list_file="/tmp/${MYNAME}.containers"
    local template_option=""

    while [ "$1" ]; do
        case "$1" in 
            --autodestroy)
                shift
                option_autodestroy="true"
                ;;

            --template)
                template_option="--template=$2"
                shift 2
                ;;

            *)
                break
                ;;
        esac
    done


    if [ "$VERBOSE" ]; then
        verbose_option="--verbose"
    fi

    if [ -z "$CONTAINER_SERVER" ]; then
        printError "The container server is not set."
        return 1
    fi

    echo -n "Creating container..." >&2
    ip=$(pip-container-create \
        $template_option \
        $verbose_option \
        --server=$CONTAINER_SERVER $1)

    retval=$?
    if [ "$retval" -ne 0 ]; then
        printError "pip-container-create returned ${retval}."
        tail $HOME/pip-container-create.log >&2
    fi

    printVerbose "Created '$ip'."
   
    #
    # Waiting until the server is up and accepts SSH connections.
    #
    wait_for_server_ssh "$ip" "$USER"
    retval=$?
    if [ "$retval" -ne 0 ]; then
        echo -e " $XTERM_COLOR_RED[FAILURE]$TERM_NORMAL" >&2
        echo "Could not reach created server at ip '$ip'." >&2
    else
        echo -e " $XTERM_COLOR_GREEN[SUCCESS]$TERM_NORMAL" >&2
    fi

    if [ "$option_autodestroy" ]; then
        echo "$ip" >>$container_list_file
    fi

    echo $ip
}

function node_created()
{
    local container_ip="$1"
    local container_list_file="/tmp/${MYNAME}.containers"
    
    echo "$container_ip" >>"$container_list_file"
}

function emit_s9s_configuration_file()
{
    cat <<EOF
#
# This configuration file was created by ${MYNAME} version ${VERSION}.
#
[global]
controller = https://localhost:9556

[log]
brief_job_log_format = "%36B:%-5L: %-7S %M\n"
brief_log_format     = "%C %36B:%-5L: %-8S %M\n"
EOF
}

function reset_config()
{
    local config_dir="$HOME/.s9s"
    local config_file="$config_dir/s9s.conf"
    local do_not_create

    while [ "$1" ]; do
        case "$1" in 
            --do-not-create)
                shift
                do_not_create="true"
                ;;

            *)
                break
        esac
    done
            
    if [ -z "$OPTION_RESET_CONFIG" ]; then
        return 0
    fi
   
    if [ -z "$do_not_create" ]; then
        print_title "Overwriting s9s Configuration"
    else
        print_title "Deleting s9s Configuration"
    fi

    if [ -d "$config_dir" ]; then
        rm -rf "$config_dir"
    fi

    if [ -z "$do_not_create" ]; then
        if [ ! -d "$config_dir" ]; then
            mkdir "$config_dir"
        fi

        emit_s9s_configuration_file >$config_file

        # This goes to the standard output.
        emit_s9s_configuration_file
    fi

    # FIXME: This should not be here:
    sudo rm -f $HOME/pip-container-create.log 2>/dev/null
}

#
# $1: the name of the cluster
#
function find_cluster_id()
{
    local name="$1"
    local retval
    local nTry=0
    local password_option=""
    
    if [ -n "$CMON_USER_PASSWORD" ]; then
        password_option="--password='$CMON_USER_PASSWORD'"
    fi

    while true; do
        retval=$($S9S cluster \
            --list \
            --long \
            --batch \
            $password_option \
            --cluster-name="$name")

        retval=$(echo "$retval" | awk '{print $1}')

        if [ -z "$retval" ]; then
            printVerbose "Cluster '$name' was not found."
            let nTry+=1

            if [ "$nTry" -gt 10 ]; then
                echo "NOT-FOUND"
                break
            else
                sleep 3
            fi
        else
            printVerbose "Cluster '$name' was found with ID ${retval}."
            echo "$retval"
            break
        fi
    done
}

#
# Just a normal createUser call we do all the time to register a user on the
# controller so that we can actually execute RPC calls.
#
function grant_user()
{
    local first
    local last

    print_title "Creating the First User"
    first=$(getent passwd $USER | cut -d ':' -f 5 | cut -d ',' -f 1 | cut -d ' ' -f 1)
    last=$(getent passwd $USER | cut -d ':' -f 5 | cut -d ',' -f 1 | cut -d ' ' -f 2)

    mys9s user \
        --create \
        --group="testgroup" \
        --create-group \
        --generate-key \
        --controller="https://localhost:9556" \
        --new-password="p" \
        --email-address="laszlo@severalnines.com" \
        --first-name="$first" \
        --last-name="$last" \
        $OPTION_PRINT_JSON \
        $OPTION_VERBOSE \
        --batch \
        "$USER"

    exitCode=$?
    if [ "$exitCode" -ne 0 ]; then
        failure "Exit code is not 0 while granting user."
        return 1
    fi

    #
    # Adding the user's default SSH public key. This will come handy when we
    # create a container because this way the user will be able to log in with
    # the SSH key without password.
    #
    mys9s user \
        --add-key \
        --public-key-file="/home/$USER/.ssh/id_rsa.pub" \
        --public-key-name="The_SSH_key"

    #mys9s user --list-keys
    #mys9s server --list --long
    #mys9s server --unregister --servers=cmon-cloud://localhost
}

function get_user_group()
{
    local user_name="$1"

    if [ -z "$user_name" ]; then
        failure "No user name in get_user_group()"
        return 1
    fi

    s9s user --list --user-format="%G" $user_name
}

function get_user_email()
{
    local user_name="$1"

    if [ -z "$user_name" ]; then
        failure "No user name in get_user_group()"
        return 1
    fi

    s9s user --list --user-format="%M" $user_name
}

function check_controller()
{
    local owner
    local group
    local cdt_path
    local status
    local tmp

    while [ -n "$1" ]; do
        case "$1" in 
            --owner)
                owner="$2"
                shift 2
                ;;

            --group)
                group="$2"
                shift 2
                ;;

            --cdt-path)
                cdt_path="$2"
                shift 2
                ;;

            --status)
                status="$2"
                shift 2
                ;;
        esac
    done

    echo ""
    echo "Checking controller..."

    if [ -n "$owner" ]; then
        tmp=$(\
            s9s node --list --node-format "%R %O\n" | \
            grep "controller" | \
            awk '{print $2}')

        if [ "$tmp" == "$owner" ]; then
            success "  o The owner of the controller is $tmp, ok."
        else
            failure "The owner of the controller should not be '$tmp'."
        fi
    fi

    if [ -n "$group" ]; then
        tmp=$(\
            s9s node --list --node-format "%R %G\n" | \
            grep "controller" | \
            awk '{print $2}')

        if [ "$tmp" == "$group" ]; then
            success "  o The group of the controller is $tmp, ok."
        else
            failure "The group of the controller should not be '$tmp'."
        fi
    fi

    if [ -n "$cdt_path" ]; then
        tmp=$(\
            s9s node --list --node-format "%R %h\n" | \
            grep "controller" | \
            awk '{print $2}')

        if [ "$tmp" == "$cdt_path" ]; then
            success "  o The CDT path of the controller is $tmp, ok."
        else
            failure "The CDT path of the controller should not be '$tmp'."
        fi

    fi

    if [ -n "$status" ]; then
        tmp=$(\
            s9s node --list --node-format "%R %S\n" | \
            grep "controller" | \
            awk '{print $2}')

        if [ "$tmp" == "$status" ]; then
            success "  o The status of the controller is $tmp, ok."
        else
            failure "The status of the controller should not be '$tmp'."
        fi

    fi
}

function check_node()
{
    local hostname
    local ipaddress
    local port
    local owner
    local group
    local cdt_path
    local status
    local config
    local no_maintenance
    local tmp

    while [ -n "$1" ]; do
        case "$1" in 
            --node|--host)
                hostname="$2"
                shift 2
                ;;

            --ip-address)
                ipaddress="$2"
                shift 2
                ;;

            --port)
                port="$2"
                shift 2
                ;;

            --owner)
                owner="$2"
                shift 2
                ;;

            --group)
                group="$2"
                shift 2
                ;;

            --cdt-path)
                cdt_path="$2"
                shift 2
                ;;

            --status)
                status="$2"
                shift 2
                ;;

            --config)
                config="$2"
                shift 2
                ;;

            --no-maint|--no-maintenance)
                no_maintenance="true"
                shift
                ;;
        esac
    done

    if [ -z "$hostname" ]; then
        failure "Hostname is not provided while checking node."
        return 1
    fi

    echo ""
    echo "Checking node '$hostname'..."

    if [ -n "$ipaddress" ]; then
        tmp=$(s9s node --list --node-format "%A\n" "$hostname")

        if [ "$tmp" == "$ipaddress" ]; then
            success "  o The IP of the node is $tmp, ok."
        else
            failure "The IP of the node should not be '$tmp'."
        fi
    fi
    
    if [ -n "$port" ]; then
        tmp=$(s9s node --list --node-format "%P\n" "$hostname")

        if [ "$tmp" == "$port" ]; then
            success "  o The port of the node is $tmp, ok."
        else
            failure "The port of the node should not be '$tmp'."
        fi
    fi

    if [ -n "$owner" ]; then
        tmp=$(s9s node --list --node-format "%O\n" "$hostname")

        if [ "$tmp" == "$owner" ]; then
            success "  o The owner of the node is $tmp, ok."
        else
            failure "The owner of the node should not be '$tmp'."
        fi
    fi

    if [ -n "$group" ]; then
        tmp=$(s9s node --list --node-format "%G\n" "$hostname")

        if [ "$tmp" == "$group" ]; then
            success "  o The group of the node is $tmp, ok."
        else
            failure "The group of the node should not be '$tmp'."
        fi
    fi

    if [ -n "$cdt_path" ]; then
        tmp=$(s9s node --list --node-format "%h\n" "$hostname")

        if [ "$tmp" == "$cdt_path" ]; then
            success "  o The CDT path of the node is $tmp, ok."
        else
            failure "The CDT path of the node should not be '$tmp'."
        fi

    fi

    if [ -n "$status" ]; then
        tmp=$(s9s node --list --node-format "%S\n" "$hostname")

        if [ "$tmp" == "$status" ]; then
            success "  o The status of the node is $tmp, ok."
        else
            failure "The status of the node should not be '$tmp'."
        fi
    fi
    
    if [ -n "$config" ]; then
        tmp=$(s9s node --list --node-format "%C\n" "$hostname")

        if [ "$tmp" == "$config" ]; then
            success "  o The config file of the node is $tmp, ok."
        else
            failure "The config file of the node should not be '$tmp'."
        fi
    fi
    
    if [ -n "$no_maintenance" ]; then
        tmp=$(s9s node --list --node-format "%a\n" "$hostname")

        if [ "$tmp" == "-" ]; then
            success "  o The maintenance of the node is '$tmp', ok."
        else
            failure "The maintenance of the node should not be '$tmp'."
        fi
    fi
}

function check_cluster()
{
    local config_file
    local log_file
    local owner
    local group
    local cdt_path
    local cluster_type
    local cluster_name
    local cluster_state
    local tmp

    while [ -n "$1" ]; do
        case "$1" in 
            --cluster|--cluster-name)
                cluster_name="$2"
                shift 2
                ;;

            --config)
                config_file="$2"
                shift 2
                ;;

            --log)
                log_file="$2"
                shift 2
                ;;
                
            --owner)
                owner="$2"
                shift 2
                ;;

            --group)
                group="$2"
                shift 2
                ;;

            --cdt-path)
                cdt_path="$2"
                shift 2
                ;;

            --type|--cluster-type)
                cluster_type="$2"
                shift 2
                ;;

            --state|--cluster-state)
                cluster_state="$2"
                shift 2
                ;;
        esac
    done

    if [ -z "$cluster_name" ]; then
        failure "No cluster name provided while checking cluster."
        return 1
    fi

    echo ""
    echo "Checking cluster '$cluster_name'..."

    if [ -n "$config_file" ]; then
        tmp=$(s9s cluster --list --cluster-format "%C\n" "$cluster_name")

        if [ "$tmp" == "$config_file" ]; then
            success "  o The config file of the cluster is $tmp, ok."
        else
            failure "The config file of the cluster should not be '$tmp'."
        fi
    fi
    
    if [ -n "$log_file" ]; then
        tmp=$(s9s cluster --list --cluster-format "%L\n" "$cluster_name")

        if [ "$tmp" == "$log_file" ]; then
            success "  o The log file of the cluster is $tmp, ok."
        else
            failure "The log file of the cluster should not be '$tmp'."
        fi
    fi
    
    if [ -n "$owner" ]; then
        tmp=$(s9s cluster --list --cluster-format "%O\n" "$cluster_name")

        if [ "$tmp" == "$owner" ]; then
            success "  o The owner of the cluster is $tmp, ok."
        else
            failure "The owner of the cluster should not be '$tmp'."
        fi
    fi
    
    if [ -n "$group" ]; then
        tmp=$(s9s cluster --list --cluster-format "%G\n" "$cluster_name")

        if [ "$tmp" == "$group" ]; then
            success "  o The group of the cluster is $tmp, ok."
        else
            failure "The group of the cluster should not be '$tmp'."
        fi
    fi
    
    if [ -n "$cdt_path" ]; then
        tmp=$(s9s cluster --list --cluster-format "%P\n" "$cluster_name")

        if [ "$tmp" == "$cdt_path" ]; then
            success "  o The CDT path of the cluster is $tmp, ok."
        else
            failure "The CDT path of the cluster should not be '$tmp'."
        fi
    fi
    
    if [ -n "$cluster_type" ]; then
        tmp=$(s9s cluster --list --cluster-format "%T\n" "$cluster_name")

        if [ "$tmp" == "$cluster_type" ]; then
            success "  o The type of the cluster is $tmp, ok."
        else
            failure "The type of the cluster should not be '$tmp'."
        fi
    fi

    if [ -n "$cluster_state" ]; then
        tmp=$(s9s cluster --list --cluster-format "%S\n" "$cluster_name")

        if [ "$tmp" == "$cluster_state" ]; then
            success "  o The state of the cluster is $tmp, ok."
        else
            failure "The state of the cluster should not be '$tmp'."
        fi
    fi

}

function check_user()
{
    local user_name
    local group
    local password
    local email
    local check_key
    local tmp

    while [ -n "$1" ]; do
        case "$1" in 
            --user-name)
                user_name="$2"
                shift 2
                ;;

            --group)
                group="$2"
                shift 2
                ;;

            --email-address|--email)
                email="$2"
                shift 2
                ;;

            --password)
                password="$2"
                shift 2
                ;;

            --check-key)
                check_key="true"
                shift
                ;;

            *)
                break
                ;;
        esac
    done

    echo "" 
    echo "Checking user $user_name:"
    if [ -z "$user_name" ]; then
        failure "check_user(): No username provided."
        return 1
    fi

    #
    # If the group is provided we check the group of the user.
    #
    if [ -n "$group" ]; then
        tmp=$(get_user_group "$user_name")
        if [ "$tmp" != "$group" ]; then
            failure "The group of $user_name should be $group and not $tmp."
        else
            success "  o group is $group, ok"
        fi
    fi

    #
    # Checking the authentication with a password.
    #
    if [ -n "$password" ]; then
        tmp=$(s9s user --whoami --cmon-user="$user_name" --password="$password")
        if [ "$tmp" != "$user_name" ]; then
            failure "User $user_name can not log in with password."
        else
            success "  o login with password ok"
        fi
    fi

    #
    # Checking the login with the key.
    #
    if [ -n "$check_key" ]; then
        tmp=$(s9s user --whoami --cmon-user="$user_name")
        if [ "$tmp" != "$user_name" ]; then
            failure "User $user_name can not log in with key."
        else
            success "  o login with key ok"
        fi

        tmp="$HOME/.s9s/${user_name}.key"
        if [ ! -f "$tmp" ]; then
            failure "File $tmp does not exist."
        else
            success "  o file '$tmp' exists, ok"
        fi
        
        tmp="$HOME/.s9s/${user_name}.pub"
        if [ ! -f "$tmp" ]; then
            failure "File $tmp does not exist."
        else
            success "  o file '$tmp' exists, ok"
        fi

        #mys9s user --list-keys --cmon-user=$user_name
    fi

    #
    #
    #
    if [ -n "$email" ]; then
        tmp=$(get_user_email "$user_name")
        if [ "$tmp" != "$email" ]; then
            failure "The email of $user_name should be $email and not $tmp."
        else
            success "  o email address is $email, ok"
        fi
    fi
}

#
# A flexible function to check the properties and the state of a container
# server.
#
function check_container_server()
{
    local container_server
    local expected_class_name
    local old_ifs="$IFS"
    local n_names_found
    local class
    local cloud
    local cloud_option
    local file

    while [ -n "$1" ]; do
        case "$1" in 
            --server-name)
                container_server="$2"
                shift 2
                ;;

            --class)
                expected_class_name="$2"
                shift 2
                ;;

            --cloud)
                cloud="$2"
                cloud_option="--cloud=$cloud"
                shift 2
                ;;

            *)
                break
                ;;
        esac
    done

    print_title "Checking Server $container_server"

    if [ -z "$container_server" ]; then
        failure "check_container_server(): No server name."
        return 1
    fi

    mys9s server --list --long $container_server
    mys9s server --stat        $container_server

    #
    # Checking the class is very important.
    #
    class=$(\
        s9s server --stat "$container_server" \
        | grep "Class:" | awk '{print $2}')

    if [ -n "$expected_class_name" ]; then
        if [ "$class" != "$expected_class_name" ]; then
            failure "Server $container_server has '$class' class."
            return 1
        fi
    elif [ -z "$class" ]; then
        failure "Server $container_server has empty class name."
        return 1
    fi

    #
    # Checking the state runtime information.
    #
    echo ""
    file="/$container_server/.runtime/state"
    n_names_found=0
    #mys9s tree --cat $file
    
    IFS=$'\n'
    for line in $(s9s tree --cat $file)
    do
        name=$(echo "$line" | awk '{print $1}')
        value=$(echo "$line" | awk '{print substr($0, index($0,$3))}')
        printf "$XTERM_COLOR_BLUE%32s$TERM_NORMAL is " "$name"
        printf "'$XTERM_COLOR_ORANGE%s$TERM_NORMAL'\n" "$value"
        
        [ -z "$name" ]  && failure "Name is empty."
        [ -z "$value" ] && failure "Value is empty for $name."
        case "$name" in
            container_server_instance)
                let n_names_found+=1
                ;;

            container_server_class)
                [ "$value" != "$expected_class_name" ] && \
                    failure "Value is '$value'."
                let n_names_found+=1
                ;;

            server_name)
                [ "$value" != "$container_server" ] && \
                    failure "Value is '$value'."
                let n_names_found+=1
                ;;

            number_of_processors)
                if [ "$expected_class_name" != "CmonCloudServer" ]; then
                    [ "$value" -lt 1 ] && \
                        failure "Value is less than 1."
                fi

                let n_names_found+=1
                ;;

            number_of_processor_threads)
                if [ "$expected_class_name" != "CmonCloudServer" ]; then
                    [ "$value" -lt 1 ] && \
                        failure "Value is less than 1."
                fi

                let n_names_found+=1
                ;;
            
            total_memory_gbyte)
                if [ "$expected_class_name" != "CmonCloudServer" ]; then
                    [ "$value" -lt 2 ] && \
                        failure "Value is less than 2."
                fi

                let n_names_found+=1
                ;;
        esac
    done 
    IFS=$old_ifs

    #echo "n_names_found: $n_names_found"
    #echo 
    if [ "$n_names_found" -lt 6 ]; then
        failure "Some lines could not be found in $file."
    fi

    #
    # Checking the server manager.
    #
    echo ""
    file="/.runtime/server_manager"
    n_names_found=0

    #mys9s tree \
    #    --cat \
    #    --cmon-user=system \
    #    --password=secret \
    #    $file

    IFS=$'\n'
    for line in $(s9s tree --cat --cmon-user=system --password=secret $file)
    do
        name=$(echo "$line" | awk '{print $1}')
        value=$(echo "$line" | awk '{print $3}')
        printf "$XTERM_COLOR_BLUE%32s$TERM_NORMAL is " "$name"
        printf "'$XTERM_COLOR_ORANGE%s$TERM_NORMAL'\n" "$value"
        
        [ -z "$name" ]  && failure "Name is empty."
        [ -z "$value" ] && failure "Value is empty for $name."
        case "$name" in 
            server_manager_instance)
                let n_names_found+=1
                ;;
            
            number_of_servers)
                [ "$value" -lt 1 ] && \
                    failure "Value is less than 1."
                let n_names_found+=1
                ;;

            number_of_processors)
                if [ "$expected_class_name" != "CmonCloudServer" ]; then
                    [ "$value" -lt 1 ] && \
                        failure "Value is less than 1."
                fi

                let n_names_found+=1
                ;;

            number_of_processor_threads)
                if [ "$expected_class_name" != "CmonCloudServer" ]; then
                    [ "$value" -lt 1 ] && \
                        failure "Value is less than 1."
                fi

                let n_names_found+=1
                ;;

            total_memory_gbyte)
                if [ "$expected_class_name" != "CmonCloudServer" ]; then
                    [ "$value" -lt 2 ] && \
                        failure "Value is less than 2."
                fi

                let n_names_found+=1
                ;;
        esac 
    done 
    IFS=$old_ifs
    
    #echo "n_names_found: $n_names_found"
    #echo 

    if [ "$n_names_found" -lt 5 ]; then
        failure "Some lines could not be found in $file."
    fi

    #
    # Checking the regions.
    #
    mys9s server --list-regions $cloud_option

    n_names_found=0
    IFS=$'\n'
    for line in $(s9s server --list-regions --batch $cloud_option)
    do
        #echo "Checking line $line"
        the_credentials=$(echo "$line" | awk '{print $1}')
        the_cloud=$(echo "$line" | awk '{print $2}')
        the_server=$(echo "$line" | awk '{print $3}')
        the_region=$(echo "$line" | awk '{print $4}')

        if [ "$the_server" != "$container_server" ]; then
            continue
        fi

        if [ "$the_credentials" != 'Y' ]; then
            continue
        fi

        let n_names_found+=1
    done
    IFS=$old_ifs
    
    if [ "$n_names_found" -lt 1 ]; then
        failure "No regions with credentials found."
    fi

    #
    # Checking the templates.
    #
    mys9s server --list-templates --long $cloud_option

    n_names_found=0
    IFS=$'\n'
    for line in $(s9s server --list-templates --batch --long $cloud_option)
    do
        #echo "Checking line $line"
        line=$(echo "$line" | sed -e 's/Southeast Asia/Southeast_Asia/g')
        the_cloud=$(echo "$line" | awk '{print $1}')
        the_region=$(echo "$line" | awk '{print $2}')
        the_server=$(echo "$line" | awk '{print $5}')
        the_template=$(echo "$line" | awk '{print $6}')

        #echo "cloud: '$the_cloud' region: '$the_region' server: '$the_server'"
        if [ "$the_server" != "$container_server" ]; then
            continue
        fi

        if [ -n "$cloud" ]; then
            if [ "$the_cloud" != "$cloud" ]; then
                failure "The cloud is $the_cloud is not $cloud."
            fi
        fi

        if [ -z "$the_template" ]; then
            failure "Template name is missing."
        fi

        let n_names_found+=1
    done
    IFS=$old_ifs

    if [ "$n_names_found" -lt 1 ]; then
        failure "No templates found."
    fi
}

#
# This will destroy the containers we created. This method is automatically
# called by this:
#
# trap clean_up_after_test EXIT
#
function clean_up_after_test()
{
    local all_created_ip=""
    local container_list_file="/tmp/${MYNAME}.containers"
    local container

    #
    # Some closing logs.
    #
    print_title "Preparing to Exit"
    if false; then
        mys9s tree \
            --cat \
            --cmon-user=system \
            --password=secret \
            /.runtime/job_manager
    
        mys9s tree \
            --cat \
            --cmon-user=system \
            --password=secret \
            /.runtime/host_manager
    fi

    # Reading the container list file.
    if [ -f "$container_list_file" ]; then
        for container in $(cat $container_list_file); do
            if [ -z "$container" ]; then
                continue
            fi

            if [ "$all_created_ip" ]; then
                all_created_ip+=" "
            fi

            all_created_ip+="$container"
        done
    fi

    # Destroying the nodes if we have to.
    if [ "$OPTION_LEAVE_NODES" ]; then
        print_title "Leaving the Containers"
        echo "The --leave-nodes option was provided, not destroying the "
        echo "containers."
        echo "     server : $CONTAINER_SERVER"
        echo " containers : $all_created_ip"
    elif [ "$OPTION_INSTALL" ]; then
        print_title "Leaving the Containers"
        echo "The --install option was provided, not destroying the "
        echo "containers."
        echo "     server : $CONTAINER_SERVER"
        echo " containers : $all_created_ip"
    elif [ "$all_created_ip" ]; then
        print_title "Destroying the Containers"
        echo "     server : $CONTAINER_SERVER"
        echo " containers : $all_created_ip"

        pip-container-destroy \
            --server=$CONTAINER_SERVER \
            "$all_created_ip" \
            >/dev/null 2>/dev/null
        
        echo "    retcode : $?"
    fi

    # Destroying the container list file.
    if [ -f "$container_list_file" ]; then
        rm -f "$container_list_file"
    fi

    return 0
}

function remember_cmon_container()
{
    local container_name="$1"

    if [ -z "$container_name" ]; then
        return 1
    fi

    if [ -n "$CMON_CONTAINER_NAMES" ]; then
        CMON_CONTAINER_NAMES+=" "
    fi

    CMON_CONTAINER_NAMES+="$container_name"
}

function cmon_container_list()
{
    echo $CMON_CONTAINER_NAMES
}

trap clean_up_after_test EXIT

