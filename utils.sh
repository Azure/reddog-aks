check_dependencies() {
    local _DEP_FLAG _NEEDED

    # check if the dependencies are installed
    _NEEDED="az jq"
    _DEP_FLAG=false

    echo -e "Checking dependencies for the creation of the branches ...\n"
    for i in ${_NEEDED}
    do
        if hash "$i" 2>/dev/null; then
        # do nothing
            :
        else
            echo -e "\t $_ not installed".
            _DEP_FLAG=true
        fi
    done

    if [[ "${_DEP_FLAG}" == "true" ]]; then
        echo -e "\nDependencies missing. Please fix that before proceeding"
        exit 1
    fi
}