#!/bin/bash

# SSL Certificate Infrastructure Setup
# =====================================
# This script creates the complete SSL infrastructure:
# - Certificate Authority (CA)
# - Server certificate
# - First client certificate
# - NGINX configuration

CERT_DIR="/etc/nginx/ssl"
NGINX_CONF="/etc/nginx/sites-available/myapp"
SERVER_IP="192.168.90.200"
SERVER_DOMAIN=""
PROXY_PORT="8088"
PROXY_TYPE="socket"
PROXY_PATH="/opt/apps/crm/fjord-login_redirect/tmp/unicorn.crm.sock"
DEFAULT_PASSWORD="1234"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function: Print header
print_header() {
    clear
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}  SSL Infrastructure Setup Wizard${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo ""
}

# Function: Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Please run with sudo!${NC}"
        exit 1
    fi
}

# Function: Check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 Checking dependencies...${NC}"

    # Check OpenSSL
    if ! command -v openssl &> /dev/null; then
        echo -e "${YELLOW}⚙️  Installing OpenSSL...${NC}"
        apt update && apt install -y openssl
    fi

    # Check NGINX
    if ! command -v nginx &> /dev/null; then
        echo -e "${YELLOW}⚙️  Installing NGINX...${NC}"
        apt update && apt install -y nginx
    fi

    echo -e "${GREEN}✅ All dependencies installed${NC}"
    echo ""
}

# Function: Gather configuration
gather_config() {
    echo -e "${YELLOW}📝 Configuration${NC}"
    echo "================================"
    echo ""

    read -p "Certificate directory [${CERT_DIR}]: " INPUT_CERT_DIR
    CERT_DIR=${INPUT_CERT_DIR:-$CERT_DIR}

    read -p "NGINX config file path [${NGINX_CONF}]: " INPUT_CONF
    NGINX_CONF=${INPUT_CONF:-$NGINX_CONF}

    read -p "Server IP address [${SERVER_IP}]: " INPUT_IP
    SERVER_IP=${INPUT_IP:-$SERVER_IP}

    read -p "Server domain name (optional, press Enter to skip): " INPUT_DOMAIN
    SERVER_DOMAIN=${INPUT_DOMAIN}

    echo ""
    echo "Proxy type:"
    echo "  1) Unix Socket"
    echo "  2) TCP Port"
    read -p "Select proxy type [1]: " PROXY_CHOICE
    PROXY_CHOICE=${PROXY_CHOICE:-1}

    if [ "$PROXY_CHOICE" == "1" ]; then
        PROXY_TYPE="socket"
    else
        PROXY_TYPE="tcp"
    fi

    # Proxy configuration based on type
    if [ "$PROXY_TYPE" == "socket" ]; then
        echo ""
        echo -e "${BLUE}Using Unix Socket for backend${NC}"
        read -p "Socket path [${PROXY_PATH}]: " INPUT_SOCKET
        PROXY_PATH=${INPUT_SOCKET:-$PROXY_PATH}
    else
        read -p "Backend proxy port [${PROXY_PORT}]: " INPUT_PORT
        PROXY_PORT=${INPUT_PORT:-$PROXY_PORT}
    fi

    read -p "Certificate password [${DEFAULT_PASSWORD}]: " INPUT_PASSWORD
    PASSWORD=${INPUT_PASSWORD:-$DEFAULT_PASSWORD}

    read -p "Organization name [MyCompany]: " INPUT_ORG
    ORG_NAME=${INPUT_ORG:-MyCompany}

    read -p "First client username [admin]: " INPUT_USER
    FIRST_CLIENT=${INPUT_USER:-admin}

    echo ""
    echo -e "${GREEN}Configuration summary:${NC}"
    echo "  Certificate Dir: $CERT_DIR"
    echo "  NGINX Config: $NGINX_CONF"
    echo "  Server IP: $SERVER_IP"
    if [ -n "$SERVER_DOMAIN" ]; then
        echo "  Server Domain: $SERVER_DOMAIN"
    else
        echo "  Server Domain: (none)"
    fi

    if [ "$PROXY_TYPE" == "socket" ]; then
        echo "  Proxy Type: Unix Socket"
        echo "  Socket Path: $PROXY_PATH"
    else
        echo "  Proxy Type: TCP"
        echo "  Proxy Port: $PROXY_PORT"
    fi

    echo "  Organization: $ORG_NAME"
    echo "  First Client: $FIRST_CLIENT"
    echo "  Password: $PASSWORD"
    echo ""

    read -p "Continue with this configuration? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "Setup cancelled"
        exit 0
    fi
    echo ""
}

# Function: Create certificate directory
create_cert_dir() {
    echo -e "${BLUE}📁 Creating certificate directory...${NC}"
    mkdir -p $CERT_DIR
    cd $CERT_DIR
    echo -e "${GREEN}✅ Directory created: $CERT_DIR${NC}"
    echo ""
}

