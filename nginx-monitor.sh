#!/bin/sh

# How frequently the script checks the active connections
CHECK_RATE=10
# How big of a jump should the script tolerate between 2 checks
DIFF_THRESHOLD=70
# How many active connections should the script tolerate before activating the firewall rule
TOTAL_THRESHOLD=900
# Log the output to file
project_root=$(dirname "$(realpath "$0")")
LOG="$project_root/monitor.log"

# Cloudflare needed variables
API_KEY=""
ZONE_ID=""
RULE_DESC=""

# Turns on a rule based on its description
turnRuleOn() {
    newBody=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/firewall/rules" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type:application/json" | jq ".result[] | select(.description == \"$RULE_DESC\") | .paused = false")

    response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/firewall/rules" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        --data "[$newBody]" | jq '.success')
    echo "    - Success: $response"
    [ -n "$LOG" ] && echo "    - Success: $response" >> "$LOG"
}

# Turns off a rule based on its description
turnRuleOff() {
    newBody=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/firewall/rules" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type:application/json" | jq ".result[] | select(.description == \"$RULE_DESC\") | .paused = true")

    response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/firewall/rules" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        --data "[$newBody]" | jq '.success')
    echo "    - Success: $response"
    [ -n "$LOG" ] && echo "    - Success: $response" >> "$LOG"
}

checkDependencies() {
    mainShellPID="$$"
    printf "curl\njq\nawk" | while IFS= read -r program; do
        if ! [ -x "$(command -v "$program")" ]; then
            echo "Error: $program is not installed." >&2
            kill -9 "$mainShellPID" 
        fi
    done
}

checkDependencies


# If zone id or rule id are empty exit
if [ -z "$ZONE_ID" ] || [ -z "$RULE_DESC" ] ||  [ -z "$API_KEY" ]; then
    echo "[Error]: ZONE_ID, RULE_DESC or API_KEY is empty!" >&2 
    [ -n "$LOG" ] && echo "[Error]: ZONE_ID, RULE_DESC or API_KEY is empty!" >> "$LOG"
    exit 1
fi

# Check if the api key is valid
isKeyValid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type:application/json" | jq '.result.status' --raw-output)

if [ ! "$isKeyValid" = "active" ]; then
    echo "[Error]: API key is invalid!" >&2
    [ -n "$LOG" ] && echo "[Error]: API key is invalid!" >> "$LOG"
    exit 1
fi


isRulePaused=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/firewall/rules" \
     -H "Authorization: Bearer $API_KEY" \
     -H "Content-Type:application/json" | jq ".result[] | select(.description == \"$RULE_DESC\") | .paused" --raw-output)

prevConnections=0 currConnections=0 
while true; do
    currConnections=$(curl -s 127.0.0.1/nginx_status | awk 'NR==1{print $3; exit}')
    timestamp=$(date +"%F %T")
    echo "[$timestamp] Active connections: $currConnections"
    [ -n "$LOG" ] && echo "[$timestamp] Active connections: $currConnections" >> "$LOG"
    echo "    - Rule $RULE_DESC paused: $isRulePaused"
    [ -n "$LOG" ] && echo "    - Rule $RULE_DESC paused: $isRulePaused" >> "$LOG"

    # check difference between previous and current active connections
    if [ $((currConnections - prevConnections)) -gt $DIFF_THRESHOLD ]; then
        echo "    - DIFF_THRESHOLD ($DIFF_THRESHOLD) exceeded!"
        [ -n "$LOG" ] && echo "    - DIFF_THRESHOLD ($DIFF_THRESHOLD) exceeded!" >> "$LOG"
        # check if the rule is enabled if not enable it
        if [ "$isRulePaused" = "true" ]; then
            echo "    - Turning on the rule"
            [ -n "$LOG" ] && echo "    - Turning on the rule" >> "$LOG"
            turnRuleOn
            isRulePaused=false
        fi

    elif [ "$currConnections" -gt $TOTAL_THRESHOLD ];then
        echo "    - TOTAL_THRESHOLD ($TOTAL_THRESHOLD) exceeded!"
        [ -n "$LOG" ] && echo "    - TOTAL_THRESHOLD ($TOTAL_THRESHOLD) exceeded!" >> "$LOG"
        # check if the rule is enabled if not enable it
        if [ "$isRulePaused" = "true" ]; then
            echo "    - Turning on the rule"
            [ -n "$LOG" ] && echo "    - Turning on the rule" >> "$LOG"
            turnRuleOn
            isRulePaused=false
        fi

    else
        # if the rule is on turn it off
        if [ "$isRulePaused" = "false" ]; then
            echo "    - Turning off the rule, traffic is under the treshold."
            [ -n "$LOG" ] && echo "    - Turning off the rule, traffic is under the treshold." >> "$LOG"
            turnRuleOff
            isRulePaused=true
        fi
    fi

    prevConnections=$currConnections
    sleep "$CHECK_RATE"
done