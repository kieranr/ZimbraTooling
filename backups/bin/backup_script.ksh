#!/usr/bin/ksh 
#
##############################################################
# DEBUG NOTES : CHANGE THE ABOVE LINE TO BE "#!/usr/bin/ksh -x" (no quotes) FOR 
# A full VERBOSE DEBUG OF EACH STEP OF THE SCRIPT.
# Don't even think of changing this shell to bash - it **WILL** BREAK.
# Bash doesn't deal with Array's of data in the same was as KSH.  SIMPLES.
##############################################################
# Version 0.07 - 15.02.2019 
# Added a function to do a remote move - where we delete the file x weeks ago locally, we want that same file to be moved on the remote end to a directory called Archived (But of course we will variable-ize it here!)
# 
#  Also created a routine to put the file at the first of the month into the Monthly directory
# 
# Version 0.06 - 12.01.2019 
# TIME parameters are still very fucked
# - Doesn't matter for the TAR - but does for the SCP
# And fixed the difference in the PRINTF For the SCP and the *ACTUAL* SCP Line
#
# Version: 0.05 - 05.01.2019
# Think I've fixed the time bit
#
# Version: 0.04 - 05.01.2019
# Verion 0.03 fouled-up the rm of the directory, and didn't exit nicely.
# The time command is still fucked  - so the scp has failed.
# 
# Version: 0.03 - 10.12.2018
# Fixing the rm, because I enumerated "date" value twice in the script
# Once at the start at 22:00 - and again once it's zipped, and copied...
# The zip and the copy take 4 hours... so the second enumeration takes place the next day - thus giving me the wrong fucking date !
# Version: 0.02 - 10.1.2017 - 
# Actually implemented the "rm -rf"
# Also added the count for number of days retention
# Really should start thinking about not running this every day - but weekly - and using the daily existing job to sync across the diff's
# i.e. the normal zextras backup routine.
# - Could I add the sync of that to this job as a "-i" called run ? (incremental?)
#
# Version: 0.02 - 10.1.2017 - 
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
		printf "Line that generated the error was ${i}\n"  2>&1 | ${LOGGY}
	fi
}

function errorcapture {
	printf "Line that generated the error was $1\n" 2>&1 | ${LOGGY}
}

function usage {
        echo "moo"

}

#######################
## The Mail functions #
#######################
#
# To get some logs to a mammil that cares... 
# </Manny, Ice Age>

################
function mailer {
echo "Mailing routine"
echo "Status is ${1}"

SENDER=kieran@kieranreynolds.co.uk
RECIPIENTS=kieran@kieranreynolds.co.uk

{
	printf  "Please find enclosed a copy of the backup log file $LOG\n\n"
	cat ${LOG}
	printf "\n\tThat's all Folks.....\n"
	} | ${MAILX} -s "Postie Mail Export ${1} - ${DSTAMP}" -A ${LOG} ${RECIPIENTS}

}



###############
# SPACE CHECK #
###############

# Make the destination direction
# And check that it exists.

function spacecheck {

USE=`df -h |grep ${EXPORTDIR} | awk '{ print $4 }' | cut -d'G' -f1`
	if [ ${USE} -lt ${MINSPACE} ]; then
		printf "Only ${USE}G Free - needs minimum of ${MINSPACE}G to complete\n" 2>&1 | ${LOGGY}
		printf "Something failed.\n" 2>&1 | ${LOGGY}
		MSTATUS=FAILED
		mailer ${MSTATUS}
			exit 2
	elif [ ${USE} -gt ${MINSPACE} ] && [ ${USE} -lt ${WARNSPACE} ]; then
		printf "Only ${USE}G Free - Today's will work, tomorrow's will fail\n" 2>&1 | ${LOGGY}
		MSTATUS=WARNING
		mailer ${MSTATUS}
		# exit 0
	fi

}

####################
# MAKE DESTINATION #
####################

# Make the destination direction
# And check that it exists.

