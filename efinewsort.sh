#!/usr/bin/bash
#------------------------------------------------------------------------------#
#  Name: efinewsort.sh
#  Date: 2022.11.01
#  Description:
#   Script for sorting the boot order in EFI 
#
#  Dependencies: 
#   bash        required, so it runs everywhere  
#   yad         required for the gui
#   efibootmgr  required 
#
#  Changes:
#	2022.11.06	VERSION=0.4	finalized README   
#	2022.11.05	VERSION=0.3	added help, final decision, cleanup   
#	2022.11.03	VERSION=0.2	added efisortbootorder file as workaround  
#	2022.11.01	VERSION=0.1	efinewboot is base 
#------------------------------------------------------------------------------#
# Primary language is English
# LANG=${LANG:=en_US.UTF-8}
# Linux REBOOT is reboot # see endYADloop
# DEBUG
# set -o errexit
# set -o nounset
# set -o pipefail ? bug in bash
# set +m
# shopt -s lastpipe
# set -x
# [[ "${TRACE-0}" == "1" ]] { set -o xtrace; }
#------------------------------------------------------------------------------#

#### latest Version for help-info 

VERSION="0.4"

# We want root ----------------------------------------------------------------#

[[ $(id -u) -ne 0 ]] && { clear; echo "We need root"; exit; }

#### let's find yad first

YAD="yad"
[[ -z `which $YAD` ]] && { clear; echo "yad is not installed: apt install yad"; exit 1; }

# let's find efibootmgr, should be in bin or sbin -----------------------------#

EFI="efibootmgr"
[[ -z `which $EFI` ]] && { clear; echo "efibootmgr is not installed: apt install efibootmgr"; }

# prepare IFS to avoid breaks by space in EFI_ARRAY based on efibootmgr -------#

IFS=$'\n'
declare -a NEW_ARRAY
declare -a EFI_ARRAY
declare -a BOA

EFI_ARRAY=(`$EFI`)

# Some cleanup first-----------------------------------------------------------#

	[[ -f ./newbootflag ]] && { `rm ./newbootflag`; }
 	[[ -f ./newbootsort ]] && { `rm ./newbootsort`; }

# Starting after main with help-info start program -h -------------------------#

help-info() {
	yad --image "dialog-question" \
        --title "Some help - Using it is simple" \
        --on-top --center --width=640 --height=480 \
		--button=OK:`exit` \
     	--list \
		--columns=2 \
		--column="*** Script must run as root ***" \
        		"Program version $VERSION
        		
bash $0 [-h]
		--help	| -h	shows this output
		
		Required: 
		EFI Boot Manager: $EFI 
		YAD Display Handler: $YAD" \
		--column="Current EFI Boot Information" \
		"`$EFI` " \
		--print-all &> /dev/null
}

# Screen User decides to boot or not ------------------------------------------#

endYAD() { 

	[[ -f ./newbootsort ]] && 
		{ BOA=`echo "$(<./newbootsort)"`; BOA=($(tr " " "," <<<${BOA})); } 
		
	yad --image "dialog-question" \
        --title "Reboot or not to reboot, that is the question" \
        --on-top --center --width=640 --height=480 \
		--button=REBOOT:1 \
        --button=CANCEL:0 \
	   	--list \
		--columns=2 \
		--column="*** Reboot Now ***" \
"Due to the great hidden wisdom 
of the EFI environment and its programmers 
a REBOOT is now required.

A reboot on your own or a regular shutdown 
may or may not work with EFI" \
		--column="Current EFI Boot Information" \
"`$EFI` " \
"Your NEW BootOrder: ${BOA}" \
		--print-all &> /dev/null
}

# user has decided ------------------------------------------------------------#

cleanup() {
	EFI="efibootmgr"
	eval $EFI -o $BOA

	[[ -f ./newbootflag ]] && { `rm ./newbootflag`; }
 	[[ -f ./newbootsort ]] && { `rm ./newbootsort`; }
}

# Read and prepares the input from Yad ----------------------------------------#
# POS(ition) UPF(lag) DOF(lag) BO(otorder) (efi)NAM(es) and only here ---------#

readYAD() { 

	IFS="|" # Required for columns out of YAD 		
	
    while read POS UPF DOF BO NAM; do
       	[[ $UPF == "TRUE" ]] && { UP_NR=$BO; UP_POS=$POS; UP_FLG=$UPF; }  
       	[[ $DOF == "TRUE" ]] && { DO_NR=$BO; DO_POS=$POS; DO_FLG=$DOF; }  
   	done  	

	[[ ! $UP_FLG && ! $DO_FLG || $UP_POS == $DO_POS ]] && { return 0; }  # User selects nothing 
	
	[[ ! $UP_FLG ]] && { UP_POS=0; }  									 # Fixing array calc 
	
	[[ $UP_FLG && ($UP_POS -lt "1") ]] && { UP_FLG="FALSE"; }			 # "Do nothing UP"
	
	[[ $DO_FLG && ($DO_POS -ge "${#BOA[@]}-1") ]] && { DO_FLG="FALSE"; } # "Do nothing DOWN"
	
	[[ "$DO_POS-$UP_POS" -eq "-1"  ]] && { DO_FLG="FALSE"; }	         # "Fixing array problem" 

   	[[ "$UP_FLG" == "TRUE" ]] && { BOA=("${BOA[@]:0:$UP_POS-1}" "$UP_NR" "${BOA[@]:$UP_POS-1}");  
								   BOA=("${BOA[@]:0:$UP_POS+1}" "${BOA[@]:$UP_POS+2}"); }	
								   
   	[[ "$DO_FLG" == "TRUE" ]] && { BOA=("${BOA[@]:0:$DO_POS+2}" "$DO_NR" "${BOA[@]:$DO_POS+2}"); 
   								   BOA=("${BOA[@]:0:$DO_POS}" "${BOA[@]:$DO_POS+1}"); } 
   						   
	echo ${BOA[@]} > newbootsort 
}

