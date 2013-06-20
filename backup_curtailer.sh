#*************************************
# backup_curtailer.sh
# Author: Asami Hiraishi
# Created Date: 2013/06/06
#*************************************

#=====================================
# Configs
#=====================================
# Cinfiguration file
CONFIG_FILE=backup_curtailer.conf

#-----------------------------
# Backup Dir Config
#-----------------------------
# target backup directory
BACKUP_DIR=./
# if size of BACKUP_DIR larger than BACKUP_DELETE_SIZE, delete half of files
BACKUP_DELETE_SIZE=100000
# prefix of backup file
BACKUP_PREFIX=backup

#-----------------------------
# Log Config
#-----------------------------
# directory of log files
BACKUP_LOG_DIR=./
BACKUP_LOG_CNT=5

#-----------------------------
# EMail Config
#-----------------------------
# if you want to send error-email : 1 else 0
USE_EMAIL=0
EMAIL_SERVER=local
EMAIL_PORT=25
EMAIL_TO=root@local.co.jp
EMAIL_FROM=root@local.co.jp

# Log file name
LOG_OUTPUT=
# backup total size
TOTAL_SIZE=0

#=====================================
# readConfigFile
#=====================================
readConfigFile()
{
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
	fi
}

#=====================================
# dumpConfiguration
#=====================================
dumpConfiguration()
{
	outputLogFile "info" "###Config Check###"
	outputLogFile "info" "CONFIG_FILE: ${CONFIG_FILE}"
	outputLogFile "info" "BACKUP_DIR: ${BACKUP_DIR}"
	outputLogFile "info" "BACKUP_DELETE_SIZE: ${BACKUP_DELETE_SIZE}MByte"
	outputLogFile "info" "BACKUP_PREFIX: ${BACKUP_PREFIX}"

	outputLogFile "info" "BACKUP_LOG_DIR: ${BACKUP_LOG_DIR}"
	outputLogFile "info" "BACKUP_LOG_CNT: ${BACKUP_LOG_CNT}"

	outputLogFile "info" "USE_EMAIL: ${USE_EMAIL}"
	if [[ ${USE_EMAIL} -eq 1 ]]; then
		outputLogFile "info" "EMAIL_SERVER: ${EMAIL_SERVER}"
		outputLogFile "info" "EMAIL_PORT: ${EMAIL_PORT}"
		outputLogFile "info" "EMAIL_SERVER: ${EMAIL_SERVER}"
		outputLogFile "info" "EMAIL_TO: ${EMAIL_TO}"
		outputLogFile "info" "EMAIL_FROM: ${EMAIL_FROM}"
	fi
	outputLogFile "info" "###Config Check End###"

}

#=====================================
# initLogFile
#=====================================
initLogFile()
{
	# no backup directory
	if [[ -z ${BACKUP_LOG_DIR} ]]; then
		BACKUP_LOG_DIR=${WORKDIR}"/backuplog/"
		mkdir -p "${BACKUP_LOG_DIR}"
	fi
	# make log file
	LOG_OUTPUT="${BACKUP_LOG_DIR}/${BACKUP_PREFIX}-$(date +%F_%H-%M-%S)-$$.log"
	
	touch "${LOG_OUTPUT}"
	
	outputLogFile "info" "Start Log..."
	outputLogFile "info" "Log File: ${LOG_OUTPUT}"
	
	checkLogFileCnt
}

#=====================================
# checkLogFileCnt
#=====================================
checkLogFileCnt()
{
	LOG_LIST=$(ls -tr "${BACKUP_LOG_DIR}" | grep "${BACKUP_PREFIX}" )
	LOG_CNT=$(ls -1tr "${BACKUP_LOG_DIR}" | grep "${BACKUP_PREFIX}" | wc -l )
	
	DELETE_NUM=$(( ${LOG_CNT} - ${BACKUP_LOG_CNT} ))
	outputLogFile "info" "checkLogFileCnt-------------"
	for file in ${LOG_LIST}; do
		outputLogFile "info" "Check log file $file"
	done
	outputLogFile "info" "checkLogFileCnt End-------------"
	
	# delete old log files
	if [[ ${DELETE_NUM} -gt 0 ]]; then
		for file in ${LOG_LIST}; do
			outputLogFile "info" "Delete log file $file"
			rm "${BACKUP_LOG_DIR}/$file"
			DELETE_NUM=$(( ${DELETE_NUM} - 1 ))
			if [[ ${DELETE_NUM} -eq 0 ]] ; then
				break
			fi
		done
	fi
}

#=====================================
# outputLogFile
#=====================================
outputLogFile()
{
    LOG_TYPE=$1
    MSG=$2

    TIME=$(date +%F" "%H:%M:%S)

    if [[ -n "${LOG_OUTPUT}" ]] ; then
        echo -e "${TIME} -- ${LOG_TYPE}: ${MSG}" >> "${LOG_OUTPUT}"
    fi
}

#=====================================
# getTotalBackupSize
#=====================================
getTotalBackupSize()
{
	# get backups
	BACKUP_LIST=$(ls -tr "${BACKUP_DIR}" | grep "${BACKUP_PREFIX}" )
	total_size=0
	for file in ${BACKUP_LIST}; do
		#directory
		if [[ -d $file ]]; then
			add_size=$(( ls -l ${file} | awk '{ i += $5 } END{print i}' ))
			total_size=$(( $total_size + $add_size ))
		#file
		else
			add_size=`ls -l ${BACKUP_DIR}/${file} | awk '{ print $5 }'`
			total_size=$(( $total_size + $add_size))
		fi
	done
	
	# Mbyte
	TOTAL_SIZE=$(( ${total_size} / 1048576 ))
}

