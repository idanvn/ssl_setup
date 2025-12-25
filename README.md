# SSL Client Certificate Authentication System

A complete solution for implementing mutual TLS (mTLS) authentication on NGINX with easy certificate management.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Certificate Management](#certificate-management)
- [Client Setup](#client-setup)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [File Structure](#file-structure)
- [FAQ](#faq)

---

## 🔍 Overview

This system implements **mutual TLS (mTLS) authentication** for web applications running behind NGINX. Only clients with valid SSL certificates can access the server, providing an additional security layer beyond traditional username/password authentication.

### What is mTLS?

Mutual TLS authentication requires both the server and client to authenticate each other using SSL certificates:
- **Server → Client**: Server proves its identity (standard HTTPS)
- **Client → Server**: Client proves its identity (mTLS enhancement)

---

## ✨ Features

- ✅ **Complete SSL Infrastructure Setup** - Automated CA, server, and client certificate generation
- ✅ **Easy Certificate Management** - Interactive menu for creating, revoking, and listing certificates
- ✅ **NGINX Integration** - Automatic reverse proxy configuration
- ✅ **Connection Tracking** - Monitor which users are connecting
- ✅ **Certificate Export** - Easy distribution of client certificates
- ✅ **Security Hardening** - TLS 1.2/1.3 only, strong ciphers, server token hiding
- ✅ **User-Friendly** - Color-coded terminal interface

---

## 🏗️ Architecture
```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Client    │         │    NGINX     │         │   Backend   │
│  (Browser)  │◄───────►│  + mTLS      │◄───────►│    App      │
│ + SSL Cert  │  HTTPS  │   (443)      │  HTTP   │  (8088)     │
└─────────────┘         └──────────────┘         └─────────────┘
      ▲                        ▲
      │                        │
      │                        │
      └────────────────────────┘
         Client Certificate
            Verification
```

### Components

1. **Certificate Authority (CA)** - Signs all certificates
2. **Server Certificate** - Installed on NGINX
3. **Client Certificates** - Distributed to authorized users
4. **NGINX Reverse Proxy** - Enforces authentication
5. **Management Scripts** - Automate certificate operations

---

## 📦 Requirements

### Server Requirements

- **OS**: Ubuntu 24.04 LTS (or similar)
- **Software**:
  - NGINX 1.24.0+
  - OpenSSL 3.0+
  - Bash 5.0+

### Client Requirements

- Modern web browser (Chrome, Firefox, Edge, Safari)
- Ability to install client certificates

---

## 🚀 Installation

### Step 1: Download Scripts
```bash
# Download setup script
sudo wget -O /usr/local/bin/ssl-setup.sh https://your-repo/ssl-setup.sh
sudo chmod +x /usr/local/bin/ssl-setup.sh

# Download certificate manager
sudo wget -O /usr/local/bin/cert-manager.sh https://your-repo/cert-manager.sh
sudo chmod +x /usr/local/bin/cert-manager.sh
```

### Step 2: Run Initial Setup
```bash
sudo ssl-setup.sh
```

The setup wizard will ask for:
- **Server IP address** (default: 192.168.90.200)
- **Backend proxy port** (default: 8088)
- **Organization name** (default: MyCompany)
- **Certificate password** (default: 1234)
- **First admin username** (default: admin)

### Step 3: Verify Installation
```bash
# Check NGINX status
sudo systemctl status nginx

# Verify certificates were created
ls -la /etc/nginx/ssl/

# Test NGINX configuration
sudo nginx -t
```

---

## 💻 Usage

### Managing Certificates

Launch the certificate manager:
```bash
sudo cert-manager.sh
```

### Menu Options
```
================================
  SSL Client Certificate Manager
================================

Select an option:

1) ➕ Create new certificate
2) 🚫 Revoke certificate
3) 📋 List certificates
4) 📤 Export certificate
5) 📊 Connection statistics
6) 🚪 Exit
```

---

## 🔐 Certificate Management

### Creating a New Certificate

1. Run: `sudo cert-manager.sh`
2. Select option `1`
3. Enter username (e.g., `john.doe`)
4. Certificate is created at: `/etc/nginx/ssl/client_john.doe.p12`

**Command Line Alternative:**
```bash
cd /etc/nginx/ssl
sudo openssl genrsa -out client_john.key 2048
sudo openssl req -new -key client_john.key -out client_john.csr \
  -subj "/C=IL/ST=Israel/L=TelAviv/O=MyCompany/CN=john.doe"
sudo openssl x509 -req -in client_john.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out client_john.crt -days 3650 -sha256
sudo openssl pkcs12 -export -out client_john.p12 \
  -inkey client_john.key -in client_john.crt -certfile ca.crt \
  -password pass:1234
rm client_john.csr
```

### Revoking a Certificate

1. Run: `sudo cert-manager.sh`
2. Select option `2`
3. Choose certificate from list
4. Confirm revocation
5. NGINX automatically reloads

**Manual Revocation:**
```bash
sudo rm /etc/nginx/ssl/client_username.*
sudo systemctl reload nginx
```

### Listing Active Certificates
```bash
sudo cert-manager.sh
# Select option 3
```

**Manual Listing:**
```bash
cd /etc/nginx/ssl
for cert in client_*.crt; do
  openssl x509 -in $cert -noout -subject -enddate
done
```

### Exporting Certificates

1. Run: `sudo cert-manager.sh`
2. Select option `4`
3. Enter username
4. Specify destination path (default: `/tmp`)
5. Transfer file to client machine

---

## 👥 Client Setup

### Windows

1. **Copy** the `.p12` file to your Windows machine
2. **Double-click** the file
3. Click **"Current User"** → Next
4. Next (path is auto-filled)
5. Enter password (default: `1234`)
6. **"Automatically select"** → Next
7. Finish
8. **Close browser completely**
9. **Reopen browser**
10. Navigate to `https://your-server-ip`
11. **Select certificate** when prompted

### Chrome/Edge

Settings → Privacy and Security → Security → Manage Certificates → Personal → Import → Select `.p12` → Enter password

### Firefox

Settings → Privacy & Security → View Certificates → Your Certificates → Import → Select `.p12` → Enter password

### macOS

1. Double-click `.p12` file
2. Add to **Keychain**
3. Enter password
4. Restart browser

### Linux
```bash
# Import to system
pk12util -i client_username.p12 -d sql:$HOME/.pki/nssdb

# For Firefox
pk12util -i client_username.p12 -d ~/.mozilla/firefox/*.default
```

---

## 🔒 Security Considerations

### Best Practices

1. **Protect CA Private Key**
```bash
   sudo chmod 600 /etc/nginx/ssl/ca.key
   sudo chown root:root /etc/nginx/ssl/ca.key
```

2. **Use Strong Passwords**
   - Change default certificate password
   - Edit `PASSWORD` variable in scripts

3. **Regular Certificate Rotation**
   - Revoke and reissue certificates annually
   - Use shorter validity periods for high-security environments

4. **Monitor Access Logs**
```bash
   sudo tail -f /var/log/nginx/app-access.log
```

5. **Backup Critical Files**
```bash
   sudo tar -czf ssl-backup-$(date +%Y%m%d).tar.gz /etc/nginx/ssl/
```

### What to Backup

- ✅ `/etc/nginx/ssl/ca.key` - CA private key (CRITICAL!)
- ✅ `/etc/nginx/ssl/ca.crt` - CA certificate
- ✅ `/etc/nginx/sites-available/myapp` - NGINX config
- ⚠️ Do NOT backup: client `.p12` files (redistribute as needed)

### Firewall Configuration
```bash
# Allow HTTPS only
sudo ufw allow 443/tcp
sudo ufw deny 80/tcp  # Optional: block HTTP
sudo ufw enable
```

---

## 🐛 Troubleshooting

### Issue: "400 Bad Request - No required SSL certificate"

**Cause:** Client certificate not installed or not selected

**Solution:**
1. Verify certificate is installed in browser
2. Close and reopen browser
3. When prompted, select the certificate
4. Clear browser cache/cookies

### Issue: Certificate not appearing in browser

**Cause:** Certificate imported to wrong store

**Solution (Windows):**
1. Win + R → `certmgr.msc`
2. Check **Personal → Certificates**
3. If missing, reimport to "Personal" store

### Issue: "SSL handshake failed"

**Cause:** NGINX configuration error

**Solution:**
```bash
# Check NGINX error log
sudo tail -n 50 /var/log/nginx/error.log

# Test configuration
sudo nginx -t

# Verify certificate files exist
ls -la /etc/nginx/ssl/
```

### Issue: Backend app not receiving requests

**Cause:** Proxy backend not running

**Solution:**
```bash
# Check if backend is listening
sudo netstat -tlnp | grep 8088

# Start your backend application
# Example: sudo systemctl start your-app
```

### Issue: Certificate expired

**Solution:**
```bash
# Check expiration
openssl x509 -in /etc/nginx/ssl/client_username.crt -noout -enddate

# Recreate certificate
sudo cert-manager.sh
# Select option 1, use same username
```

---

## 📁 File Structure
```
/etc/nginx/ssl/
├── ca.crt                    # Certificate Authority certificate
├── ca.key                    # CA private key (KEEP SECURE!)
├── ca.srl                    # Serial number tracker
├── server.crt                # Server certificate
├── server.key                # Server private key
├── client_admin.crt          # Client certificate (admin)
├── client_admin.key          # Client private key (admin)
├── client_admin.p12          # Client PKCS12 bundle (admin)
├── client_user1.crt          # Additional client certificates...
├── client_user1.key
└── client_user1.p12

/etc/nginx/sites-available/
└── myapp                     # NGINX configuration

/usr/local/bin/
├── ssl-setup.sh              # Initial setup script
└── cert-manager.sh           # Certificate management script

/var/log/nginx/
├── app-access.log            # Access logs
└── app-error.log             # Error logs
```

---

## 📊 Monitoring & Statistics

### View Real-Time Connections
```bash
sudo tail -f /var/log/nginx/app-access.log
```

### Connection Statistics (Today)
```bash
sudo cert-manager.sh
# Select option 5
```

### Manual Statistics
```bash
# Count connections per user
sudo grep $(date +%d/%b/%Y) /var/log/nginx/app-access.log | \
  grep -oP 'CN=\K[^,]+' | sort | uniq -c | sort -rn
```

### Log Rotation

NGINX logs rotate automatically, but you can force rotation:
```bash
sudo logrotate -f /etc/logrotate.d/nginx
```

---

## ❓ FAQ

### Q: Can I use this with Let's Encrypt?

**A:** Yes! Use Let's Encrypt for the server certificate and your CA only for client certificates:
```nginx
ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
ssl_client_certificate /etc/nginx/ssl/ca.crt;  # Your private CA
```

### Q: How do I integrate with LDAP/Active Directory?

**A:** Install `libnginx-mod-http-auth-ldap` and add LDAP authentication for dual-factor security. See documentation for details.

### Q: Can I use the same certificate on multiple devices?

**A:** Yes, but it's not recommended for security auditing. Better practice: one certificate per user, allowing device tracking.

### Q: What happens if CA private key is compromised?

**A:** You must:
1. Create new CA
2. Reissue all certificates
3. Distribute new certificates to all users
4. Update NGINX configuration

### Q: Can I automate certificate distribution?

**A:** Yes! Use SCP, email, or a secure file sharing service:
```bash
# Example: SCP to user machine
scp /etc/nginx/ssl/client_john.p12 user@client-machine:/tmp/
```

### Q: How many certificates can I create?

**A:** Unlimited. The serial number file (`ca.srl`) tracks issuance.

### Q: Does this work with mobile devices?

**A:** Yes! Mobile browsers support client certificates:
- iOS Safari: Install via profile or AirDrop
- Android Chrome: Settings → Security → Install from storage

---

## 🔄 Updates & Maintenance

### Updating NGINX Configuration
```bash
sudo nano /etc/nginx/sites-available/myapp
sudo nginx -t
sudo systemctl reload nginx
```

### Renewing Server Certificate
```bash
cd /etc/nginx/ssl
sudo rm server.crt server.key

# Recreate (same steps as initial setup)
sudo openssl genrsa -out server.key 2048
sudo openssl req -new -key server.key -out server.csr \
  -subj "/C=IL/ST=Israel/L=TelAviv/O=MyCompany/CN=192.168.90.200"
echo "subjectAltName=IP:192.168.90.200" > san.cnf
sudo openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -days 3650 -sha256 -extfile san.cnf
sudo rm server.csr san.cnf

sudo systemctl reload nginx
```

---

## 📞 Support

For issues or questions:
1. Check troubleshooting section
2. Review NGINX error logs
3. Verify certificate validity
4. Test with `openssl s_client -connect IP:443 -cert client.crt -key client.key`

---

## 📝 License

This setup is provided as-is for educational and internal use.

---

## 🙏 Credits

Created for secure internal web application access using industry-standard mTLS authentication.

**Version:** 1.0  
**Last Updated:** December 2024  
**Tested on:** Ubuntu 24.04.3 LTS, NGINX 1.24.0

---

## 🔖 Quick Reference
```bash
# Initial setup
sudo ssl-setup.sh

# Manage certificates
sudo cert-manager.sh

# Check NGINX
sudo nginx -t
sudo systemctl status nginx
sudo systemctl reload nginx

# View logs
sudo tail -f /var/log/nginx/app-access.log
sudo tail -f /var/log/nginx/app-error.log

# List certificates
ls -la /etc/nginx/ssl/client_*.p12

# Export certificate
sudo cp /etc/nginx/ssl/client_user.p12 /tmp/

# Backup
sudo tar -czf ssl-backup.tar.gz /etc/nginx/ssl/
```

---

**End of Documentation**