#!/bin/bash

# SSL Client Certificate Manager
# ======================================

# Configuration - will be loaded from config file or prompted
CONFIG_FILE="/etc/nginx/ssl/.cert-manager.conf"
CERT_DIR="/etc/nginx/ssl"
PASSWORD=""
ORG_NAME=""
LOG_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Header
print_header() {
    clear
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  SSL Client Certificate Manager${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Function: Load or create configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "${GREEN}✅ Configuration loaded from $CONFIG_FILE${NC}"
    else
        echo -e "${YELLOW}⚠️  No configuration file found. Let's set up the configuration.${NC}"
        echo ""

        read -p "Certificate directory [${CERT_DIR}]: " INPUT_DIR
        CERT_DIR=${INPUT_DIR:-$CERT_DIR}

        read -p "Default password for certificates [1234]: " INPUT_PASS
        PASSWORD=${INPUT_PASS:-1234}

        read -p "Organization name [MyCompany]: " INPUT_ORG
        ORG_NAME=${INPUT_ORG:-MyCompany}

        read -p "NGINX access log file [/var/log/nginx/app-access.log]: " INPUT_LOG
        LOG_FILE=${INPUT_LOG:-/var/log/nginx/app-access.log}

        # Save configuration
        cat > "$CONFIG_FILE" << EOF
CERT_DIR="$CERT_DIR"
PASSWORD="$PASSWORD"
ORG_NAME="$ORG_NAME"
LOG_FILE="$LOG_FILE"
EOF
        chmod 600 "$CONFIG_FILE"
        echo ""
        echo -e "${GREEN}✅ Configuration saved to $CONFIG_FILE${NC}"
    fi
    echo ""
}

# Function: Create Certificate
create_cert() {
    echo -e "${GREEN}🔐 Create New Certificate${NC}"
    echo ""
    read -p "Enter username: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}❌ Username cannot be empty!${NC}"
        return
    fi
    
    if [ -f "$CERT_DIR/client_${USERNAME}.crt" ]; then
        echo -e "${YELLOW}⚠️  Certificate for $USERNAME already exists!${NC}"
        read -p "Do you want to replace it? (y/n): " REPLACE
        if [ "$REPLACE" != "y" ]; then
            return
        fi
    fi
    
    cd $CERT_DIR
    
    echo -e "${BLUE}📝 Creating certificate...${NC}"
    
    # Generate key
    openssl genrsa -out client_${USERNAME}.key 2048 2>/dev/null
    
    # Create request
    openssl req -new -key client_${USERNAME}.key -out client_${USERNAME}.csr \
      -subj "/C=IL/ST=Israel/L=TelAviv/O=${ORG_NAME}/CN=$USERNAME" 2>/dev/null
    
    # Sign certificate
    openssl x509 -req -in client_${USERNAME}.csr -CA ca.crt -CAkey ca.key \
      -CAcreateserial -out client_${USERNAME}.crt -days 3650 -sha256 2>/dev/null
    
    # Create P12 file
    openssl pkcs12 -export -out client_${USERNAME}.p12 \
      -inkey client_${USERNAME}.key -in client_${USERNAME}.crt -certfile ca.crt \
      -password pass:$PASSWORD 2>/dev/null
    
    # Clean temporary files
    rm client_${USERNAME}.csr
    
    echo ""
    echo -e "${GREEN}✅ Certificate created successfully!${NC}"
    echo -e "${YELLOW}📁 File: $CERT_DIR/client_${USERNAME}.p12${NC}"
    echo -e "${YELLOW}🔑 Password: $PASSWORD${NC}"
}

# Function: Revoke Certificate
revoke_cert() {
    echo -e "${RED}🚫 Revoke Certificate${NC}"
    echo ""
    
    # Display certificate list
    echo "Available certificates to revoke:"
    echo "----------------------"
    i=1
    declare -a certs
    for cert in $CERT_DIR/client_*.crt; do
        if [ -f "$cert" ]; then
            USERNAME=$(openssl x509 -in $cert -noout -subject 2>/dev/null | grep -oP 'CN=\K[^,]+')
            echo "$i) $USERNAME"
            certs[$i]=$USERNAME
            ((i++))
        fi
    done
    
    if [ ${#certs[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No certificates to revoke${NC}"
        return
    fi
    
    echo ""
    read -p "Select number (or 0 to cancel): " CHOICE
    
    if [ "$CHOICE" -eq 0 ] 2>/dev/null; then
        return
    fi
    
    USERNAME=${certs[$CHOICE]}
    
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}❌ Invalid selection!${NC}"
        return
    fi
    
    read -p "Are you sure you want to revoke $USERNAME? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "Operation cancelled"
        return
    fi
    
    cd $CERT_DIR
    
    # Delete files
    rm -f client_${USERNAME}.key client_${USERNAME}.crt client_${USERNAME}.p12
    
    echo -e "${GREEN}✅ Certificate for $USERNAME has been revoked!${NC}"
    echo -e "${YELLOW}⚠️  $USERNAME will no longer be able to connect${NC}"
    
    # Reload NGINX
    echo -e "${BLUE}🔄 Reloading NGINX...${NC}"
    systemctl reload nginx 2>/dev/null && echo -e "${GREEN}✅ NGINX reloaded${NC}"
}

# Function: List Certificates
list_certs() {
    echo -e "${BLUE}📋 Active Certificates${NC}"
    echo "================================"
    
    cd $CERT_DIR
    COUNT=0
    
    for cert in client_*.crt; do
        if [ -f "$cert" ]; then
            USERNAME=$(openssl x509 -in $cert -noout -subject 2>/dev/null | grep -oP 'CN=\K[^,]+')
            EXPIRY=$(openssl x509 -in $cert -noout -enddate 2>/dev/null | cut -d= -f2)
            SERIAL=$(openssl x509 -in $cert -noout -serial 2>/dev/null | cut -d= -f2)
            
            echo -e "${GREEN}👤 User:${NC} $USERNAME"
            echo -e "${YELLOW}   Expires:${NC} $EXPIRY"
            echo -e "${BLUE}   Serial:${NC} $SERIAL"
            echo ""
            ((COUNT++))
        fi
    done
    
    if [ $COUNT -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No active certificates${NC}"
    else
        echo -e "${GREEN}Total: $COUNT certificates${NC}"
    fi
}

# Function: Export Certificate
export_cert() {
    echo -e "${BLUE}📤 Export Certificate${NC}"
    echo ""
    read -p "Enter username: " USERNAME
    
    if [ ! -f "$CERT_DIR/client_${USERNAME}.p12" ]; then
        echo -e "${RED}❌ Certificate for $USERNAME not found!${NC}"
        return
    fi
    
    read -p "Enter destination path (default: /tmp): " DEST
    DEST=${DEST:-/tmp}
    
    cp "$CERT_DIR/client_${USERNAME}.p12" "$DEST/client_${USERNAME}.p12"
    chmod 644 "$DEST/client_${USERNAME}.p12"
    
    echo -e "${GREEN}✅ Certificate exported successfully!${NC}"
    echo -e "${YELLOW}📁 Location: $DEST/client_${USERNAME}.p12${NC}"
    echo -e "${YELLOW}🔑 Password: $PASSWORD${NC}"
}

# Function: Connection Statistics
show_stats() {
    echo -e "${BLUE}📊 Connection Statistics${NC}"
    echo "================================"

    if [ -z "$LOG_FILE" ]; then
        read -p "Enter NGINX access log path: " LOG_FILE
    fi

    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}⚠️  Log file not found: $LOG_FILE${NC}"
        return
    fi

    echo "Log file: $LOG_FILE"
    echo ""
    echo "Connections by user (today):"
    echo ""

    TODAY=$(date +%d/%b/%Y)
    grep "$TODAY" "$LOG_FILE" 2>/dev/null | \
    grep -oP 'CN=\K[^,]+' | sort | uniq -c | sort -rn | \
    while read count user; do
        echo -e "${GREEN}👤 $user:${NC} $count connections"
    done
}

# Function: Change Settings
change_settings() {
    echo -e "${BLUE}⚙️  Change Settings${NC}"
    echo "================================"
    echo ""
    echo "Current settings:"
    echo "  1) Certificate directory: $CERT_DIR"
    echo "  2) Default password: $PASSWORD"
    echo "  3) Organization name: $ORG_NAME"
    echo "  4) Log file: $LOG_FILE"
    echo "  5) Back to menu"
    echo ""
    read -p "Select setting to change (1-5): " SETTING

    case $SETTING in
        1)
            read -p "New certificate directory [$CERT_DIR]: " NEW_DIR
            CERT_DIR=${NEW_DIR:-$CERT_DIR}
            ;;
        2)
            read -p "New default password [$PASSWORD]: " NEW_PASS
            PASSWORD=${NEW_PASS:-$PASSWORD}
            ;;
        3)
            read -p "New organization name [$ORG_NAME]: " NEW_ORG
            ORG_NAME=${NEW_ORG:-$ORG_NAME}
            ;;
        4)
            read -p "New log file path [$LOG_FILE]: " NEW_LOG
            LOG_FILE=${NEW_LOG:-$LOG_FILE}
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}❌ Invalid choice!${NC}"
            return
            ;;
    esac

    # Save updated configuration
    cat > "$CONFIG_FILE" << EOF
CERT_DIR="$CERT_DIR"
PASSWORD="$PASSWORD"
ORG_NAME="$ORG_NAME"
LOG_FILE="$LOG_FILE"
EOF
    echo -e "${GREEN}✅ Settings saved!${NC}"
}

# Main Menu
main_menu() {
    while true; do
        print_header
        echo "Select an option:"
        echo ""
        echo "1) ➕ Create new certificate"
        echo "2) 🚫 Revoke certificate"
        echo "3) 📋 List certificates"
        echo "4) 📤 Export certificate"
        echo "5) 📊 Connection statistics"
        echo "6) ⚙️  Change settings"
        echo "7) 🚪 Exit"
        echo ""
        read -p "Choice (1-7): " CHOICE
        
        echo ""
        case $CHOICE in
            1)
                create_cert
                ;;
            2)
                revoke_cert
                ;;
            3)
                list_certs
                ;;
            4)
                export_cert
                ;;
            5)
                show_stats
                ;;
            6)
                change_settings
                ;;
            7)
                echo -e "${GREEN}Goodbye! 👋${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid choice!${NC}"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run with sudo!${NC}"
    exit 1
fi

# Load configuration
print_header
load_config

# Run menu
main_menu