# Function: Create CA
create_ca() {
    echo -e "${BLUE}🔐 Creating Certificate Authority (CA)...${NC}"

    # Generate CA key
    openssl genrsa -out ca.key 4096 2>/dev/null

    # Generate CA certificate
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
      -out ca.crt \
      -subj "/C=IL/ST=Israel/L=TelAviv/O=${ORG_NAME}/CN=${ORG_NAME} Root CA" 2>/dev/null

    chmod 600 ca.key
    chmod 644 ca.crt

    echo -e "${GREEN}✅ CA created successfully${NC}"
    echo ""
}

# Function: Create server certificate
create_server_cert() {
    echo -e "${BLUE}🖥️  Creating server certificate...${NC}"

    # Generate server key
    openssl genrsa -out server.key 2048 2>/dev/null

    # Determine CN (Common Name) - use domain if provided, otherwise IP
    if [ -n "$SERVER_DOMAIN" ]; then
        CERT_CN="$SERVER_DOMAIN"
    else
        CERT_CN="$SERVER_IP"
    fi

    # Create certificate request
    openssl req -new -key server.key -out server.csr \
      -subj "/C=IL/ST=Israel/L=TelAviv/O=${ORG_NAME}/CN=${CERT_CN}" 2>/dev/null

    # Create config file for SAN - include both IP and domain if provided
    if [ -n "$SERVER_DOMAIN" ]; then
        cat > san.cnf << EOF
subjectAltName=IP:${SERVER_IP},DNS:${SERVER_DOMAIN}
EOF
        echo -e "${BLUE}   SAN: IP:${SERVER_IP}, DNS:${SERVER_DOMAIN}${NC}"
    else
        cat > san.cnf << EOF
subjectAltName=IP:${SERVER_IP}
EOF
        echo -e "${BLUE}   SAN: IP:${SERVER_IP}${NC}"
    fi

    # Sign server certificate
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
      -CAcreateserial -out server.crt -days 3650 -sha256 \
      -extfile san.cnf 2>/dev/null

    # Clean up
    rm server.csr san.cnf

    chmod 600 server.key
    chmod 644 server.crt

    echo -e "${GREEN}✅ Server certificate created${NC}"
    echo ""
}

# Function: Create first client certificate
create_first_client() {
    echo -e "${BLUE}👤 Creating first client certificate...${NC}"

    USERNAME=$FIRST_CLIENT

    # Generate client key
    openssl genrsa -out client_${USERNAME}.key 2048 2>/dev/null

    # Create certificate request
    openssl req -new -key client_${USERNAME}.key -out client_${USERNAME}.csr \
      -subj "/C=IL/ST=Israel/L=TelAviv/O=${ORG_NAME}/CN=${USERNAME}" 2>/dev/null

    # Sign client certificate
    openssl x509 -req -in client_${USERNAME}.csr -CA ca.crt -CAkey ca.key \
      -CAcreateserial -out client_${USERNAME}.crt -days 3650 -sha256 2>/dev/null

    # Create P12 file
    openssl pkcs12 -export -out client_${USERNAME}.p12 \
      -inkey client_${USERNAME}.key -in client_${USERNAME}.crt -certfile ca.crt \
      -password pass:${PASSWORD} 2>/dev/null

    # Clean up
    rm client_${USERNAME}.csr

    chmod 600 client_${USERNAME}.key
    chmod 644 client_${USERNAME}.crt
    chmod 644 client_${USERNAME}.p12

    echo -e "${GREEN}✅ First client certificate created${NC}"
    echo ""
}

# Function: Configure NGINX
configure_nginx() {
    echo -e "${BLUE}⚙️  Configuring NGINX...${NC}"

    # Extract the filename from the path for dynamic symlink
    CONF_NAME=$(basename $NGINX_CONF)
    ENABLED_LINK="/etc/nginx/sites-enabled/${CONF_NAME}"

    # Backup existing config if present
    if [ -f "$NGINX_CONF" ]; then
        BACKUP_FILE="${NGINX_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
        cp $NGINX_CONF $BACKUP_FILE
        echo -e "${YELLOW}⚠️  Existing config backed up to: $BACKUP_FILE${NC}"
    fi

    # Create upstream block if using socket
    if [ "$PROXY_TYPE" == "socket" ]; then
        UPSTREAM_BLOCK="upstream backend {
    server unix:${PROXY_PATH} fail_timeout=0;
}"
        PROXY_PASS="http://backend"
    else
        UPSTREAM_BLOCK=""
        PROXY_PASS="http://127.0.0.1:${PROXY_PORT}"
    fi

    # Determine server_name directive
    if [ -n "$SERVER_DOMAIN" ]; then
        NGINX_SERVER_NAME="_ ${SERVER_DOMAIN}"
    else
        NGINX_SERVER_NAME="${SERVER_IP}"
    fi

    # Create NGINX configuration
    cat > $NGINX_CONF << EOF
${UPSTREAM_BLOCK}

