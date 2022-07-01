#!/usr/bin/with-contenv bashio

###
## FUNCTIONS
###

## updateSetup
function addon::setup.update()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local c="${1:-}"
  local e="${2:-}"
  local update
  local path="/config/setup.json"

  old="$(jq -r '.'"${e}"'?' ${path})"
  new=$(jq -r '.'"${c}"'?' "/data/options.json")

  if [ "${new:-null}" != 'null' ] &&  [ "${old:-}" != "${new:-}" ]; then
    jq -c '.timestamp="'$(date -u '+%FT%TZ')'"|.'"${e}"'="'"${new}"'"' /config/setup.json > /tmp/setup.json.$$ && mv -f /tmp/setup.json.$$ /config/setup.json
    bashio::log.info "Updated ${e}: ${new}; old: ${old}"
    update=1
  else
    bashio::log.debug "${FUNCNAME[0]} no change ${e}: ${old}; new: ${new}"
  fi
  echo ${update:-0}
}

## reload
function addon::reload()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  if [ $(bashio::config 'reload') != 'false' ] && [ -e /config/setup.json ]; then
    local update=0
    local date='null'
    local i=2
    local old
    local new
    local tf

    while true; do
      bashio::log.notice "Option 'reload' is true; querying for ${i} seconds at ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}"
      local config=$(curl -sSL -m ${i} ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}/cgi-bin/config 2> /dev/null || true)

      config=$(echo "${config}" | jq '.config?')
      if [ "${config:-null}" != 'null' ]; then

        # check configuration (timezone, latitude, longitude, mqtt, group, device, client)
        if [ -e /config/setup.json ]; then
          # ww3
          tf=$(addon::setup.update 'w3w.apikey' 'MOTION_W3W_APIKEY') && update=$((update+tf))
          tf=$(addon::setup.update 'w3w.words' 'MOTION_W3W_WORDS') && update=$((update+tf))
          # router
          tf=$(addon::setup.update 'router_name' 'MOTION_ROUTER_NAME') && update=$((update+tf))
          # host
          tf=$(addon::setup.update 'interface' 'HOST_INTERFACE') && update=$((update+tf))
          tf=$(addon::setup.update 'ipaddr' 'HOST_IPADDR') && update=$((update+tf))
          tf=$(addon::setup.update 'timezone' 'HOST_TIMEZONE') && update=$((update+tf))
          tf=$(addon::setup.update 'latitude' 'HOST_LATITUDE') && update=$((update+tf))
          tf=$(addon::setup.update 'longitude' 'HOST_LONGITUDE') && update=$((update+tf))
          # mqtt
          tf=$(addon::setup.update 'mqtt.host' 'MQTT_HOST') && update=$((update+tf))
          tf=$(addon::setup.update 'mqtt.password' 'MQTT_PASSWORD') && update=$((update+tf))
          tf=$(addon::setup.update 'mqtt.port' 'MQTT_PORT') && update=$((update+tf))
          tf=$(addon::setup.update 'mqtt.username' 'MQTT_USERNAME') && update=$((update+tf))
          # motion
          tf=$(addon::setup.update 'group' 'MOTION_GROUP') && update=$((update+tf))
          tf=$(addon::setup.update 'device' 'MOTION_DEVICE') && update=$((update+tf))
          tf=$(addon::setup.update 'client' 'MOTION_CLIENT') && update=$((update+tf))
          # overview
          tf=$(addon::setup.update 'overview.apikey' 'MOTION_OVERVIEW_APIKEY') && update=$((update+tf))
          tf=$(addon::setup.update 'overview.image' 'MOTION_OVERVIEW_IMAGE') && update=$((update+tf))
          tf=$(addon::setup.update 'overview.mode' 'MOTION_OVERVIEW_MODE') && update=$((update+tf))
          tf=$(addon::setup.update 'overview.zoom' 'MOTION_OVERVIEW_ZOOM') && update=$((update+tf))
          # USER
          tf=$(addon::setup.update 'person.user' 'MOTION_USER') && update=$((update+tf))
        fi

        # test if update
        if [ ${update:-0} -gt 0 ]; then
          bashio::log.notice "Updated settings"
        else
          bashio::log.notice "No updates"
        fi
        break
      fi

      # no config; try again
      sleep ${i}
      i=$((i+i))
      if [ ${i:-0} -gt 30 ]; then
        # up to a limit
        bashio::log.error "Automatic reload failed waiting on Apache; use Terminal and run 'make restart'"
        break
      fi
    done
  elif [ ! -e /config/setup.json ]; then
    bashio::log.notice "Did not find /config/setup.json"
  else 
    bashio::log.info "Reload off"
  fi
}


