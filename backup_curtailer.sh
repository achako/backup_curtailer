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
# number of save log file
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

#=====================================
# readConfigFile
#=====================================
readConfigFile()
{
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
    else
    	# error log
    	outputLogFile "error" ""
    fi
}

#=====================================
# dumpConfiguration
#=====================================
dumpConfiguration()
{
	echo "CONFIG_FILE: ${CONFIG_FILE}"
	echo "BACKUP_DIR: ${BACKUP_DIR}"
	echo "BACKUP_DELETE_SIZE: ${BACKUP_DELETE_SIZE}"
	echo "BACKUP_PREFIX: ${BACKUP_PREFIX}"
}

#=====================================
# checkLogFileCnt
#=====================================
checkLogFileCnt()
{
	LOG_LIST=$(ls -t "${BACKUP_LOG_DIR}" | grep "backup" * )

}

#=====================================
# initLogFile
#=====================================
initLogFile()
{
	echo "initLogFile()"
}

#=====================================
# outputLogFile
#=====================================
outputLogFile()
{
    LOG_TYPE=$1
    MSG=$2

    if [[ "${LOG_LEVEL}" == "debug" ]] && [[ "${LOG_TYPE}" == "debug" ]] || [[ "${LOG_TYPE}" == "info" ]] || [[ "${LOG_TYPE}" == "dryrun" ]]; then
        TIME=$(date +%F" "%H:%M:%S)
        if [[ "${LOG_TO_STDOUT}" -eq 1 ]] ; then
            echo -e "${TIME} -- ${LOG_TYPE}: ${MSG}"
        fi

        if [[ -n "${LOG_OUTPUT}" ]] ; then
            echo -e "${TIME} -- ${LOG_TYPE}: ${MSG}" >> "${LOG_OUTPUT}"
        fi

        if [[ "${EMAIL_LOG}" -eq 1 ]] ; then
            echo -ne "${TIME} -- ${LOG_TYPE}: ${MSG}\r\n" >> "${EMAIL_LOG_OUTPUT}"      
        fi
    fi
}

#=====================================
# getTotalBackupSize
#=====================================
getTotalBackupSize()
{
	# get backups
	BACKUP_LIST=$(ls -t "${BACKUP_DIR}" | grep "${BACKUP_PREFIX}" * )
	TOTAL_SIZE=0
	for file in ${BACKUP_LIST}; do
		#directory
		if [[test $file -d]] == 0; then
			TOTAL_SIZE += [[ du -s $file ]]
		#file
		else
			TOTAL_SIZE += [[ wc -c < $files ]]
		fi
	done
}

#=====================================
# rotateBackupSize
#=====================================
rotateBackupSize()
{
	getTotalBackupSize
	
	if [[ $TOTAL_SIZE > BACKUP_DELETE_SIZE ]]; then
		cnt = 0
		for file in ${BACKUP_LIST}; do
			if[[ cnt -eq 1 ]]; then
				result = test $file -d
				if [[ result -eq 0 ]]; then
					rm -rf "$BACKUP_DIR_PATH/$file"
				else
					rm -f "$BACKUP_DIR_PATH/$file"
				fi
			fi
			cnt += 1
		done
	fi

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
    echo -ne "Subject: ghettoVCB - $(hostname -s) ${FINAL_STATUS}\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "Date: $( date +"%a, %d %b %Y %T %z" )\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "Message-Id: <$( date -u +%Y%m%d%H%M%S ).$( dd if=/dev/urandom bs=6 count=1 2>/dev/null | hexdump -e '/1 "%02X"' )@$( hostname -f )>\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "XMailer: ghettoVCB ${VERSION_STRING}\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -en "\r\n" >> "${EMAIL_LOG_HEADER}"

    echo -en ".\r\n" >> "${EMAIL_LOG_OUTPUT}"
    echo -en "QUIT\r\n" >> "${EMAIL_LOG_OUTPUT}"

    cat "${EMAIL_LOG_HEADER}" > "${EMAIL_LOG_CONTENT}"
    cat "${EMAIL_LOG_OUTPUT}" >> "${EMAIL_LOG_CONTENT}"
}

#=====================================
# sendErrorMail
#=====================================
sendErrorMail()
{
    #close email message
    if [[ "${USE_EMAIL}" -eq 1 ]] ; then
        if /sbin/esxcli network firewall get | grep "Enabled" | grep -q "true" > /dev/null 2>&1; then
            #validate firewall has email port open for ESXi 5
            if [[ "${VER}" == "5" ]] ; then
                /sbin/esxcli network firewall ruleset rule list | grep "${EMAIL_PORT}" > /dev/null 2>&1
                if [[ $? -eq 1 ]] ; then
                    logger "info" "ERROR: Please enable firewall rule for email traffic on port ${EMAIL_PORT}\n"
                    logger "info" "Please refer to ghettoVCB documentation for ESXi 5 firewall configuration\n"
                fi
            fi
        fi

        echo "${EMAIL_TO}" | grep "," > /dev/null 2>&1
        if [[ $? -eq 0 ]] ; then
            ORIG_IFS=${IFS}
            IFS=','
            for i in ${EMAIL_TO}; do
                buildHeaders ${i}
                "${NC_BIN}" -i "${EMAIL_DELAY_INTERVAL}" "${EMAIL_SERVER}" "${EMAIL_PORT}" < "${EMAIL_LOG_CONTENT}" > /dev/null 2>&1
                if [[ $? -eq 1 ]] ; then
                    logger "info" "ERROR: Failed to email log output to ${EMAIL_SERVER}:${EMAIL_PORT} to ${EMAIL_TO}\n"
                fi
            done
            unset IFS
        else
            buildHeaders ${EMAIL_TO}
            "${NC_BIN}" -i "${EMAIL_DELAY_INTERVAL}" "${EMAIL_SERVER}" "${EMAIL_PORT}" < "${EMAIL_LOG_CONTENT}" > /dev/null 2>&1
            if [[ $? -eq 1 ]] ; then
                logger "info" "ERROR: Failed to email log output to ${EMAIL_SERVER}:${EMAIL_PORT} to ${EMAIL_TO}\n"
            fi
        fi
    fi
}

#========================
# Start Script
#========================

readConfigFile
dumpConfiguration
