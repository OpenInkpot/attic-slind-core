# logging
#  * LOGFILE -- full pathname of a log file which will contain the full output
#               of commands executed
#  * REPORTFILE -- pathname of a file which will contain log messages

# print a log message to REPORTFILE
# $1 -- message to be printed
# $2 -- options to 'echo'
logmsg()
{
	local _msg="$1"
	local _opt="$2"

	if [ "${_opt#*n}" != "$_opt" ]; then
		_msg="`date +'%H:%M:%S'` $_msg"
	fi
	echo $_opt "$_msg" >> "$REPORTFILE"
}

# execute a command, log its output to LOGFILE and put results to REPORTFILE
# $1 -- command to be executed
# $2 -- (optional) message to REPORTFILE
logcmd()
{
	local _cmd="$1"
	local _msg="$2"

	if [ -z "$_msg" ]; then
		_msg="$_cmd"
	fi

	logmsg "$_msg... " -n
	( $_cmd 2>&1;                    \
		if [ "$?" = "0" ]; then  \
			logmsg "OK";     \
			exit 1;          \
		else                     \
			logmsg "FAILED"; \
		fi                       \
	) | tee -a "$LOGFILE"

	LASTSTATUS="$?"
}

logstart()
{
	local _logfile="$1"
	local _msg="$2"

	if [ -z "$_msg" ]; then
		_msg="Logging started at "
	fi

	REPORTFILE="$_logfile"

	echo -n "$_msg" > "$REPORTFILE"
	env LC_ALL=C date >> "$REPORTFILE"
	echo "----------" >> "$REPORTFILE"
}

logend()
{
	local _msg="$2"

	if [ -z "$_msg" ]; then
		_msg="Logging finished at "
	fi

	echo "----------" >> "$REPORTFILE"
	echo -n "$_msg" >> "$REPORTFILE"
	env LC_ALL=C date >> "$REPORTFILE"
}

