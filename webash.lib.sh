

bash_setup()
{
    setup_logging

    # Follow errors, enables stacktrace generation by populating some arrays
    set -o errtrace
    # Explicit version of set -e, exit on error
    set -o errexit
    # If anything fails in a pipeline, all the pipeline is considered failed.
    set -o pipefail
    # Defined, variables must be
    set -o nounset
    
    # Limits IFS to \n only
    IFS=$'\n'
    
    # Setup the exit handler, called when an error is returned by any command, thanks to set -o errexit:
    ## $? Return code of the 
    ## LINENO is the line at which the handler was called
    ## BASH_LINENO is an array containing the line numbers of the functions calls
    ## BASH_SOURCE is an array containing the file names in which the functions are
    ## BASH_COMMAND is the command which triggered the error
    ## FUNCNAME is an array containing the function names 
    ## All the arrays are ordered the same way, which allows correlating the file name, the function name and the line number
    trap 'exit_handler $? $LINENO "${BASH_LINENO[*]}" "${BASH_SOURCE[*]}" "$BASH_COMMAND" "${FUNCNAME[*]:-empty}"'  ERR
}

# Validate a value for a given option against a list of allowed values, exits with an error message  in case it does not match
# Relies on extglob which is set 
validate_option()
{
    local option="$1"
    local provided_value="$2"
    shift 2
    local valid_options="$*"
    local saved_extglob="$(shopt -p extglob)"
    shopt -s extglob
    prepared_valid_options="@(${valid_options// /|})"
    case "${provided_value}" in
    ${prepared_valid_options})
        #echo "Option [${option}] is set to [${provided_value}]"
    ;;
    *)
        echo "Invalid option value [${provided_value}] for option [${option}]. Valid values : [${valid_options}]"
	exit 1
    ;;
    esac
    eval ${saved_extglob}
}

setup_logging()
{
    # By default, the log file is created in /tmp to avoid permissions issues 
    logfile="${logfile:-/tmp/$(basename ${0%.*}).log}"

    # Logs are shown on stdout if the script if called from a tty (ie: manually) or sent in a file.
    #  - terminal_or_file : logs are sent on the terminal OR in the log file
    #  - terminal_and_file : logs are sent both on the terminal and the log file
    validate_option logging_mode ${logging_mode:=terminal_or_file} terminal_or_file terminal_and_file 
    
    # Logs can be appended to the log file, or the log file can be recreated each time
    validate_option logfile_policy ${logfile_policy:=append} append recreate

    [[ ${logfile_policy} == "recreate" ]] && rm -f "${logfile}"
    
    # Do we have a tty attached ?
    term=$(tty)
    if (( $? != 0 ))
    then
        # Nope, let's close stdout and stderr and redirect 
	exec 1<&-
        exec 2<&-
        exec &>> "$logfile"
    elif [[ ${logging_mode} == "terminal_and_file" ]]
    then
	exec &> >(tee -a "$logfile") 
    fi
}

exit_handler()
{
    local err=$1 # error status
    local line=$2 # LINENO
    local bash_linenos=($3)
    local bash_sources=($4)
    local command="$5"
    local funcstack=($6)

    echo -e "\n<---"
    echo -e "\tERROR: [${bash_sources[0]} line $line] - command '$command' exited with status: $err"

    if [[ "${funcstack}" == "empty" ]]
    then
        echo -e "--->"
        exit $err
    fi

    local max_idx=$((${#funcstack[@]} - 1))
    local previous_file=""
    for idx in $(seq $max_idx -1 0)
    do
        local current_file=${bash_sources[idx]}
        local display_file=""
        if [[ "${current_file}" != "${previous_file}" ]]
        then
            display_file="[${current_file}] "
        fi

        local t=${bash_linenos[$((idx - 1))]}
        if ((idx == 0))
        then
            t=$line
        else
            t="$t"
        fi

        if [[ -n "${display_file}" ]]
	then
	    echo -e "\t| ${display_file}"
	fi
	
	arrow="| "
	((idx == 0)) && arrow="V "
	echo -e  "\t${arrow}    ${funcstack[${idx}]}:$t"
        previous_file="${current_file}"
    done

    echo -e "--->"
        
    exit $err
}