#=====================================
# rotateBackupSize
#=====================================
rotateBackupSize()
{
	outputLogFile "info" "backup files curtail start-----"

	getTotalBackupSize

	outputLogFile "info" "backup file total size: ${TOTAL_SIZE}MByte"
	
	DELETE_CNT=$(( ${TOTAL_SIZE} - ${BACKUP_DELETE_SIZE} ))
	
	if [[ ${DELETE_CNT} -lt 0 ]]; then
		outputLogFile "info" "didn't delete backup files"
		if [[ ${USE_EMAIL} -eq 1 ]] ; then
			USE_EMAIL=0
		fi
		return
	fi

	cnt=0
	BACKUP_LIST=$(ls -tr "${BACKUP_DIR}" | grep "${BACKUP_PREFIX}" )
	outputLogFile "info" "delete backup files"
	
	for file in ${BACKUP_LIST}; do
	
		if [[ $(( $cnt & 1 )) -eq 1 ]]; then
			outputLogFile "info" "delete backup file:${BACKUP_DIR}/$file"
			rm -rf ${BACKUP_DIR}/$file
		fi
		cnt=$(( $cnt + 1 ))
	
	done

	outputLogFile "info" "backup files curtail end-----"
	
}

#=====================================
# buildHeaders
#=====================================
buildHeaders() {
    EMAIL_ADDRESS=$1

    echo -ne "HELO $(hostname -s)\r\n" > "${EMAIL_LOG_HEADER}"
    echo -ne "MAIL FROM: <${EMAIL_FROM}>\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "RCPT TO: <${EMAIL_ADDRESS}>\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "DATA\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "From: ${EMAIL_FROM}\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "To: ${EMAIL_ADDRESS}\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "Subject: DeleteBackupFiles[${BACKUP_PREFIX}]\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "Date: $( date +"%a, %d %b %Y %T %z" )\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "Message-Id: <$( date -u +%Y%m%d%H%M%S ).$( dd if=/dev/urandom bs=6 count=1 2>/dev/null | hexdump -e '/1 "%02X"' )@$( hostname -f )>\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -en "\r\n" >> "${EMAIL_LOG_HEADER}"

    echo -en ".\r\n" >> "${LOG_OUTPUT}"
    echo -en "QUIT\r\n" >> "${LOG_OUTPUT}"
    
    cat "${EMAIL_LOG_HEADER}" > "${EMAIL_LOG_CONTENT}"
    cat "${LOG_OUTPUT}" >> "${EMAIL_LOG_CONTENT}"
}

#=====================================
# sendMail
#=====================================
sendMail()
{
	if [[ "${USE_EMAIL}" -eq 0 ]] ; then
		return
	fi
		
	#close email message
	if /sbin/esxcli network firewall get | grep "Enabled" | grep -q "true" > /dev/null 2>&1; then
		#validate firewall has email port open for ESXi 5
		/sbin/esxcli network firewall ruleset rule list | grep "${EMAIL_PORT}" > /dev/null 2>&1
		if [[ $? -eq 1 ]] ; then
			outputLogFile "error" "error: Please enable firewall rule for email traffic on port ${EMAIL_PORT}"
		fi
	fi

    if [[ -f /usr/bin/nc ]] ; then
        NC_BIN=/usr/bin/nc
    elif [[ -f /bin/nc ]] ; then
        NC_BIN=/bin/nc
    fi
    
	echo "${EMAIL_TO}" | grep "," > /dev/null 2>&1
	if [[ $? -eq 0 ]] ; then
		ORIG_IFS=${IFS}
		IFS=','
		for i in ${EMAIL_TO}; do
			buildHeaders ${i}
			"${NC_BIN}" -i "1" "${EMAIL_SERVER}" "${EMAIL_PORT}" < "${EMAIL_LOG_CONTENT}" > /dev/null 2>&1
			if [[ $? -eq 1 ]] ; then
				outputLogFile "error" "error: Failed to email log output(1)"
			fi
		done
		unset IFS
	else
		buildHeaders ${EMAIL_TO}
		"${NC_BIN}" -i "1" "${EMAIL_SERVER}" "${EMAIL_PORT}" < "${EMAIL_LOG_CONTENT}" > /dev/null 2>&1
		if [[ $? -eq 1 ]] ; then
			outputLogFile "error" "error Failed to email log output(2)"
		fi
	fi
	
	# delete email files
	rm -rf ${EMAIL_LOG_HEADER}
	rm -rf ${EMAIL_LOG_OUTPUT}
	rm -rf ${EMAIL_LOG_CONTENT}

}

#========================
# Start Script
#========================
WORKDIR=$(cd $(dirname $0);pwd)

EMAIL_LOG_HEADER=${WORKDIR}/backup_curtailer-email-$$.header
EMAIL_LOG_OUTPUT=${WORKDIR}/backup_curtailer-email-$$.log
EMAIL_LOG_CONTENT=${WORKDIR}/backup_curtailer-email-$$.content

readConfigFile
initLogFile
dumpConfiguration
rotateBackupSize
sendMail

