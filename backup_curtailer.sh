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
BACKUP_DIR=
# if size of BACKUP_DIR larger than BACKUP_DELETE_SIZE, delete half of files
BACKUP_DELETE_SIZE=
# prefix of backup file
BACKUP_PREFIX=

#-----------------------------
# Log Config
#-----------------------------
# directory of log files
BACKUP_LOG_DIR= ./
# number of save log file
BACKUP_LOG_CNT= 5

#-----------------------------
# EMail Config
#-----------------------------
# if you want to send error-email : 1 else 0
USE_EMAIL= 0
EMAIL_SERVER=
EMAIL_PORT=
EMAIL_TO
EMAIL_FROM=

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
# checkLogFileCnt
#=====================================
checkLogFileCnt()
{
}

#=====================================
# initLogFile
#=====================================
initLogFile()
{
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
# sendErrorMail
#=====================================
sendErrorMail()
{
    #close email message
    if [[ "${EMAIL_LOG}" -eq 1 ]] ; then
        if /sbin/esxcli network firewall get | grep "Enabled" | grep -q "true" > /dev/null 2>&1; then
            #validate firewall has email port open for ESXi 5
            if [[ "${VER}" == "5" ]] ; then
                /sbin/esxcli network firewall ruleset rule list | grep "${EMAIL_SERVER_PORT}" > /dev/null 2>&1
                if [[ $? -eq 1 ]] ; then
                    logger "info" "ERROR: Please enable firewall rule for email traffic on port ${EMAIL_SERVER_PORT}\n"
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
                "${NC_BIN}" -i "${EMAIL_DELAY_INTERVAL}" "${EMAIL_SERVER}" "${EMAIL_SERVER_PORT}" < "${EMAIL_LOG_CONTENT}" > /dev/null 2>&1
                if [[ $? -eq 1 ]] ; then
                    logger "info" "ERROR: Failed to email log output to ${EMAIL_SERVER}:${EMAIL_SERVER_PORT} to ${EMAIL_TO}\n"
                fi
            done
            unset IFS
        else
            buildHeaders ${EMAIL_TO}
            "${NC_BIN}" -i "${EMAIL_DELAY_INTERVAL}" "${EMAIL_SERVER}" "${EMAIL_SERVER_PORT}" < "${EMAIL_LOG_CONTENT}" > /dev/null 2>&1
            if [[ $? -eq 1 ]] ; then
                logger "info" "ERROR: Failed to email log output to ${EMAIL_SERVER}:${EMAIL_SERVER_PORT} to ${EMAIL_TO}\n"
            fi
        fi
    fi
}

#=====================================
# deleteBackupFiles
#=====================================




