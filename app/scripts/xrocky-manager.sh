#!/bin/bash

VERSION="1.3"

CONFIG_FILE="/app/xray.json"
TMP_FILE="/tmp/xray_config_tmp.json"

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m' # No Color

#region Functions

clear_screen() {
    # More compatible way to clear the screen than "clear"
    printf "\033c"
}

generate_short_id() {
    local hex_chars=({0..9} {a..f})

    # Generate random shortId (Hexdezimal, max. 16 digits)
    local hex_id=""
    for _ in {1..16}; do
        hex_id+=${hex_chars[$((RANDOM % 16))]}
    done

    echo "$hex_id"
}

generate_uuid() {
    if command -v xray &>/dev/null; then
        xray uuid 2>/dev/null || uuidgen | tr '[:upper:]' '[:lower:]'
    else
        uuidgen | tr '[:upper:]' '[:lower:]'
    fi
}

generate_x25519_keys() {
    if command -v xray &>/dev/null; then
        xray x25519 2>/dev/null
    else
        echo -e "${RED}Error: xray command not found!${NC}" >&2
        return 1
    fi
}

validate_email() {
    local email=$1
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

    if [[ $email =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

check_config_structure() {
    local missing_fields=()

    # Check basic structure
    if ! jq -e '.inbounds' "$CONFIG_FILE" >/dev/null 2>&1; then
        missing_fields+=("inbounds array")
    fi

    if ! jq -e '.inbounds[0]' "$CONFIG_FILE" >/dev/null 2>&1; then
        missing_fields+=("first inbound configuration")
    fi

    if ! jq -e '.inbounds[0].settings' "$CONFIG_FILE" >/dev/null 2>&1; then
        missing_fields+=("inbound settings")
    fi

    if ! jq -e '.inbounds[0].streamSettings' "$CONFIG_FILE" >/dev/null 2>&1; then
        missing_fields+=("stream settings")
    fi

    if ! jq -e '.inbounds[0].streamSettings.realitySettings' "$CONFIG_FILE" >/dev/null 2>&1; then
        missing_fields+=("reality settings")
    fi

    if [ ${#missing_fields[@]} -ne 0 ]; then
        echo -e "${RED}Error: Configuration file is missing required sections:${NC}"
        for field in "${missing_fields[@]}"; do
            echo -e " - ${RED}$field${NC}"
        done
        echo -e "\n${YELLOW}Please ensure your xray.json has the correct structure before proceeding.${NC}"
        return 1
    fi

    return 0
}

check_empty_users() {
    if ! jq -e '.inbounds[0].settings.clients' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Clients configuration missing!${NC}"
        return 1
    fi

    local user_count=$(jq '.inbounds[0].settings.clients | length' "$CONFIG_FILE")
    if [ "$user_count" -eq 0 ]; then
        echo -e "${YELLOW}WARNING: No users found in the configuration!${NC}"
    fi
}

check_empty_keys() {
    # Generate keys if missing
    local private_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' "$CONFIG_FILE")
    local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' "$CONFIG_FILE")

    if [ -z "$private_key" ] || [ "$private_key" = "null" ]; then
        echo -e "${RED}Fresh Installation detected! Please wait ...${NC}\n"
        echo -e "${YELLOW}Generating new x25519 keys ...${NC}\n"
        keys=$(generate_x25519_keys)
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to generate keys!${NC}"
            return 1
        fi

        private_key=$(echo "$keys" | awk '/Private/{print $3}')
        public_key=$(echo "$keys" | awk '/Public/{print $3}')

        jq ".inbounds[0].streamSettings.realitySettings.privateKey = \"$private_key\" | .inbounds[0].streamSettings.realitySettings.publicKey = \"$public_key\"" "$CONFIG_FILE" >"$TMP_FILE" && mv -f "$TMP_FILE" "$CONFIG_FILE"

        echo -e "${GREEN}[OK] Keys generated and added to config:${NC}"
        echo -e "Private Key: ${BLUE}$private_key${NC}"
        echo -e "Public Key: ${BLUE}$public_key${NC}\n"
        read -p "Press [Enter] to continue..."
    fi

    # Generate shortId if missing or empty
    local short_ids_count=$(jq '.inbounds[0].streamSettings.realitySettings.shortIds | length' "$CONFIG_FILE")
    local first_short_id=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0] // empty' "$CONFIG_FILE")

    if [ "$short_ids_count" -eq 0 ] || [ "$short_ids_count" = "null" ] || [ -z "$first_short_id" ]; then
        echo -e "${YELLOW}Generating new shortId...${NC}"
        short_id=$(generate_short_id)
        jq ".inbounds[0].streamSettings.realitySettings.shortIds = [\"$short_id\"]" "$CONFIG_FILE" >"$TMP_FILE" && mv -f "$TMP_FILE" "$CONFIG_FILE"
        echo -e "${GREEN}[OK] ShortId generated and added to config:${NC}"
        echo -e "ShortId: ${BLUE}$short_id${NC}"
    fi
}

get_public_ip() {
    echo -e "${YELLOW}Detecting server IP addresses! Please wait ...${NC}"

    # IPv4
    local ipv4=$(curl -4 -s --max-time 3 https://ipinfo.io/ip 2>/dev/null ||
        curl -4 -s --max-time 3 https://ifconfig.me/ip 2>/dev/null ||
        echo "n/a")

    # IPv6
    local ipv6=$(curl -6 -s --max-time 3 https://ipinfo.io/ip 2>/dev/null ||
        curl -6 -s --max-time 3 https://ifconfig.me/ip 2>/dev/null ||
        echo "n/a -> is your Docker setup configured for IPv6?")

    # Return both addresses
    echo -e "${GREEN}IPv4:${NC} ${BLUE}$ipv4${NC}"
    echo -e "${GREEN}IPv6:${NC} ${BLUE}$ipv6${NC}"
}

show_client_config() {
    clear_screen
    echo -e "${YELLOW}=== Client Connection Details ===${NC}\n"

    # Get public IPs (both IPv4 and IPv6)
    get_public_ip

    # Get protocol
    local protocol=$(jq -r '.inbounds[0].protocol' "$CONFIG_FILE" 2>/dev/null)
    echo -e "\n${GREEN}Protocol:${NC}"
    echo -e "${BLUE}$protocol${NC}"

    # Get port
    local port=$(jq -r '.inbounds[0].port' "$CONFIG_FILE" 2>/dev/null)
    echo -e "\n${GREEN}Port:${NC}"
    echo -e "${BLUE}$port${NC}"

    # Get flow
    local flow=$(jq -r '.inbounds[0].settings.clients[0].flow' "$CONFIG_FILE" 2>/dev/null)
    echo -e "\n${GREEN}Flow Type:${NC}"
    echo -e "${BLUE}${flow:-"xtls-rprx-vision"}${NC}"

    # Get encryption
    local encryption=$(jq -r '.inbounds[0].settings.clients[0].encryption // "none"' "$CONFIG_FILE" 2>/dev/null)
    echo -e "\n${GREEN}Encryption:${NC}"
    echo -e "${BLUE}$encryption${NC}"

    # Get dest
    local dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest' "$CONFIG_FILE" 2>/dev/null)
    echo -e "\n${GREEN}Destination (SNI):${NC}"
    echo -e "${BLUE}$dest${NC}"

    # Get public key
    local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' "$CONFIG_FILE" 2>/dev/null)
    echo -e "\n${GREEN}Public Key:${NC}"
    echo -e "${BLUE}$public_key${NC}"

    # Get short IDs
    local short_ids=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[]?' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$short_ids" ]; then
        echo -e "\n${GREEN}Short IDs:${NC}"
        while read -r id; do
            echo -e "${BLUE}$id${NC}"
        done <<<"$short_ids"
    else
        echo -e "\n${YELLOW}No Short IDs configured${NC}"
    fi

    # Get current users
    echo -e "\n${GREEN}Available Users:${NC}"
    list_clients
    echo -e "\n${YELLOW}Note:${NC} Combine these details with the specific user UUID for the complete connection configuration."
}

add_client() {
    local id=$(generate_uuid)
    while true; do
        read -p "Email: " email
        if validate_email "$email"; then
            break
        else
            echo -e "${RED}Invalid email format!${NC} Please try again."
        fi
    done

    flow="xtls-rprx-vision"
    if jq ".inbounds[0].settings.clients += [{\"id\": \"$id\", \"email\": \"$email\", \"flow\": \"$flow\"}]" "$CONFIG_FILE" >"$TMP_FILE" 2>/dev/null && mv -f "$TMP_FILE" "$CONFIG_FILE"; then
        echo -e "\n${GREEN}[OK] User successfully added:${NC}"
        echo -e "UUID: ${BLUE}$id${NC}"
        echo -e "Email: ${BLUE}$email${NC}"
        echo -e "Flow: ${BLUE}$flow${NC}"

        # Get server config for QR code
        local ipv4=$(curl -4 -s --max-time 3 https://ipinfo.io/ip 2>/dev/null || echo "n/a")
        local port=$(jq -r '.inbounds[0].port' "$CONFIG_FILE")
        local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' "$CONFIG_FILE")
        local short_id=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' "$CONFIG_FILE")
        local dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest' "$CONFIG_FILE")

        # Generate and show QR code
        local vless_link="vless://$id@$ipv4:$port?type=tcp&security=reality&flow=$flow&pbk=$public_key&sid=$short_id&sni=$dest#${email//@/%40}"
        echo -e "\n${YELLOW}QR Code for new user:${NC}"
        echo "$vless_link" | qrencode -t ANSIUTF8
        echo -e "${GREEN}Config Link:${NC} ${BLUE}$vless_link${NC}"
    else
        echo -e "\n${RED}Error: Failed to add user!${NC}"
        return 1
    fi
}

list_clients_numbered() {
    if ! jq -e '.inbounds[0].settings.clients' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Clients configuration missing or invalid!${NC}"
        return 1
    fi

    local clients=$(jq -r '.inbounds[0].settings.clients | to_entries[] | "\(.key+1) | UUID: \(.value.id) | Email: \(.value.email) | Flow: \(.value.flow)"' "$CONFIG_FILE" 2>/dev/null)
    echo -e "${YELLOW}Existing users:${NC}"
    if [ -z "$clients" ]; then
        echo -e "${RED}No users found!${NC}"
        return 1
    else
        echo "$clients"
        return 0
    fi
}

delete_client() {
    list_clients_numbered || return 1

    read -p "Enter the number of the user to delete: " user_num
    local id=$(jq -r ".inbounds[0].settings.clients[$((user_num - 1))].id" "$CONFIG_FILE" 2>/dev/null)

    if [ -z "$id" ] || [ "$id" = "null" ]; then
        echo -e "${RED}Invalid user number!${NC}"
        return 1
    fi

    if jq "del(.inbounds[0].settings.clients[$((user_num - 1))])" "$CONFIG_FILE" >"$TMP_FILE" 2>/dev/null && mv -f "$TMP_FILE" "$CONFIG_FILE"; then
        echo -e "\n${GREEN}[OK] User deleted:${NC} $id"
    else
        echo -e "\n${RED}Error: Failed to delete user!${NC}"
        return 1
    fi
}

list_clients() {
    if ! jq -e '.inbounds[0].settings.clients' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Clients configuration missing or invalid!${NC}"
        return 1
    fi

    local clients_data
    clients_data=$(jq -c '.inbounds[0].settings.clients[]' "$CONFIG_FILE" 2>/dev/null)

    if [ -z "$clients_data" ]; then
        echo -e "${RED}No users found!${NC}"
        return 1
    fi

    # Build menu
    local client_array=()
    local count=0

    echo -e "${YELLOW}Available Clients:${NC}"
    printf "%-4s %-36s %-20s\n" "No." "UUID (short)" "Email"
    echo "---------------------------------------------------------------"

    while IFS= read -r client; do
        count=$((count + 1))
        local id email
        id=$(jq -r '.id' <<<"$client")
        email=$(jq -r '.email' <<<"$client")

        printf "%-4s %-36s %-20s\n" "$count." "${id:0:8}..." "$email"
        client_array+=("$client")
    done <<<"$clients_data"

    echo -e "\nEnter the client number to view connection details, or press Enter to cancel:"
    read -rp "> " selection

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#client_array[@]}" ]; then
        echo -e "${BLUE}Cancelled or invalid selection.${NC}"
        return
    fi

    # Get selected client
    local selected="${client_array[selection - 1]}"
    local id=$(jq -r '.id' <<<"$selected")
    local email=$(jq -r '.email' <<<"$selected")
    local flow=$(jq -r '.flow // "xtls-rprx-vision"' <<<"$selected")

    # Shared info
    local ipv4=$(curl -4 -s --max-time 3 https://ipinfo.io/ip 2>/dev/null || echo "n/a")
    local port=$(jq -r '.inbounds[0].port' "$CONFIG_FILE")
    local public_key=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' "$CONFIG_FILE")
    local short_id=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' "$CONFIG_FILE")
    local dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest' "$CONFIG_FILE")

    local vless_link="vless://$id@$ipv4:$port?type=tcp&security=reality&flow=$flow&pbk=$public_key&sid=$short_id&sni=$dest#${email//@/%40}"

    echo -e "\n${GREEN}Client:${NC} $email"
    echo -e "${GREEN}UUID:${NC} $id"
    echo -e "${GREEN}Flow:${NC} $flow"
    echo -e "${GREEN}Server IP:${NC} $ipv4"
    echo -e "${GREEN}Port:${NC} $port"
    echo -e "${GREEN}Dest/SNI:${NC} $dest"
    echo -e "${GREEN}Public Key:${NC} $public_key"
    echo -e "${GREEN}Short ID:${NC} $short_id"

    echo -e "\n${YELLOW}QR Code:${NC}"
    echo "$vless_link" | qrencode -t ANSIUTF8
    echo -e "${GREEN}Config Link:${NC} ${BLUE}$vless_link${NC}"
}

edit_client() {
    list_clients_numbered || return 1

    read -p "Enter the number of the user to edit: " user_num
    local id=$(jq -r ".inbounds[0].settings.clients[$((user_num - 1))].id" "$CONFIG_FILE" 2>/dev/null)

    if [ -z "$id" ] || [ "$id" = "null" ]; then
        echo -e "${RED}Invalid user number!${NC}"
        return 1
    fi

    while true; do
        read -p "New email: " new_email
        if validate_email "$new_email"; then
            break
        else
            echo -e "${RED}Invalid email format!${NC} Please try again."
        fi
    done

    if jq "(.inbounds[0].settings.clients[$((user_num - 1))].email) |= \"$new_email\"" "$CONFIG_FILE" >"$TMP_FILE" 2>/dev/null && mv -f "$TMP_FILE" "$CONFIG_FILE"; then
        echo -e "\n${GREEN}[OK] User updated:${NC} $id"
    else
        echo -e "\n${RED}Error: Failed to update user!${NC}"
        return 1
    fi
}

restart_xray() {
    echo -e "${YELLOW}Restarting Xray service...${NC}"

    if pgrep -x xray >/dev/null; then
        if pkill -x xray; then
            echo -e "${GREEN}Xray service restarted successfully.${NC}"
        else
            echo -e "${RED}Failed to restart Xray service!${NC}"
            return 1
        fi
    else
        echo -e "${BLUE}Xray is not running. No need to restart.${NC}"
    fi
}
#endregion

# Main execution
clear_screen

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file $CONFIG_FILE not found!${NC}"
    exit 1
fi

# Validate JSON syntax
if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    echo -e "${RED}Error: Invalid JSON in configuration file!${NC}"
    exit 1
fi

# Check config structure
if ! check_config_structure; then
    exit 1
fi

# Initial checks
check_empty_users
check_empty_keys

# Main menu
while true; do
    clear_screen
    echo -e "${YELLOW}      ____            _          "
    echo -e "${YELLOW}__  _|  _ \ ___   ___| | ___   _ "
    echo -e "${YELLOW}\ \/ / |_) / _ \ / __| |/ / | | |"
    echo -e "${YELLOW} >  <|  _ < (_) | (__|   <| |_| |"
    echo -e "${YELLOW}/_/\_\_| \_\___/ \___|_|\_\\__, |"
    echo -e " ${YELLOW}                          |___/ "
    echo -e "     xRocky User Manager         "
    echo -e "      v$VERSION by GillBates           "
    echo -e "https://github.com/Gill-Bates/xROCKY\n"
    echo -e "${YELLOW}1.${NC} Add user"
    echo -e "${YELLOW}2.${NC} Delete user"
    echo -e "${YELLOW}3.${NC} Edit user"
    echo -e "${YELLOW}4.${NC} List users (with QR codes)"
    echo -e "${YELLOW}5.${NC} Show Server config"
    echo -e "${YELLOW}6.${NC} Restart Xray service"
    echo -e "${YELLOW}7.${NC} Exit"
    read -p "Choose an option (1-7): " choice

    case $choice in
    1)
        add_client
        read -p "Press [Enter] to continue..."
        ;;
    2)
        delete_client
        read -p "Press [Enter] to continue..."
        ;;
    3)
        edit_client
        read -p "Press [Enter] to continue..."
        ;;
    4)
        list_clients
        read -p "Press [Enter] to continue..."
        ;;
    5)
        show_client_config
        read -p "Press [Enter] to continue..."
        ;;
    6)
        restart_xray
        read -p "Press [Enter] to continue..."
        ;;
    7)
        clear_screen
        echo -e "${GREEN}xROCKY Manager exited. Don't forget to restart your Docker Container after Configuration changes. Have a nice day!\n${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option! Try again ...${NC}"
        sleep 1
        ;;
    esac
done