function mkdestination {

if [ ! -d "/${EXPORTDIR}]/${DSTAMP}" ] ; then
	printf "We need to make the backup directory ... /${DESTDIR}/${DSTAMP}\n" 2>&1 | ${LOGGY}
	printf "mkdir /${EXPORTDIR}/${DSTAMP}\n" 2>&1 | ${LOGGY}
	mkdir /${EXPORTDIR}/${DSTAMP} 2>&1 | ${LOGGY}
	chmod 775 /${EXPORTDIR}/${DSTAMP} 2>&1 | ${LOGGY}
	ls -al /${EXPORTDIR}/ 2>&1 | ${LOGGY}
else
	printf "Already exists - erm - how ?\n" 2>&1 | ${LOGGY}
	ls -al /${EXPORTDIR}/
	printf "Eh ? ... /${EXPORTDIR}/${DSTAMP}\n" 2>&1 | ${LOGGY}

fi

	ls -al /${EXPORTDIR}/

}

##########
# EXPORT #
##########

# 

function doexport {

# Let's do the backup
printf "${ZXSUITE} backup doExport /${EXPORTDIR}/${DSTAMP}\n" 2>&1 | ${LOGGY}
JOBID=$( ${ZXSUITE} backup doExport /${EXPORTDIR}/${DSTAMP} | grep "monitorCommand" | awk '{ print $5}' ) 

printf "JobID for this operation is ${JOBID}\n" 2>&1 | ${LOGGY}

} 


###########
# WAITING #
###########

function dowait {
while true
do
printf  "..............\n" 2>&1 | ${LOGGY}
${ZXSUITE} backup getAllOperations | grep ${JOBID} 
if [ $? -ne 0 ] ; then
	printf "Not found - must have finished\n" 2>&1 | ${LOGGY}
	break
	else
	sleep ${SLEEPING}
		printf "Finished sleeping - checking again\n" 2>&1 | ${LOGGY}
fi
done

printf  "..............\n" 2>&1 | ${LOGGY}

}

############
# COMPRESS #
############

function docompress {
# in the case of the full backup, we take all the files and compress them
# in the case of the incremental backup, so compress all the log files.

	printf "+++++++++++\n Using Pigz to compress backup files.\n" 2>&1 | ${LOGGY}
	cd /${EXPORTDIR}/
	#${TIME} $( ${TAR} -cf - ./${DSTAMP} | ${PIGZ} > ${DSTAMP}.tar.gz ) 2>&1 | ${LOGGY}
	$( ${TAR} -cf - ./${DSTAMP} | ${PIGZ} > ${DSTAMP}.tar.gz ) 2>&1 | ${LOGGY}
	error
	printf "+++++++++++\n" 2>&1 | ${LOGGY}
}


###############
# REMOTE COPY #
###############
# As of version 0.04 - I know we need to write some more logic for checking here - but, leaving it as is for this version

function remotecopy {
# Assuming ~/.ssh/id_rsa.pub and ~/.ssh/id_rsa as ssh keys

# We need to check if the directories on the remote host exist 
# first, and if not, error and exit

	printf "-----------------\n ${SSH} -i ${HOMEPATH}/${RSA} -p2201 -o LogLevel=error ${REMOTEUSER}@${REMOTEHOST} 'ls -al /${REMOTEPATH}/'\n" 2>&1 | ${LOGGY}
	${SSH} -i ${HOMEPATH}/${RSA} -p2201 -o LogLevel=error ${REMOTEUSER}@${REMOTEHOST} "ls -al /${REMOTEPATH}/" 2>&1 | ${LOGGY}
	printf "-----------------\n" | ${LOGGY}

#error

#if [ $? -ne 0 ] ; then
#        echo "Directory ${BCKTYPE} failed...."
#        ssh ${REMOTEHOST} "mkdir -p ${REMOTEPATH}/${BCKTYPE}/"
#else
#        echo "Directory exits...."
#fi

# OK, now we have confirmed the directories exist.
# Let's move forward with syncing the data

	printf "=================\n ${SCP} -P${REMOTEPORT} -i ${HOMEPATH}/${RSA} ${DSTAMP}.tar.gz  ${REMOTEUSER}@${REMOTEHOST}:/${REMOTEPATH}/\n"  | ${LOGGY}
	#${TIME} ${SCP} -o LogLevel=Error -P${REMOTEPORT} -i ${HOMEPATH}/${RSA} ${DSTAMP}.tar.gz  ${REMOTEUSER}@${REMOTEHOST}:/${REMOTEPATH}/ 2>&1 | ${LOGGY}
	${SCP} -o LogLevel=Error -P${REMOTEPORT} -i ${HOMEPATH}/${RSA} ${DSTAMP}.tar.gz  ${REMOTEUSER}@${REMOTEHOST}:/${REMOTEPATH}/ 2>&1 | ${LOGGY}
# Version 0.04 - copied above line and removed the TIME bit until I've figured out why it's busted
# Version 0.05 - think I might have it's sorted.
# Version 0.06 - Still fucked
	#${SCP} -o LogLevel=Error -P${REMOTEPORT} -i ${HOMEPATH}/${RSA} ${DSTAMP}.tar.gz  ${REMOTEUSER}@${REMOTEHOST}:/${REMOTEPATH}/ 2>&1 | ${LOGGY}
	error ${LINENO}	
	printf "=================\n" | ${LOGGY}


}


