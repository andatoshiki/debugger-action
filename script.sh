#!/bin/bash

set -eo pipefail

uriencode() {
  s="${1//'%'/%25}"
  s="${s//' '/%20}"
  s="${s//'"'/%22}"
  s="${s//'#'/%23}"
  s="${s//'$'/%24}"
  s="${s//'&'/%26}"
  s="${s//'+'/%2B}"
  s="${s//','/%2C}"
  s="${s//'/'/%2F}"
  s="${s//':'/%3A}"
  s="${s//';'/%3B}"
  s="${s//'='/%3D}"
  s="${s//'?'/%3F}"
  s="${s//'@'/%40}"
  s="${s//'['/%5B}"
  s="${s//']'/%5D}"
  printf %s "$s"
}

# For mount docker volume, do not directly use '/tmp' as the dir
TMATE_TERM="${TMATE_TERM:-screen-256color}"
TIMESTAMP="$(date +%s%3N)"
TMATE_DIR="/tmp/tmate-${TIMESTAMP}"
TMATE_SOCK="${TMATE_DIR}/session.sock"
TMATE_SESSION_NAME="tmate-${TIMESTAMP}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# Shorten this URL to avoid mask by Github Actions Runner
README_URL="https://github.com/tete1030/safe-debugger-action/blob/master/README.md"
README_URL_SHORT="$(curl -si https://git.io -F "url=${README_URL}" | tr -d '\r' | sed -En 's/^Location: (.*)/\1/p')"

cleanup() {
  if [ -n "${container_id}" ] && [ "x${docker_type}" = "ximage" ]; then
    echo "Current docker container will be saved to your image: ${TMATE_DOCKER_IMAGE_EXP}"
    docker stop -t1 "${container_id}" > /dev/null
    docker commit --message "Commit from safe-debugger-action" "${container_id}" "${TMATE_DOCKER_IMAGE_EXP}"
    docker rm -f "${container_id}" > /dev/null
  fi
  tmate -S "${TMATE_SOCK}" kill-server || true
  sed -i '/alias attach_docker/d' ~/.bashrc || true
  rm -rf "${TMATE_DIR}"
}

if [[ -n "$SKIP_DEBUGGER" ]]; then
  echo "Skipping debugger because SKIP_DEBUGGER enviroment variable is set"
  exit
fi

# Install tmate on macOS or Ubuntu
echo Setting up tmate and openssl...
if [ -x "$(command -v brew)" ]; then
  brew install tmate > /tmp/brew.log
fi
if [ -x "$(command -v apt-get)" ]; then
  "${SCRIPT_DIR}/tmate.sh"
fi

# Generate ssh key if needed
[ -e ~/.ssh/id_rsa ] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""

# Run deamonized tmate
echo Running tmate...

now_date="$(date)"
timeout=$(( ${TIMEOUT_MIN:=30}*60 ))
kill_date="$(date -d "${now_date} + ${timeout} seconds")"

TMATE_SESSION_PATH="$(pwd)"
mkdir "${TMATE_DIR}"

container_id=''
if [ -n "${TMATE_DOCKER_IMAGE}" ] || [ -n "${TMATE_DOCKER_CONTAINER}" ]; then
  if [ -n "${TMATE_DOCKER_CONTAINER}" ]; then
    docker_type="container"
    container_id="${TMATE_DOCKER_CONTAINER}"
  else
    docker_type="image"
    if [ -z "${TMATE_DOCKER_IMAGE_EXP}" ]; then
      TMATE_DOCKER_IMAGE_EXP="${TMATE_DOCKER_IMAGE}"
    fi
    echo "Creating docker container for running tmate"
    container_id=$(docker create -t "${TMATE_DOCKER_IMAGE}")
    docker start "${container_id}"
  fi
  DK_SHELL="docker exec -e TERM='${TMATE_TERM}' -it '${container_id}' /bin/bash -il"
  DOCKER_MESSAGE_CMD='printf "This window is running in Docker '"${docker_type}"'.\nTo attach to Github Actions runner, exit current shell\nor create a new tmate window by \"Ctrl-b, c\"\n(This shortcut is only available when connecting through ssh)\n\n"'
  FIRSTWIN_MESSAGE_CMD='printf "This window is now running in GitHub Actions runner.\nTo attach to your Docker '"${docker_type}"' again, use \"attach_docker\" command\n\n"'
  SECWIN_MESSAGE_CMD='printf "The first window of tmate has already been attached to your Docker '"${docker_type}"'.\nThis window is running in GitHub Actions runner.\nTo attach to your Docker '"${docker_type}"' again, use \"attach_docker\" command\n\n"'
  echo "unalias attach_docker 2>/dev/null || true ; alias attach_docker='${DK_SHELL}'" >> ~/.bashrc
  (
    cd "${TMATE_DIR}"
    TERM="${TMATE_TERM}" tmate -v -S "${TMATE_SOCK}" new-session -s "${TMATE_SESSION_NAME}" -c "${TMATE_SESSION_PATH}" -d "/bin/bash --noprofile --norc -c '${DOCKER_MESSAGE_CMD} ; ${DK_SHELL} ; ${FIRSTWIN_MESSAGE_CMD} ; /bin/bash -li'" \; set-option default-command "/bin/bash --noprofile --norc -c '${SECWIN_MESSAGE_CMD} ; /bin/bash -li'" \; set-option default-terminal "${TMATE_TERM}"
  )
