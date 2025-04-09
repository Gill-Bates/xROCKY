#!/bin/bash

# Version 1.0

CONFIG_FILE="/app/xray.json"
TMP_FILE="/tmp/xray_config_tmp.json"

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m' # No Color

# Functions
generate_uuid() {
    uuidgen | tr '[:upper:]' '[:lower:]' # UUID v4 in lowercase
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
    jq ".inbounds[0].settings.clients += [{\"id\": \"$id\", \"email\": \"$email\", \"flow\": \"$flow\"}]" "$CONFIG_FILE" >"$TMP_FILE" && mv -f "$TMP_FILE" "$CONFIG_FILE"
    echo -e "\n${GREEN}[OK] User successfully added:${NC}"
    echo -e "UUID: ${BLUE}$id${NC}"
    echo -e "Email: ${BLUE}$email${NC}"
    echo -e "Flow: ${BLUE}$flow${NC}"
}

list_clients_numbered() {
    local clients=$(jq -r '.inbounds[0].settings.clients | to_entries[] | "\(.key+1) | UUID: \(.value.id) | Email: \(.value.email) | Flow: \(.value.flow)"' "$CONFIG_FILE")
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
    list_clients_numbered || return

    read -p "Enter the number of the user to delete: " user_num
    local id=$(jq -r ".inbounds[0].settings.clients[$((user_num - 1))].id" "$CONFIG_FILE")

    if [ "$id" = "null" ]; then
        echo -e "${RED}Invalid user number!${NC}"
        return
    fi

    jq "del(.inbounds[0].settings.clients[$((user_num - 1))])" "$CONFIG_FILE" >"$TMP_FILE" && mv "$TMP_FILE" "$CONFIG_FILE"
    echo -e "\n${GREEN}[OK] User deleted:${NC} $id"
}

list_clients() {
    echo -e "${YELLOW}Current users:${NC}"
    jq -r '.inbounds[0].settings.clients[] | "UUID: \(.id) | Flow: \(.flow) | Email: \(.email)"' "$CONFIG_FILE"
}

edit_client() {
    list_clients_numbered || return

    read -p "Enter the number of the user to edit: " user_num
    local id=$(jq -r ".inbounds[0].settings.clients[$((user_num - 1))].id" "$CONFIG_FILE")

    if [ "$id" = "null" ]; then
        echo -e "${RED}Invalid user number!${NC}"
        return
    fi

    while true; do
        read -p "New email: " new_email
        if validate_email "$new_email"; then
            break
        else
            echo -e "${RED}Invalid email format!${NC} Please try again."
        fi
    done

    jq "(.inbounds[0].settings.clients[$((user_num - 1))].email) |= \"$new_email\"" "$CONFIG_FILE" >"$TMP_FILE" && mv "$TMP_FILE" "$CONFIG_FILE"

    echo -e "\n${GREEN}[OK] User updated:${NC} $id"
}

# Main menu
while true; do

    echo -e "${YELLOW}      ____            _          "
    echo -e "${YELLOW}__  _|  _ \ ___   ___| | ___   _ "
    echo -e "${YELLOW}\ \/ / |_) / _ \ / __| |/ / | | |"
    echo -e "${YELLOW} >  <|  _ < (_) | (__|   <| |_| |"
    echo -e "${YELLOW}/_/\_\_| \_\___/ \___|_|\_\\__, |"
    echo -e " ${YELLOW}                          |___/ "
    echo -e "     xRocky User Manager         "
    echo -e "      v1.0 by GillBates\n           "
    echo -e "${YELLOW}1.${NC} Add user (Auto-UUID)"
    echo -e "${YELLOW}2.${NC} Delete user"
    echo -e "${YELLOW}3.${NC} Edit user"
    echo -e "${YELLOW}4.${NC} List users"
    echo -e "${YELLOW}5.${NC} Exit"
    read -p "Choose an option (1-5): " choice

    case $choice in
    1) add_client ;;
    2) delete_client ;;
    3) edit_client ;;
    4) list_clients ;;
    5)
        echo -e "${GREEN}xROCKY Manager exited. Have a nice day!\n${NC}"
        exit 0
        ;;
    *) echo -e "${RED}Invalid option! Try again ...${NC}" ;;
    esac
done