###########
# CLEARUP #
###########
# Make this as safe as possible.

function doclearup {

# So - if either ${EXPORTDIR} or ${DSTAMP} is non-existant - fail out 

	printf "This is the clearup section\n" | ${LOGGY}
	printf "EXPORT DIR = ${EXPORTDIR}, STAMP = ${DSTAMP}\n"  | ${LOGGY}
	if [[ -z $EXPORTDIR ||  -z $DSTAMP ]] ; then
		printf "\tHmmm - variables are zerod! SHITE!\n" | ${LOGGY}
		errorcapture ${LINENO}
		(( ERROR = ERROR + 1 ))
		break 1 
	else 
		printf "\tVariables are REAL!!\n" | ${LOGGY}
		cd /${EXPORTDIR}/
		pwd | ${LOGGY}
		ls -al ${DSTAMP} | ${LOGGY}
		printf "rm -rf ${DSTAMP}\n" | ${LOGGY}
		rm -rf ${DSTAMP}
	fi

# We are also going to perform the remote move to Archive!
	printf "Moving the remote file from a ${NUMCOPIES} weeks ago to Archive..... \n" | ${LOGGY}
	printf "EXPORT DIR = ${EXPORTDIR}, ${ARCHIVEDI}, RTAMP = ${DSTAMP}, ${OLDSTAMP}\n"  | ${LOGGY}
	if [[ -z $EXPORTDIR ||  -z $OLDSTAMP || -z $ARCHIVEDIR ]] ; then
		printf "\tHmmm - variables are zerod! SHITE!\n" | ${LOGGY}
		errorcapture ${LINENO}
		(( ERROR = ERROR + 1 ))
		#exit 2
		break 1
	else 
		printf "\tVariables are REAL!!\n" | ${LOGGY}
		printf "\t${SSH} -i ${HOMEPATH}/${RSA} -p2201 -o LogLevel=error ${REMOTEUSER}@${REMOTEHOST} mv /${REMOTEPATH}/${OLDSTAMP}.tar.gz /${REMOTEPATH}/${ARCHIVEDIR}/ 2>&1 | ${LOGGY}\n"
		${SSH} -i ${HOMEPATH}/${RSA} -p2201 -o LogLevel=error ${REMOTEUSER}@${REMOTEHOST} "mv /${REMOTEPATH}/${OLDSTAMP}.tar.gz /${REMOTEPATH}/${ARCHIVEDIR}/" 2>&1 | ${LOGGY}
		cd /${EXPORTDIR}/
		pwd | ${LOGGY}
		printf "rm ${OLDSTAMP}.tar.gz\n" | ${LOGGY}
		rm  ${OLDSTAMP}.tar.gz
	fi

# We are also going to remove one from a week ago!
	printf "Removing the file from a ${NUMCOPIES} weeks ago..... \n" | ${LOGGY}
	printf "EXPORT DIR = ${EXPORTDIR}, STAMP = ${DSTAMP}, OLDSTAMP = ${OLDSTAMP}\n"  | ${LOGGY}
	if [[ -z $EXPORTDIR ||  -z $OLDSTAMP ]] ; then
		printf "\tHmmm - variables are zerod! SHITE!\n" | ${LOGGY}
		errorcapture ${LINENO}
		(( ERROR = ERROR + 1 ))
		#exit 2
		break 1
	else 
		printf "\tVariables are REAL!!\n" | ${LOGGY}
		cd /${EXPORTDIR}/
		pwd | ${LOGGY}
		printf "rm ${OLDSTAMP}.tar.gz\n" | ${LOGGY}
		rm  ${OLDSTAMP}.tar.gz
	fi


}