dispYAD(){ 

	yad --image "dialog-question" \
		--title "Rearange Bootorder"  \
		--on-top --center --width=640 --height=480 \
		--button="Sort":0 \
		--button="Finish":1 \
		--list \
		--columns=5 \
		--column="POS":TXT \
		--column="Sort Up":RD \
		--column="Sort Down":RD \
		--column="Boot Order" \
		--column="EFI Names" \
		--print-all
		[[ $? == 1 ]] && { `echo "end" > newbootflag`; }
}	

# Prepares the Display for Yad ------------------------------------------------#
  
setYAD() {  
	
	SBU="FALSE"; SBD="FALSE"; # Sort Boot Up and Sort Boot Down flags
	
	for (( i = 0 ; i < ${#BOA[@]}; i++ )); do 
		for (( j = 0 ; j < ${#BOA[@]}; j++ )); do
			[[ ${BOA[$i]} == ${EFI_ARRAY[$j]:0:4} ]] &&
				{ NEW_ARRAY[$i]=${EFI_ARRAY[$j]}; break; } # Sort by BootOrder
		done
	done

	unset EFI_ARRAY # old stuff deleted
	EFI_ARRAY=("${NEW_ARRAY[@]}") # Clone again to cover changes

	for (( i = 0; i < ${#BOA[@]}; i++ )); do
		NEW_NR[$i]=${NEW_ARRAY[$i]:0:4} # EFI Number
		NEW_NAM[$i]=${NEW_ARRAY[$i]:6:${#NEW_ARRAY[$i]}} # EFI Name
	done 
	
	for (( POS = 0 ; POS < ${#BOA[@]}; POS++ )); do
		echo $POS; echo $SBU; echo $SBD; echo ${NEW_NR[$POS]}; echo ${NEW_NAM[$POS]};  # Prepare YAD
	done 
} 

# Here is main - Starting the whole enchilda ----------------------------------#

: main_course

while [[ -n "${1-}" ]]; do # catch $1 unbound error
	case "$1" in
		--help|-h|-H)
			help-info; exit ;;
		--end|-e|-E)
			endYAD; exit ;;
 		*)
        	help-info; exit ;;
	esac
done

# Check BootNext to catch possible user error. if BootNext exists, ------------#
# BootOrder shifts 1 position up in array. BL (Boot Loop) starts with 4 else 3 #
# BOA (BootOrder-Array) -------------------------------------------------------#

[[ ${EFI_ARRAY[0]} = *"BootNext:"* ]] && 
	{ BOA=${EFI_ARRAY[3]}; BL=4; } || 
	{ BOA=${EFI_ARRAY[2]}; BL=3; }  

# Get the BOA array and only the values ---------------------------------------#

BOA=($(tr "," "\n" <<<${BOA:11:(${#BOA})}))

# create the boot order transport inside pipe structure -----------------------#

echo ${BOA[@]} > ./newbootsort 

# original boot order for comparison later ------------------------------------#
# OBO=${BOA[@]}
# echo ${OBO[@]} > ./oldbootorder 

# remove the first 3/4 entries BootCurrent: Timeout: BootOrder: / NextBoot: ---# 

NEW_ARRAY=("${EFI_ARRAY[@]:$BL:${#EFI_ARRAY[@]}-$BL}") 

# Clean EFI_ARRAY and delete the old version and clone it with NEW_ARRAY ------#

unset EFI_ARRAY; EFI_ARRAY=("${NEW_ARRAY[@]}") 

# Delete Boot from the strings and get only number and efi names --------------#    

for (( i = 0; i < ${#EFI_ARRAY[@]}; i++ )); do
	EFI_ARRAY[$i]=${EFI_ARRAY[$i]:4:${#EFI_ARRAY[$i]}-4}
done 

# Delete NEW_ARRAY and clone it with EFI_ARRAY to sync them -------------------#

unset NEW_ARRAY; NEW_ARRAY=("${EFI_ARRAY[@]}") 

# setYAD pipes to YAD pipes to readYAD ----------------------------------------#

while : ; do

	[[ -f ./newbootflag ]] && { `rm ./newbootflag`; }
	
	setYAD | dispYAD | readYAD 

	[[ -f ./newbootflag ]] && { endYAD; RET=$?; }
	[[ $RET == 1 ]] && { cleanup; reboot; }

	[[ -f ./newbootsort ]] && 
		{ BOA=`echo "$(<./newbootsort)"`; BOA=($(tr " " "\n" <<<${BOA})); }  # pick up the values
done
  										
exit
##########################################
# All Vars
# VERSION
# YAD Test if yad exists
# EFI efibootmgr program
# EFI_ARRAY contains all the efi stuff
# NEW_ARRAY contains copy of the efi stuff
# BL Boot Loop
# BOA Boot Order Array