## start the apache server

# FOREGROUND (does not return)
start_apache_foreground()
{
  start_apache true ${*}
}

# BACKGROUND (returns)
start_apache_background()
{
  start_apache false ${*}
}

start_apache()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local foreground=${1}; shift

  local conf=${1}
  local host=${2}
  local port=${3}
  local admin="${4:-root@${host}}"
  local tokens="${5:-}"
  local signature="${6:-}"

  # edit defaults
  sed -i 's|^Listen .*|Listen '${port}'|' "${conf}"
  sed -i 's|^ServerName .*|ServerName '"${host}:${port}"'|' "${conf}"
  sed -i 's|^ServerAdmin .*|ServerAdmin '"${admin}"'|' "${conf}"

  # SSL
  if [ ! -z "${tokens:-}" ]; then
    sed -i 's|^ServerTokens.*|ServerTokens '"${tokens}"'|' "${conf}"
  fi
  if [ ! -z "${signature:-}" ]; then
    sed -i 's|^ServerSignature.*|ServerSignature '"${signature}"'|' "${conf}"
  fi

  # enable CGI
  sed -i 's|^\([^#]\)#LoadModule cgi|\1LoadModule cgi|' "${conf}"

  # export environment
  export MOTION_SHARE_DIR=$(motion.config.share_dir)

  # pass environment
  echo 'PassEnv MOTION_SHARE_DIR' >> "${conf}"

  # make /run/apache2 for PID file
  mkdir -p /run/apache2

  # start HTTP daemon
  bashio::log.debug "Starting Apache: ${conf} ${host} ${port}"

  if [ "${foreground:-false}" = 'true' ]; then
    httpd -E ${MOTION_LOGTO} -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
  else
    httpd -E ${MOTION_LOGTO} -e debug -f "${MOTION_APACHE_CONF}"
  fi
}

## mqtt
process_config_mqtt()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local result=
  local value
  local json

  # local json server (hassio addon)
  value=$(echo "${config}" | jq -r ".host")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value="core-mosquitto"; fi
  bashio::log.info "Using MQTT host: ${value}"
  json='{"host":"'"${value}"'"'

  # username
  value=$(echo "${config}" | jq -r ".username")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  bashio::log.info "Using MQTT username: ${value}"
  json="${json}"',"username":"'"${value}"'"'

  # password
  value=$(echo "${config}" | jq -r ".password")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  bashio::log.info "Using MQTT password: ${value}"
  json="${json}"',"password":"'"${value}"'"'

  # port
  value=$(echo "${config}" | jq -r ".port")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=1883; fi
  bashio::log.info "Using MQTT port: ${value}"
  json="${json}"',"port":'"${value}"'}'

  echo "${json:-null}"
}

###
### MAIN
###

## INITIATE LOGGING
export MOTION_LOG_LEVEL="${1:-debug}"
export MOTION_LOGTO=${MOTION_LOGTO:-/tmp/motion.log}

## SOURCE TOOLS
source ${USRBIN:-/usr/bin}/motion-tools.sh

## APACHE
if [ ! -s "${MOTION_APACHE_CONF}" ]; then
  bashio::log.error "Missing Apache configuration"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  bashio::log.error "Missing Apache ServerName"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  bashio::log.error "Missing Apache ServerAdmin"
  exit 1
fi
if [ -z "${MOTION_APACHE_HTDOCS:-}" ]; then
  bashio::log.error "Missing Apache HTML documents directory"
  exit 1
fi

