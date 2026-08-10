#!/bin/bash
cd /home/container
sleep 1
# Make internal Docker IP address available to processes.
export INTERNAL_IP=`ip route get 1 | awk '{print $NF;exit}'`

# Update Source Server
if [ ! -z ${SRCDS_APPID} ]; then
    if [ ${SRCDS_STOP_UPDATE} -eq 0 ]; then
        STEAMCMD=""
        echo "Starting SteamCMD for AppID: ${SRCDS_APPID}"
        if [ ! -z ${SRCDS_BETAID} ]; then
            if [ ! -z ${SRCDS_BETAPASS} ]; then
                if [ ${SRCDS_VALIDATE} -eq 1 ]; then
                    echo "SteamCMD Validate Flag Enabled! Triggered install validation for AppID: ${SRCDS_APPID}"
                    echo "THIS MAY WIPE CUSTOM CONFIGURATIONS! Please stop the server if this was not intended."
                    if [ ! -z ${SRCDS_LOGIN} ]; then
                        STEAMCMD="./steamcmd/steamcmd.sh +login ${SRCDS_LOGIN} ${SRCDS_LOGIN_PASS} +force_install_dir /home/container +app_update ${SRCDS_APPID} -beta ${SRCDS_BETAID} -betapassword ${SRCDS_BETAPASS} validate +quit"
                    else
                        STEAMCMD="./steamcmd/steamcmd.sh +login anonymous +force_install_dir /home/container +app_update ${SRCDS_APPID} -beta ${SRCDS_BETAID} -betapassword ${SRCDS_BETAPASS} validate +quit"
                    fi
                else
                    if [ ! -z ${SRCDS_LOGIN} ]; then
                        STEAMCMD="./steamcmd/steamcmd.sh +login ${SRCDS_LOGIN} ${SRCDS_LOGIN_PASS} +force_install_dir /home/container +app_update ${SRCDS_APPID} -beta ${SRCDS_BETAID} -betapassword ${SRCDS_BETAPASS} +quit"
                    else
                        STEAMCMD="./steamcmd/steamcmd.sh +login anonymous +force_install_dir /home/container +app_update ${SRCDS_APPID} -beta ${SRCDS_BETAID} -betapassword ${SRCDS_BETAPASS} +quit"
                    fi
                fi
            else
                if [ ${SRCDS_VALIDATE} -eq 1 ]; then
                    if [ ! -z ${SRCDS_LOGIN} ]; then
                        STEAMCMD="./steamcmd/steamcmd.sh +login ${SRCDS_LOGIN} ${SRCDS_LOGIN_PASS} +force_install_dir /home/container +app_update ${SRCDS_APPID} -beta ${SRCDS_BETAID} validate +quit"
                    else             
                        STEAMCMD="./steamcmd/steamcmd.sh +login anonymous +force_install_dir /home/container +app_update ${SRCDS_APPID} -beta ${SRCDS_BETAID} validate +quit"
                    fi
                else
                    if [ ! -z ${SRCDS_LOGIN} ]; then
                        STEAMCMD="./steamcmd/steamcmd.sh +login ${SRCDS_LOGIN} ${SRCDS_LOGIN_PASS} +force_install_dir /home/container +app_update ${SRCDS_APPID} -beta ${SRCDS_BETAID} +quit"
                    else 
                        STEAMCMD="./steamcmd/steamcmd.sh +login anonymous +force_install_dir /home/container +app_update ${SRCDS_APPID} -beta ${SRCDS_BETAID} +quit"
                    fi
                fi
            fi
        else
            if [ ${SRCDS_VALIDATE} -eq 1 ]; then
            echo "SteamCMD Validate Flag Enabled! Triggered install validation for AppID: ${SRCDS_APPID}"
            echo "THIS MAY WIPE CUSTOM CONFIGURATIONS! Please stop the server if this was not intended."
                if [ ! -z ${SRCDS_LOGIN} ]; then
                    STEAMCMD="./steamcmd/steamcmd.sh +login ${SRCDS_LOGIN} ${SRCDS_LOGIN_PASS} +force_install_dir /home/container +app_update ${SRCDS_APPID} validate +quit"
                else
                    STEAMCMD="./steamcmd/steamcmd.sh +login anonymous +force_install_dir /home/container +app_update ${SRCDS_APPID} validate +quit"
                fi
            else
                if [ ! -z ${SRCDS_LOGIN} ]; then
                    STEAMCMD="./steamcmd/steamcmd.sh +login ${SRCDS_LOGIN} ${SRCDS_LOGIN_PASS} +force_install_dir /home/container +app_update ${SRCDS_APPID} +quit"
                else
                    STEAMCMD="./steamcmd/steamcmd.sh +login anonymous +force_install_dir /home/container +app_update ${SRCDS_APPID} +quit"
                fi
            fi
        fi

        # echo "SteamCMD Launch: ${STEAMCMD}"
        eval ${STEAMCMD}
        # Issue #44 - We can't symlink this, causes "File not found" errors. As a mitigation, copy over the updated binary on start.
        cp -f ./steamcmd/linux32/steamclient.so ./.steam/sdk32/steamclient.so
        cp -f ./steamcmd/linux64/steamclient.so ./.steam/sdk64/steamclient.so
    fi