else
  echo "unalias attach_docker 2>/dev/null || true" >> ~/.bashrc
  (
    cd "${TMATE_DIR}"
    TERM="${TMATE_TERM}" tmate -v -S "${TMATE_SOCK}" new-session -s "${TMATE_SESSION_NAME}" -c "${TMATE_SESSION_PATH}" -d \; set-option default-terminal "${TMATE_TERM}"
  )
fi

tmate -S "${TMATE_SOCK}" wait tmate-ready
TMATE_PID="$(tmate -S "${TMATE_SOCK}" display -p '#{pid}')"
TMATE_SERVER_LOG="${TMATE_DIR}/tmate-server-${TMATE_PID}.log"
if [ ! -f "${TMATE_SERVER_LOG}" ]; then
  echo "::error::No server log found" >&2
  echo "Files in TMATE_DIR:" >&2
  ls -l "${TMATE_DIR}"
  exit 1
fi

SSH_LINE="$(tmate -S "${TMATE_SOCK}" display -p '#{tmate_ssh}')"
WEB_LINE="$(tmate -S "${TMATE_SOCK}" display -p '#{tmate_web}')"

  MSG="SSH: ${SSH_LINE}\nWEB: ${WEB_LINE}"

  echo -e "    SSH:\e[32m ${SSH_LINE} \e[0m"
  echo -e "    Web:\e[32m ${WEB_LINE} \e[0m"

TIMEOUT_MESSAGE="If you don't connect to this session, it will be *SKIPPED* in ${timeout} seconds at ${kill_date}. To skip this step now, simply connect the ssh and exit."
echo -e "$TIMEOUT_MESSAGE"

if [[ -n "$TELEGRAM_TOKEN" ]]; then
  MSG="SSH: ${SSH_LINE}\nWEB: ${WEB_LINE}"
  echo -n "Sending information to Telegram Bot......"
  curl -k --data chat_id="${TELEGRAM_CHAT_ID}" --data "text=SSH: ${SSH_LINE}  WEB: ${WEB_LINE}" "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage"
  echo ""
fi

echo ______________________________________________________________________________________________
echo ""

# Wait for connection to close or timeout
display_int=${DISP_INTERVAL_SEC:=30}
timecounter=0

user_connected=0
while [ -S "${TMATE_SOCK}" ]; do
  connected=0
  grep -qE '^[[:digit:]\.]+ A mate has joined' "${TMATE_SERVER_LOG}" && connected=1
  if [ ${connected} -eq 1 ] && [ ${user_connected} -eq 0 ]; then
    echo "You just connected! Timeout is now disabled."
    user_connected=1
  fi
  if [ ${user_connected} -ne 1 ]; then
    if (( timecounter > timeout )); then
      echo "Waiting on tmate connection timed out! This step is skipped now."
      cleanup

      if [ "x$TIMEOUT_FAIL" = "x1" ] || [ "x$TIMEOUT_FAIL" = "xtrue" ]; then
        exit 1
      else
        exit 0
      fi
    fi
  fi

  if (( timecounter % display_int == 0 )); then
    echo "You can connect to this session in a terminal or browser"
      echo "The following are encrypted debugger connection info"
      echo -e "    SSH:\e[32m ${SSH_LINE} \e[0m"
      echo -e "    Web:\e[32m ${WEB_LINE} \e[0m"
	  
    [ "x${user_connected}" != "x1" ] && (
      echo -e "\nIf you don't connect to this session, it will be \e[31mSKIPPED\e[0m in $(( timeout-timecounter )) seconds at ${kill_date}"
      echo "To skip this step now, simply connect the ssh and exit."
    )
    echo ______________________________________________________________________________________________
  fi

  sleep 1
  timecounter=$((timecounter+1))
done

echo "The connection is terminated."
cleanup
