#!/usr/bin/ksh 
#
##############################################################
# DEBUG NOTES : CHANGE THE ABOVE LINE TO BE "#!/usr/bin/ksh -x" (no quotes) FOR 
# A full VERBOSE DEBUG OF EACH STEP OF THE SCRIPT.
# Don't even think of changing this shell to bash - it **WILL** BREAK.
##############################################################
# Version: 0.02 - 05.01.2019
# Time command is still broken - very broken
#
# Version: 0.01 - 04.12.2017 - 
# - Initial creation 
#
# CHANGELOG:
#


# Need to specify this Variable soooo early on in the script... damn.
ERROR=0

# A little function called regularly in the script to determine if something has
# broken - and if so increment a variable by 1 for each failure.
################

function error {
	if [ $? -ne 0 ] ; then
		(( ERROR = ERROR + 1 ))
	else
		ERROR=${ERROR}
	fi
}

#######################
## The Mail functions #
#######################
#
# To get some logs to a mammil that cares... 
# </Manny, Ice Age>

function mailer {
echo "Mailing routine"
echo "Status is ${1}"

SENDER=kieran@kieranreynolds.co.uk
RECIPIENTS=kieran@kieranreynolds.co.uk

{
	printf  "Please find enclosed a copy of the rsync log file $LOG\n\n"
	cat ${LOG}
	printf "\n\tThat's all Folks.....\n"
	} | ${MAILX} -s "Postie Mail Rsync ${SOURCEDIR} ....  ${1} - ${DSTAMP}" -A ${LOG} ${RECIPIENTS}

}

###############
# SPACE CHECK #
###############

function remotediskcheck {

USE=`${SSH} -p${REMOTEPORT} -o LogLevel=error ${REMOTEUSER}@${REMOTEHOST} "df -h ${DESTDIR}/" |grep -v Filesystem | awk '{ print $4 }' | cut -d'G' -f1`
	printf "Remote disk space - ${DESTDIR} is ${USE}GB"
	if [ ${USE} -lt ${MINSPACE} ]; then
		printf "Only ${USE}G Free - needs minimum of ${MINSPACE}G to complete\n" 2>&1 | ${LOGGY}
		printf "Something failed.\n" 2>&1 | ${LOGGY}
		MSTATUS=FAILED
		mailer ${MSTATUS}
			exit 2
	elif [ ${USE} -gt ${MINSPACE} ] && [ ${USE} -lt ${WARNSPACE} ]; then
		printf "Only ${USE}G Free - Today's will work, tomorrow's will fail\n" 2>&1 | ${LOGGY}
		MSTATUS=WARNING
#		mailer ${MSTATUS}
		#	exit 0
	fi

}

###############
# REMOTE COPY #
###############

function remotecopy {
# Assuming ~/.ssh/id_rsa.pub and ~/.ssh/id_rsa as ssh keys

# We need to check if the directories on the remote host exist 
# first, and if not, error and exit

	printf "-----------------\n ${SSH} -i ${HOMEPATH}/${RSA} -p2201 -o LogLevel=error ${REMOTEUSER}@${REMOTEHOST} 'ls -al /${DESTDIR}/'\n" 2>&1 | ${LOGGY}
	${SSH} -i ${HOMEPATH}/${RSA} -p2201 -o LogLevel=error ${REMOTEUSER}@${REMOTEHOST} "ls -al /${DESTDIR}/" 2>&1 | ${LOGGY}

#error


	printf "=================\n ${RSYNC} --progress --stats -e \"ssh -o LogLevel=error -p${REMOTEPORT}\" ${SOURCEDIR} ${REMOTEUSER}@${REMOTEHOST}:/${DESTDIR}/\n\n"  | ${LOGGY}
	#printf " ${RSYNC} -a --delete --stats -h -e "ssh -o LogLevel=error -p${REMOTEPORT}" ${SOURCEDIR} ${REMOTEUSER}@${REMOTEHOST}:/${DESTDIR}/ 2>&1 | ${LOGGY}"
	#${TIME} ${RSYNC} -a --delete --stats -h -e "ssh -o LogLevel=error -p${REMOTEPORT}" ${SOURCEDIR} ${REMOTEUSER}@${REMOTEHOST}:/${DESTDIR}/ 2>&1 | ${LOGGY}
	${RSYNC} -a --delete --stats -h -e "ssh -o LogLevel=error -p${REMOTEPORT}" ${SOURCEDIR} ${REMOTEUSER}@${REMOTEHOST}:/${DESTDIR}/ 2>&1 | ${LOGGY}
	printf "=================\n" | ${LOGGY}

	error	

}


###################
# THE (DEAD) BODY #
#  MAIN CORPS(E)  #
###################
# Now let's declare some variables.
# Let's get a Date Stamp to be able to append to the new shiny dumps.
DSTAMP=$( date +%H%M-%d-%h-%Y )


# Paranoia as to where binaries live.
TEE="/usr/bin/tee"
SED="/bin/sed"
GREP="/bin/grep"
#TIME="/usr/bin/time -f "\t%E real,\t%U user,\t%S sys""
#TIME="/usr/bin/time -f \" \t%E real,\t%U user,\t%S sys \" "
#time -f "\t%E real,\t%U ^Cer,\t%S sys" ls -Fsk
SSH="/usr/bin/ssh"
SCP="/usr/bin/scp"
RSYNC="/usr/bin/rsync"
MAILX="/usr/bin/mailx"


# VARIABLES
###################

SOURCEDIR="/mail_backup/zextras/"
DESTDIR="/mail_backup/zextras/"

# Minumum disk space required
MINSPACE=5.5
WARNSPACE=6

# REMOTEHOST  DETAILS
REMOTEHOST="endor.kairnsdata.net"
REMOTEPORT="2201"
REMOTEUSER="zimbra"
REMOTEPATH="${EXPORTDIR}"

LOGDIR="/home/zimbra-kr/backups/logs/RSYNC"
HOMEPATH="/opt/zimbra"
RSA=".ssh/id_rsa"

# We need logs. 
LOG="${LOGDIR}/RSYNC-ZEX-${DSTAMP}.log"
#LOG="RSYNC-ZEX-0958-14-Nov-2017.log"
echo "LOGFILE = ${LOG}"

# Bored with "${TEE} -a >> ${LOG} every few lines....
# so.. create variable to call every time
LOGGY="${TEE} -a ${LOG} "

# Start something
	touch ${LOG}
	printf "We are starting Postie Mail Rsync - ${SOURCEDIR}  at ${DSTAMP}.\n" 2>&1 | ${LOGGY}

# Check disk space on remote server 
	printf "Checking remote disk space...\n" 2>&1 | ${LOGGY}
	remotediskcheck
	error

# Call the remote copy
	printf "Calling Remote copy.\n" 2>&1 | ${LOGGY}
	remotecopy 

# END of the main stuff


# Error checking ..
if [ ${ERROR} -gt 0 ] ; then
	printf "Something failed.\n" 2>&1 | ${LOGGY}
	MSTATUS=FAILED
else
	printf "Something didn't fail.\n" 2>&1 | ${LOGGY}
	MSTATUS=OK
fi
mailer ${MSTATUS}

# END of the STIFF (Dead body - aka CORPS(E) )
