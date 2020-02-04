#!/bin/bash 

# So - lets start at a date.
# All months have a 28th day in them
# So let's iterate per month then shall we ?

#start_date=20131019 
start_date=20130530 
end_date=$(date -d "last month")
echo ${end_date}
num_months=12
#num_months=3
truth="arse"

for i in `seq 1 $num_months`
do
    mydate=$(date +%d/%m/%Y -d "${start_date}+${i} months")
	    echo $mydate # Use this however you want!



# hacking a test mydate in here to test the logic
#mydate="20/09/2013"

while true

do
echo "We begin with the truth set from either last run, at either, true, or arse:-  ${truth}"
	 zmmailbox -z -m dexterf@calibre-solutions.co.uk s -t message -l 1000  "in:inbox before:${mydate}" | head -1 
	 # What we are doing here is finding out how many mesages there are.
	 # if the condition "more": is "true", we run this purge, and run round the cirle again


# OK - we are limited to getting 1000 mails back -
# - so - if we have only 999 in the output, the value of "more" will be " false" - so we can break out, and then do a single purge.
# So let's get the value of truth:

	 truth=$( zmmailbox -z -m dexterf@calibre-solutions.co.uk s -t message -l 1000  "in:inbox before:${mydate}" | head -1 | awk -F":" '{ print $3 }' )

# If we have over 1000 mails, the value of "more" will be " true" - so this next if won't break us out.

echo "We now found out the truth - which is ${truth}"


### We should change this to " false" on the proper run
##	if [ "${truth}" = " false" ] ; then
##		echo "As the truth was false... we are purging - and breaking"
##		echo "So - we have a number of emails to process on this, the last run for this date: ${mydate}"
##		echo " Then we are Breaking out"
##
##		# The command to purge:
##			for mymsgid in $( zmmailbox -z -m dexterf@calibre-solutions.co.uk s -t message -l 1000  "in:inbox before:${mydate}" | grep -v "^num" | awk '{ print $2 }'  )
##				do  
##					echo "zmmailbox -z -m dexterf@calibre-solutions.co.uk deleteMessage ${mymsgid}"
##				 time	zmmailbox -z -m dexterf@calibre-solutions.co.uk deleteMessage ${mymsgid}
##				 done
##			break
##
##	fi
##
	# So at this point - we've checked to see if "more" was " false", i.e, we had less than 1000 mails - and that didn't fire, so that means we have over 1000 - so we need to bloody purge some...

##echo "As the truth was true ... we are purging"
##
##		# The command to purge:
##			for mymsgid in $( zmmailbox -z -m dexterf@calibre-solutions.co.uk s -t message -l 1000  "in:inbox before:${mydate}" | grep -v "^num" | awk '{ print $2 }'  )
##				do  
##					echo "zmmailbox -z -m dexterf@calibre-solutions.co.uk deleteMessage ${mymsgid}"
##				 	time zmmailbox -z -m dexterf@calibre-solutions.co.uk deleteMessage ${mymsgid}
##				 done
##
##
##	    echo "$mydate "
##	    echo "================="
##
# end of while 
 done



done