server {
    listen 80;
    server_name ${NGINX_SERVER_NAME};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name ${NGINX_SERVER_NAME};

    # Hide NGINX version
    server_tokens off;

    # SSL Certificates
    ssl_certificate ${CERT_DIR}/server.crt;
    ssl_certificate_key ${CERT_DIR}/server.key;

    # Client Certificate Authentication
    ssl_client_certificate ${CERT_DIR}/ca.crt;
    ssl_verify_client on;
    ssl_verify_depth 2;

    # SSL Hardening
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    # Session settings
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL_${CONF_NAME^^}:50m;
    ssl_session_tickets off;

    # Reverse Proxy
    location / {
        proxy_pass ${PROXY_PASS};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-SSL-Client-DN \$ssl_client_s_dn;
        proxy_set_header X-SSL-Client-Verify \$ssl_client_verify;

        # Don't buffer for real-time apps
        proxy_buffering off;
        proxy_redirect off;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Logs
    access_log /var/log/nginx/${CONF_NAME}-access.log;
    error_log /var/log/nginx/${CONF_NAME}-error.log;
}
EOF

    # Create symlink if doesn't exist
    if [ ! -L "$ENABLED_LINK" ]; then
        ln -s $NGINX_CONF $ENABLED_LINK
        echo -e "${GREEN}✅ Symlink created: $ENABLED_LINK -> $NGINX_CONF${NC}"
    else
        echo -e "${YELLOW}ℹ️  Symlink already exists: $ENABLED_LINK${NC}"
    fi

    # Test NGINX configuration
    echo -e "${BLUE}🔍 Testing NGINX configuration...${NC}"
    if nginx -t 2>&1; then
        echo -e "${GREEN}✅ NGINX configuration is valid${NC}"

        # Reload NGINX
        systemctl reload nginx
        echo -e "${GREEN}✅ NGINX reloaded${NC}"
    else
        echo -e "${RED}❌ NGINX configuration error!${NC}"
        echo "Please check the configuration manually"
    fi

    echo ""
}

# Function: Print summary
print_summary() {
    CONF_NAME=$(basename $NGINX_CONF)

    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  ✅ Setup Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${YELLOW}📋 Summary:${NC}"
    echo ""
    echo -e "${BLUE}Certificate Authority:${NC}"
    echo "  Location: ${CERT_DIR}/ca.crt"
    echo ""
    echo -e "${BLUE}Server Certificate:${NC}"
    echo "  Location: ${CERT_DIR}/server.crt"
    echo "  Server IP: ${SERVER_IP}"
    if [ -n "$SERVER_DOMAIN" ]; then
        echo "  Server Domain: ${SERVER_DOMAIN}"
        echo "  SAN: IP:${SERVER_IP}, DNS:${SERVER_DOMAIN}"
    fi
    echo ""
    echo -e "${BLUE}First Client Certificate:${NC}"
    echo "  Username: ${FIRST_CLIENT}"
    echo "  File: ${CERT_DIR}/client_${FIRST_CLIENT}.p12"
    echo "  Password: ${PASSWORD}"
    echo ""
    echo -e "${BLUE}NGINX Configuration:${NC}"
    echo "  Config file: ${NGINX_CONF}"
    echo "  Enabled link: /etc/nginx/sites-enabled/${CONF_NAME}"

    if [ "$PROXY_TYPE" == "socket" ]; then
        echo "  Proxy backend: unix:${PROXY_PATH}"
    else
        echo "  Proxy backend: http://127.0.0.1:${PROXY_PORT}"
    fi
    echo ""
    echo -e "${BLUE}Access URLs:${NC}"
    echo "  https://${SERVER_IP}"
    if [ -n "$SERVER_DOMAIN" ]; then
        echo "  https://${SERVER_DOMAIN}"
    fi
    echo ""
    echo -e "${YELLOW}📝 Next Steps:${NC}"
    echo ""
    echo "1. Copy the client certificate to your computer:"
    echo "   ${CERT_DIR}/client_${FIRST_CLIENT}.p12"
    echo ""
    echo "2. Install the certificate in your browser"
    echo "   (double-click and enter password: ${PASSWORD})"
    echo ""
    if [ -n "$SERVER_DOMAIN" ]; then
        echo "3. Access the server:"
        echo "   https://${SERVER_IP} or https://${SERVER_DOMAIN}"
    else
        echo "3. Access the server: https://${SERVER_IP}"
    fi
    echo ""
    echo "4. Create additional certificates with:"
    echo "   sudo cert-manager.sh"
    echo ""
    echo -e "${GREEN}================================${NC}"
}

# Function: Install cert-manager
install_cert_manager() {
    echo -e "${BLUE}📦 Would you like to install the certificate manager?${NC}"
    read -p "Install cert-manager.sh? (y/n): " INSTALL_MGR

    if [ "$INSTALL_MGR" == "y" ]; then
        echo ""
        echo -e "${YELLOW}Please run the following command after this setup:${NC}"
        echo "  sudo nano /usr/local/bin/cert-manager.sh"
        echo "  # Paste the cert-manager.sh script"
        echo "  sudo chmod +x /usr/local/bin/cert-manager.sh"
        echo ""
    fi
}

# Main execution
main() {
    print_header
    check_root
    check_dependencies
    gather_config
    create_cert_dir
    create_ca
    create_server_cert
    create_first_client
    configure_nginx
    print_summary
    install_cert_manager
}

# Run main function
main