## add-on API
ipaddr=$(ip addr | egrep -A4 UP | egrep 'inet ' | egrep -v 'scope host lo' | egrep -v 'scope global docker' | awk '{ print $2 }')
ipaddr=${ipaddr%%/*}
ADDON_API="http://${ipaddr}:${MOTION_APACHE_PORT}"

## initialize configutation (JSON)
JSON='{"version":"'"${BUILD_VERSION:-}"'","config_path":"'"${CONFIG_PATH}"'","ipaddr":"'${ipaddr}'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)

## options

# device name
VALUE=$(jq -r ".device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE="$(hostname -s)"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
bashio::log.info "MOTION_DEVICE: ${VALUE}"
MOTION_DEVICE="${VALUE}"

# device group
VALUE=$(jq -r ".group" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE="motion"
fi
JSON="${JSON}"',"group":"'"${VALUE}"'"'
bashio::log.info "MOTION_GROUP: ${VALUE}"
MOTION_GROUP="${VALUE}"

# client
VALUE=$(jq -r ".client" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE="+"
fi
JSON="${JSON}"',"client":"'"${VALUE}"'"'
bashio::log.info "MOTION_CLIENT: ${VALUE}"
MOTION_CLIENT="${VALUE}"

## time zone
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE="GMT"
else
  bashio::log.info "TIMEZONE: ${VALUE}"
fi
if [ -s "/usr/share/zoneinfo/${VALUE}" ]; then
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime
  echo "${VALUE}" > /etc/timezone
else
  bashio::log.error "No known timezone: ${VALUE}"
fi
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

# set unit_system for events
VALUE=$(jq -r '.unit_system' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
bashio::log.debug "Set unit_system to ${VALUE}"
JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'

# set latitude for events
VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
bashio::log.debug "Set latitude to ${VALUE}"
JSON="${JSON}"',"latitude":'"${VALUE}"

# set longitude for events
VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
bashio::log.debug "Set longitude to ${VALUE}"
JSON="${JSON}"',"longitude":'"${VALUE}"

# set elevation for events
VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
bashio::log.debug "Set elevation to ${VALUE}"
JSON="${JSON}"',"elevation":'"${VALUE}"

## MQTT
# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
bashio::log.info "Using MQTT at ${VALUE}"
MQTT='{"host":"'"${VALUE}"'"'
# username
VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
bashio::log.info "Using MQTT username: ${VALUE}"
MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
# password
VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
bashio::log.info "Using MQTT password: ${VALUE}"
MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
# port
VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
bashio::log.info "Using MQTT port: ${VALUE}"
MQTT="${MQTT}"',"port":'"${VALUE}"'}'
# finish
JSON="${JSON}"',"mqtt":'"${MQTT}"

## W3W
# local W3W server (hassio addon)
VALUE=$(jq -r ".w3w.words" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="w3w"; fi
bashio::log.info "Using W3W at ${VALUE}"
W3W='{"words":"'"${VALUE}"'"'
# apikey
VALUE=$(jq -r ".w3w.apikey" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
bashio::log.info "Using W3W apikey: ${VALUE}"
W3W="${W3W}"',"apikey":"'"${VALUE}"'"}'
# finish
JSON="${JSON}"',"w3w":'"${W3W}"

## ADD-ON configuration
MOTION='{'

# set log_type (FIRST ENTRY)
VALUE=$(jq -r ".log_addon_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="ALL"; fi
sed -i "s|^log_type .*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"'"log_type":"'"${VALUE}"'"'
bashio::log.debug "Set motion.log_type to ${VALUE}"

# set log_level
VALUE=$(jq -r ".log_addon_level" "${CONFIG_PATH}")
case ${VALUE} in
  emergency)
    VALUE=1
    ;;
  alert)
    VALUE=2
    ;;
  critical)
    VALUE=3
    ;;
  error)
    VALUE=4
    ;;
  warn)
    VALUE=5
    ;;
  info)
    VALUE=7
    ;;
  debug)
    VALUE=8
    ;;
  all)
    VALUE=9
    ;;
  *|notice)
    VALUE=6
    ;;
esac
sed -i "s/^log_level .*/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"
bashio::log.debug "Set motion.log_level to ${VALUE}"

# set log_file
VALUE=$(jq -r ".log_file" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/tmp/motion.log"; fi
sed -i "s|^log_file .*|log_file ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_file":"'"${VALUE}"'"'
bashio::log.debug "Set log_file to ${VALUE}"
export MOTION_LOGTO=${VALUE}

# shared directory for results (not images and JSON)
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/${MOTION_GROUP}"; fi
MOTION="${MOTION}"',"share_dir":"'"${VALUE}"'"'
bashio::log.debug "Set share_dir to ${VALUE}"
export MOTION_SHARE_DIR="${VALUE}"

# set username and password
USERNAME=$(jq -r ".username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".password" "${CONFIG_PATH}")
MOTION="${MOTION}"',"username":"'"${USERNAME}"'"'
MOTION="${MOTION}"',"password":"'"${PASSWORD}"'"'

## end motion structure; cameras section depends on well-formed JSON for $MOTION
MOTION="${MOTION}"'}'
bashio::log.debug "MOTION: ${MOTION}"

JSON="${JSON}"',"motion":'"${MOTION}"'}'


###
## validate JSON
###

echo "${JSON}" | jq -c '.' > "$(motion.config.file)"
if [ ! -s "$(motion.config.file)" ]; then
  bashio::log.error "INVALID CONFIGURATION; metadata: ${JSON}"
  exit 1
fi
bashio::log.debug "CONFIGURATION; file: $(motion.config.file); metadata: $(jq -c '.' $(motion.config.file))"

###
# start Apache
###

# make the options available to the apache client
chmod go+rx /data /data/options.json
start_apache_background ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}
bashio::log.notice "Started Apache on ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}"

## reload Home Assistant iff requested and necessary
addon::reload

if [ ! -d /share/motion-ai ]; then
  bashio::log.info "Cloning /share/motion-ai"
  git clone http://github.com/motion-ai/motion-ai /share/motion-ai &> /dev/null
else
  pushd /share/motion-ai &> /dev/null
  bashio::log.info "Pulling /share/motion-ai"
  git pull &> /dev/null
  popd &> /dev/null
fi

if [ ! -d /share/ageathome ]; then
  bashio::log.info "Cloning /share/ageathome"
  git clone http://github.com/ageathome/core /share/ageathome &> /dev/null
fi

if [ -d /share/ageathome ]; then
  pushd /share/ageathome &> /dev/null
  if [ ! -e motion-ai ] && [ -d /share/motion-ai ]; then
    bashio::log.info "Linking /share/motion-ai"
    ln -s /share/motion-ai .
  elif [ ! -d /share/motion-ai ]; then
    bashio::log.error "Could not link to /share/motion-ai"
  fi
  bashio::log.info "Pulling /share/ageathome"
  git pull &> /dev/null
  popd &> /dev/null
else
  bashio::log.error "Cannot find /share/ageathome"
fi

if [ -d /share/ageathome ] && [ ! -e /config/setup.json ]; then
  bashio::log.info "Initializing /share/ageathome"
  pushd /share/ageathome &> /dev/null
  make homeassistant/setup.json &> /dev/null && mv homeassistant/setup.json /config
  popd &> /dev/null
fi

if [ -d /share/ageathome ] && [ -d /share/motion-ai ] && [ -e /config/setup.json ]; then
  bashio::log.info "Updating /config from /share/ageathome/homeassistant"
  pushd /share/ageathome/homeassistant &> /dev/null
  tar chf - . | ( cd /config ; tar xf - )
  popd &> /dev/null
  bashio::log.info "Making /config"
  pushd /config &> /dev/null
  MOTION_APP="Age@Home" HOST_IPADDR="${ipaddr}" PACKAGES="" make &> /dev/null
  popd &> /dev/null
else
  bashio::log.error "Cannot find /config/setup.json"
fi

## fork process to on-board devices and set CoIoT for motion sensors
# implement this code

## forever
while true; do

    ## publish configuration
    ( motion.mqtt.pub -r -q 2 -t "$(motion.config.group)/$(motion.config.device)/start" -f "$(motion.config.file)" &> /dev/null \
      && bashio::log.info "Published configuration to MQTT; topic: $(motion.config.group)/$(motion.config.device)/start" ) \
      || bashio::log.notice "Failed to publish configuration to MQTT; config: $(motion.config.mqtt)"

    ## sleep
    bashio::log.info "Sleeping; ${MOTION_WATCHDOG_INTERVAL:-1800} seconds ..."
    sleep ${MOTION_WATCHDOG_INTERVAL:-1800}

done