fi

# Keep only the most recent CS2 coredump to avoid disk space being filled
CORE_DUMP_DIR="/home/container/game/bin/linuxsteamrt64"
if [ -d "${CORE_DUMP_DIR}" ]; then
    while IFS= read -r CORE_DUMP; do
        echo "Deleting old coredump: ${CORE_DUMP}"
        rm -f -- "${CORE_DUMP}"
    done < <(
        find "${CORE_DUMP_DIR}" -maxdepth 1 -type f -name 'core.*' -printf '%T@ %p\n' \
            | sort -nr \
            | awk 'NR > 1 { sub(/^[^ ]+ /, ""); print }'
    )
fi

# Preserve the previous console.log before server startup deletes it
CONSOLE_LOG_DIR="/home/container/game/csgo"
CONSOLE_LOG_FILE="${CONSOLE_LOG_DIR}/console.log"
if [ -f "${CONSOLE_LOG_FILE}" ]; then
    ROTATED_CONSOLE_LOG_FILE="${CONSOLE_LOG_DIR}/console.$(date +%Y%m%d).log"

    if [ -f "${ROTATED_CONSOLE_LOG_FILE}" ]; then
        cat "${CONSOLE_LOG_FILE}" >> "${ROTATED_CONSOLE_LOG_FILE}"
        rm -f -- "${CONSOLE_LOG_FILE}"
    else
        mv -- "${CONSOLE_LOG_FILE}" "${ROTATED_CONSOLE_LOG_FILE}"
    fi

    echo "Archived console.log to ${ROTATED_CONSOLE_LOG_FILE}"
fi

if [ -d "${CONSOLE_LOG_DIR}" ]; then
    while IFS= read -r OLD_CONSOLE_LOG; do
        echo "Deleting old console log: ${OLD_CONSOLE_LOG}"
        rm -f -- "${OLD_CONSOLE_LOG}"
    done < <(
        find "${CONSOLE_LOG_DIR}" -maxdepth 1 -type f -name 'console.*.log' -printf '%T@ %p\n' \
            | sort -nr \
            | awk 'NR > 5 { sub(/^[^ ]+ /, ""); print }'
    )
fi

# Replace Startup Variables
MODIFIED_STARTUP=`eval echo $(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')`
echo ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
if [ ${LOAD_METAMOD:-0} -eq 1 ]; then
    eval LD_PRELOAD="/home/container/game/libmetamod-loader.so" ${MODIFIED_STARTUP}
else
    eval ${MODIFIED_STARTUP}
fi