###################
# THE (DEAD) BODY #
#  MAIN CORPS(E)  #
###################
# Now let's declare some variables.

# Paranoia as to where binaries live.
TEE="/usr/bin/tee"
SED="/bin/sed"
GREP="/bin/grep"
TAR="/bin/tar"
#TIME='/usr/bin/time -f "\t%E real,\t%U user,\t%S sys"'
TIME="/usr/bin/time -f \"\t%E real,\t%U u^Cr,\t%S sys\""
PIGZ="/usr/bin/pigz"
SSH="/usr/bin/ssh"
SCP="/usr/bin/scp"
MAILX="/usr/bin/mailx"
ZXSUITE="/opt/zimbra/bin/zxsuite"


# VARIABLES
###################

EXPORTDIR="zexport2"
ARCHIVEDIR="Archived"
MONTHLYDIR="monthly"

# Minumum disk space required
MINSPACE=8
WARNSPACE=15

# Number of copies of backup to keep locally
# So - we work out today's date -  but 8 iterations ago (initially this will be days, but will move to weekly, so 8 weekly)- and then remove that file :-D )
NUMCOPIES=12
INTERVALS=weeks

# Let's get a Date Stamp to be able to append to the new shiny dumps.
DSTAMP=$( date +%H%M-%d-%h-%Y )
printf " date  --date= $NUMCOPIES $INTERVALS ago  +2210-%d-%h-%Y " 
OLDSTAMP=$( date  --date="$NUMCOPIES $INTERVALS ago"  +2210-%d-%h-%Y ) 
#OLDSTAMP=""

printf "${OLDSTAMP}"

# How long to sleep for
SLEEPING="300"

# REMOTEHOST  DETAILS
REMOTEHOST="endor.kairnsdata.net"
REMOTEPORT="2201"
REMOTEUSER="zimbra"
REMOTEPATH="${EXPORTDIR}"

LOGDIR="/home/zimbra-kr/backups/logs/ZEX"
HOMEPATH="/opt/zimbra"
RSA=".ssh/id_rsa"

# We need logs. 
LOG="${LOGDIR}/ZEX-${DSTAMP}.log"
#LOG="ZEX-0958-14-Nov-2017.log"
echo "LOGFILE = ${LOG}"

# Bored with "${TEE} -a >> ${LOG} every few lines....
# so.. create variable to call every time
LOGGY="${TEE} -a ${LOG} "

# Start something
	touch ${LOG}
	printf "We are starting Postie Export at ${DSTAMP}.\n" 2>&1 | ${LOGGY}

# Make the destination directory
	printf "Do we have enough disk space in the destination?.\n" 2>&1 | ${LOGGY}
	spacecheck

# Make the destination directory
	printf "Making the desintation directory.\n" 2>&1 | ${LOGGY}
	mkdestination

# Call the backup routine
	printf "Calling zxsuite backup export.\n " 2>&1 | ${LOGGY}
	doexport

# Do the monitor and wait
	printf "Monitoring and waiting.\n" 2>&1 | ${LOGGY}
	dowait
	wait

# Now compress everything
	printf "Calling Compression.\n" 2>&1 | ${LOGGY}
	docompress 
	wait

# Call the remote copy
	printf "Calling Remote copy.\n" 2>&1 | ${LOGGY}
	remotecopy 
	wait

# Remove local directory
	printf "Clearing up.\n" 2>&1 | ${LOGGY}
	doclearup 
	wait
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
