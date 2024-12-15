function run_script() {
    local url=$1
    local temp_script=$(mktemp)
    
    # Download the script
    if ! wget -q -O "$temp_script" "$url"; then
        echo -e "${RED}Failed to download script from $url${NC}"
        rm "$temp_script"
        sleep 2
        return 1
    fi
    
    # Check if the downloaded file is a valid shell script
    if head -n 1 "$temp_script" | grep -q "^#!.*sh" || file "$temp_script" | grep -q "shell script"; then
        # Execute the script
        bash "$temp_script"
        local exit_status=$?
        rm "$temp_script"
        return $exit_status
    else
        echo -e "${RED}Invalid script format or URL returned HTML instead of script${NC}"
        rm "$temp_script"
        sleep 2
        return 1
    fi
}

function ubuntu_menu() {
    while true; do
        header_info
        show_welcome
        echo -e "\nPlease select an option:"
        echo "1. Ubuntu 20.04 LTS (Focal Fossa)"
        echo "2. Ubuntu 22.04 LTS (Jammy Jellyfish)"
        echo "3. Ubuntu 24.04 LTS (Noble Numbat)"
        echo "4. Return to Main Menu"
        echo
        
        read -t 60 -p "Enter your choice (1-4): " choice
        
        if [ $? -ne 0 ]; then
            echo -e "\nNo input received. Returning to main menu..."
            exit 0
        fi

        case "$choice" in
            1)
                echo -e "${GREEN}Downloading Ubuntu 20.04 LTS installation script...${NC}"
                if ! run_script "https://osdl.sh/ubuntu-2004.sh"; then
                    echo -e "${RED}Failed to execute Ubuntu 20.04 installation script${NC}"
                    sleep 2
                    continue
                fi
                exit 0
                ;;
            2)
                echo -e "${GREEN}Downloading Ubuntu 22.04 LTS installation script...${NC}"
                if ! run_script "https://osdl.sh/ubuntu-2204.sh"; then
                    echo -e "${RED}Failed to execute Ubuntu 22.04 installation script${NC}"
                    sleep 2
                    continue
                fi
                exit 0
                ;;
            3)
                echo -e "${GREEN}Downloading Ubuntu 24.04 LTS installation script...${NC}"
                if ! run_script "https://osdl.sh/ubuntu-2404.sh"; then
                    echo -e "${RED}Failed to execute Ubuntu 24.04 installation script${NC}"
                    sleep 2
                    continue
                fi
                exit 0
                ;;
            4)
                echo -e "${GREEN}Returning to main menu...${NC}"
                if ! run_script "https://osdl.sh/test.sh"; then
                    echo -e "${RED}Failed to return to main menu${NC}"
                    sleep 2
                    exit 1
                fi
                exit 0
                ;;
            *)
                echo -e "\nInvalid option. Please try again."
                sleep 2
                continue
                ;;
        esac
    done
}