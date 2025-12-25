#!/bin/bash

# SSL Client Certificate Manager
# ======================================

CERT_DIR="/etc/nginx/ssl"
PASSWORD="1234"

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
      -subj "/C=IL/ST=Israel/L=TelAviv/O=MyCompany/CN=$USERNAME" 2>/dev/null
    
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
    
    if [ ! -f "/var/log/nginx/app-access.log" ]; then
        echo -e "${YELLOW}⚠️  Log file not found${NC}"
        return
    fi
    
    echo "Connections by user (today):"
    echo ""
    
    TODAY=$(date +%d/%b/%Y)
    grep "$TODAY" /var/log/nginx/app-access.log 2>/dev/null | \
    grep -oP 'CN=\K[^,]+' | sort | uniq -c | sort -rn | \
    while read count user; do
        echo -e "${GREEN}👤 $user:${NC} $count connections"
    done
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
        echo "6) 🚪 Exit"
        echo ""
        read -p "Choice (1-6): " CHOICE
        
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

# Run menu
main_menu
