#
# Various utility functions for Slind's shell scripts.
#
# 
# The logic of configuration file processing is the following: 
# All of the "common" sections in config files are loaded in the environment of
# the script, into the same variable names, uppercase:
# That is, "debian_mirror" from [common] of slind-config.ini becomes
# DEBIAN_MIRROR in the environment of a script that sources libutils.sh.
# This is done by the function load_common_config().
# 
# For scripts to parse their own sections of the configuration file, utility
# function conf_get_var() is provided by this "library".

SLIND_DEF_CONFIG=/etc/slind/slind-config.ini
SLIND_SUITES_DEF_CONFIG=/etc/slind/slind-suites.ini
SLIND_USR_CONFIG=~/.slind/slind-config.ini
SLIND_USR_SUITES_CONFIG=~/.slind/slind-suites.ini

# We default to local files.
SLIND_CONFIG=$SLIND_USR_CONFIG
SLIND_SUITES_CONFIG=$SLIND_USR_SUITES_CONFIG

load_slind_config_common() {
    # This function loads in the current namespace all variables from
    # slind-config.ini, section [common].
    local _output

    if [ ! -f "$SLIND_CONFIG" ]; then
	if [ -f "$SLIND_DEF_CONFIG" ]; then
	    SLIND_CONFIG=$SLIND_DEF_CONFIG
	else
	    yell "ERROR: Cannot open configuration file, slind-config.ini"
	    exit 1
	fi
    fi

    # Source everything common
    eval `pget SECTION=common PARAM=.* JOINC=1 DEBLANK=1 PRINT=3 $SLIND_CONFIG | awk -F=\" '{ print toupper(\$1) FS \$2 }'`
}

load_slind_config_maintainer_common() {
    # This function loads in the current namespace all variables from
    # slind-config.ini, section [maintainer-common].
    local _output

    if [ ! -f "$SLIND_CONFIG" ]; then
	if [ -f "$SLIND_DEF_CONFIG" ]; then
	    SLIND_CONFIG=$SLIND_DEF_CONFIG
	else
	    yell "ERROR: Cannot open configuration file, slind-config.ini"
	    exit 1
	fi
    fi

    # Source everything common
    eval `pget SECTION=maintainer-common PARAM=.* JOINC=1 DEBLANK=1 PRINT=3 $SLIND_CONFIG | awk -F=\" '{ print toupper(\$1) FS \$2 }'`
}

load_suites_config() {
    # This function load in the current namespace all variables from
    # slind-config.ini. 
    # Arguments:
    #	$1 -- current suite
    #	      If this parameter is passed, we check if any of the variables are
    #	      overriden in section [<current suite>], and use values from there.
    #

    if [ ! -f $SLIND_SUITES_CONFIG ]; then
	if [ -f $SLIND_SUITES_DEF_CONFIG ]; then
	    SLIND_SUITES_CONFIG=$SLIND_SUITES_DEF_CONFIG
	else
	    yell "ERROR: Cannot open configuration file, slind-suites.ini"
	    exit 1
	fi
    fi
    
    # Source everything common
    eval `pget SECTION=common PARAM=.* JOINC=1 DEBLANK=1 PRINT=3 $SLIND_SUITES_CONFIG | awk -F=\" '{print toupper(\$1) FS \$2 }'`

    [ -n "$1" ] && {
	# Source per-suite variables 
	eval `pget SECTION=$1 PARAM=.* JOINC=1 DEBLANK=1 PRINT=3 $SLIND_SUITES_CONFIG | awk -F=\" '{ print toupper($1) FS $2 }'` 
    }
}


conf_get_var_strict() {
    # Get the value of the variable from the config file.
    # This function is strict, that is, if the parameter is missing, it produces
    # an error message.

    # Arguments:
    #	    $1 -- config file
    #	    $2 -- section name
    #	    $3 -- parameter name
    local _file=$1
    local _section=$2
    local _param=$3
    local _value

    _value=`pget SECTION=$_section PARAM=$_param JOINC=1 $_file`

    [ -n "$_value" ] || {
	yell "ERROR: $_param is not set in section $_section of $_file."
    }
    echo $_value
}

conf_get_var_relaxed() {
    # Get the value of the variable from the config file.
    # This function is relaxed, that is, if the parameter is missing, it
    # falls back to default with a warning message.

    # Arguments:
    #	    $1 -- config file
    #	    $2 -- section name
    #	    $3 -- parameter name
    #	    $4 -- default
    local _file=$1
    local _section=$2
    local _param=$3
    local _default=$4
    local _value

    _value=`pget SECTION=$_section PARAM=$_param JOINC=1 $_file`

    [ -n "$_value" ] || {
	yell "WARNING: $_param is not set in section $_section of $_file, falling back to $_default"
	_value=$_default
    }
    echo $_value
}

yell() {
    echo $1
}

