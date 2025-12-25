# SSL Client Certificate Authentication System

מערכת מלאה להטמעת אימות mTLS (Mutual TLS) על NGINX עם ניהול תעודות קל.

## מה זה ולמה צריך את זה?

### הבעיה
כשיש לך אפליקציה פנימית (כמו CRM, מערכת ניהול, או כל שירות רגיש), אתה צריך להגן עליה מפני גישה לא מורשית. סיסמה רגילה לא מספיקה כי:
- סיסמאות יכולות להיגנב (פישינג, keylogger)
- אפשר לנחש אותן (brute force)
- משתמשים משתפים סיסמאות
- אין דרך לדעת מאיזה מכשיר מתחברים

### הפתרון: Mutual TLS (mTLS)
במקום רק סיסמה, כל משתמש מקבל **תעודה דיגיטלית** שמותקנת על המחשב שלו. בלי התעודה - אי אפשר להתחבר בכלל.

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   לקוח      │◄───────►│   NGINX     │◄───────►│  אפליקציה   │
│  + תעודה    │  mTLS   │  (שרת)      │  proxy  │  (backend)  │
└─────────────┘         └─────────────┘         └─────────────┘
```

### יתרונות

| יתרון | הסבר |
|-------|------|
| **אימות דו-כיווני** | גם השרת וגם הלקוח מוכיחים את זהותם |
| **ללא סיסמאות** | אי אפשר לגנוב מה שלא קיים |
| **שליטה מלאה** | תעודה לכל משתמש, ביטול מיידי |
| **לוגים מפורטים** | יודעים בדיוק מי התחבר ומתי |
| **הגנה מ-MITM** | תקשורת מוצפנת מקצה לקצה |

---

## מבנה הפרויקט

```
SSL_setup/
├── ssl-setup.sh          # התקנה עם TCP proxy (פורט)
├── ssl-setup-socket.sh   # התקנה עם Unix socket
├── cert-manager.sh       # ניהול תעודות משתמשים
└── README.md             # המדריך הזה
```

---

## דרישות מקדימות

### שרת
- **מערכת הפעלה**: Ubuntu 24.04 LTS (או דומה)
- **תוכנות**: NGINX, OpenSSL, Bash (מותקנים אוטומטית)

### לקוח
- דפדפן מודרני (Chrome, Firefox, Edge, Safari)
- יכולת להתקין תעודות לקוח

---

## התקנה מהירה

### שלב 1: הרצת סקריפט ההתקנה

**לשרת עם TCP backend (פורט):**
```bash
sudo ./ssl-setup.sh
```

**לשרת עם Unix socket (למשל Rails/Unicorn):**
```bash
sudo ./ssl-setup-socket.sh
```

### שלב 2: מענה על השאלות

הסקריפט ישאל אותך (כל הערכים ניתנים לשינוי):

| שאלה | דוגמה | הסבר |
|------|-------|------|
| Certificate directory | `/etc/nginx/ssl` | איפה לשמור את התעודות |
| NGINX config file | `/etc/nginx/sites-available/myapp` | שם קובץ הקונפיגורציה |
| Server IP | `192.168.1.100` | כתובת IP של השרת |
| Server domain | `app.example.com` | דומיין (אופציונלי) |
| Proxy type | `1` (socket) או `2` (TCP) | סוג החיבור לאפליקציה |
| Socket path / Port | `/tmp/app.sock` או `8080` | נתיב ה-socket או הפורט |
| Password | `MySecurePass123` | סיסמה לקובצי התעודה |
| Organization | `MyCompany` | שם הארגון (יופיע בתעודות) |
| First client | `admin` | שם המשתמש הראשון |

**הערה לגבי דומיין:** אם תזין דומיין, התעודה תכלול גם את ה-IP וגם את הדומיין ב-SAN (Subject Alternative Names), כך שתוכל לגשת לשרת דרך שניהם.

### שלב 3: אימות ההתקנה

```bash
# בדיקת סטטוס NGINX
sudo systemctl status nginx

# בדיקת קבצי התעודות
ls -la /etc/nginx/ssl/

# בדיקת תקינות הקונפיגורציה
sudo nginx -t
```

### שלב 4: התקנת התעודה במחשב הלקוח

1. העתק את קובץ ה-P12 למחשב שלך:
   ```bash
   scp user@server:/etc/nginx/ssl/client_admin.p12 ~/Desktop/
   ```

2. התקן את התעודה (ראה פירוט למטה)

3. גלוש לכתובת השרת (למשל `https://192.168.1.100`)

---

## ניהול תעודות

לאחר ההתקנה, השתמש ב-cert-manager לניהול שוטף:

```bash
sudo ./cert-manager.sh
```

### הגדרה ראשונית

בהרצה ראשונה, הסקריפט ישאל אותך להגדיר:
- תיקיית תעודות
- סיסמת ברירת מחדל
- שם ארגון
- קובץ לוג NGINX

ההגדרות נשמרות ב: `/etc/nginx/ssl/.cert-manager.conf`

### תפריט הניהול

```
================================
  SSL Client Certificate Manager
================================

1) ➕ Create new certificate    # יצירת תעודה למשתמש חדש
2) 🚫 Revoke certificate        # ביטול תעודה (חסימת משתמש)
3) 📋 List certificates         # רשימת כל התעודות הפעילות
4) 📤 Export certificate        # ייצוא תעודה להעברה
5) 📊 Connection statistics     # סטטיסטיקות חיבורים
6) ⚙️  Change settings           # שינוי הגדרות
7) 🚪 Exit                       # יציאה
```

### דוגמאות שימוש

**יצירת תעודה לעובד חדש:**
```
Choice: 1
Enter username: david
✅ Certificate created successfully!
📁 File: /etc/nginx/ssl/client_david.p12
🔑 Password: 1234
```

**חסימת עובד שעזב:**
```
Choice: 2
Available certificates:
1) admin
2) david
3) sarah
Select number: 2
Are you sure you want to revoke david? (y/n): y
✅ Certificate for david has been revoked!
```

**שינוי הגדרות:**
```
Choice: 6
Current settings:
  1) Certificate directory: /etc/nginx/ssl
  2) Default password: 1234
  3) Organization name: MyCompany
  4) Log file: /var/log/nginx/myapp-access.log
  5) Back to menu

Select setting to change (1-5): 2
New default password: MyNewSecurePassword
✅ Settings saved!
```

---

## התקנת תעודה בצד הלקוח

### Windows

1. **העתק** את קובץ ה-`.p12` למחשב
2. **לחץ כפול** על הקובץ
3. בחר **"Current User"** → Next
4. Next (הנתיב מתמלא אוטומטית)
5. הזן את הסיסמה
6. בחר **"Automatically select"** → Next
7. Finish
8. **סגור את הדפדפן לחלוטין**
9. **פתח מחדש** וגלוש לשרת
10. **בחר את התעודה** כשתתבקש

### macOS

1. לחץ כפול על קובץ ה-`.p12`
2. הוסף ל-**Keychain**
3. הזן את הסיסמה
4. הפעל מחדש את הדפדפן

### Linux

**Firefox:**
Settings → Privacy & Security → View Certificates → Your Certificates → Import

**Chrome:**
Settings → Privacy and Security → Security → Manage Certificates → Import

**שורת פקודה:**
```bash
pk12util -i client_username.p12 -d sql:$HOME/.pki/nssdb
```

### iOS

1. שלח את קובץ ה-P12 במייל או ב-AirDrop
2. לחץ על הקובץ
3. עקוב אחר ההוראות להתקנת Profile

### Android

Settings → Security → Install from storage → בחר את קובץ ה-P12

---

## קבצים שנוצרים

```
/etc/nginx/ssl/
├── ca.key                # מפתח פרטי של ה-CA (שמור בסוד!)
├── ca.crt                # תעודת ה-CA
├── ca.srl                # מעקב אחר מספרים סידוריים
├── server.key            # מפתח פרטי של השרת
├── server.crt            # תעודת השרת
├── client_admin.key      # מפתח פרטי של המשתמש
├── client_admin.crt      # תעודת המשתמש
├── client_admin.p12      # קובץ להתקנה בדפדפן
└── .cert-manager.conf    # הגדרות cert-manager

/etc/nginx/sites-available/
└── [שם הקונפיג שבחרת]    # קונפיגורציית NGINX

/var/log/nginx/
├── [שם]-access.log       # לוג גישה
└── [שם]-error.log        # לוג שגיאות
```

---

## פתרון בעיות

### "NET::ERR_CERT_AUTHORITY_INVALID"
הדפדפן לא מכיר את ה-CA שלך. זה תקין עבור CA פרטי - לחץ "Advanced" ו-"Proceed".

### "400 Bad Request - No required SSL certificate was sent"
לא נבחרה תעודה. וודא שהתעודה מותקנת ובחר אותה כשהדפדפן מבקש.

### "SSL_ERROR_HANDSHAKE_FAILURE_ALERT"
התעודה לא תקינה או פגה. צור תעודה חדשה עם cert-manager.

### הדפדפן לא מבקש לבחור תעודה
- נקה cache ו-cookies
- סגור והפעל מחדש את הדפדפן
- וודא שהתעודה מותקנת נכון

### בדיקת תקינות

```bash
# בדיקת תעודת השרת
openssl x509 -in /etc/nginx/ssl/server.crt -text -noout

# בדיקת תעודת לקוח
openssl x509 -in /etc/nginx/ssl/client_admin.crt -text -noout

# בדיקת תאריך תפוגה
openssl x509 -in /etc/nginx/ssl/client_admin.crt -noout -enddate

# בדיקת תקינות NGINX
sudo nginx -t

# צפייה בלוגים
sudo tail -f /var/log/nginx/*-error.log
```

---

## אבטחה - המלצות

### הרשאות קבצים
```bash
# מפתחות פרטיים - רק root יכול לקרוא
sudo chmod 600 /etc/nginx/ssl/*.key
sudo chmod 600 /etc/nginx/ssl/ca.key

# תעודות - כולם יכולים לקרוא
sudo chmod 644 /etc/nginx/ssl/*.crt
```

### גיבוי
```bash
# גיבוי ה-CA (קריטי!)
sudo tar -czf ssl-backup-$(date +%Y%m%d).tar.gz /etc/nginx/ssl/
sudo cp ssl-backup-*.tar.gz /secure-backup-location/
```

### מה לא לעשות
- לשתף את `ca.key` עם אף אחד
- לשלוח קבצי P12 במייל לא מוצפן
- להשתמש בסיסמאות פשוטות
- להשאיר תעודות של עובדים שעזבו

---

## שילוב עם Let's Encrypt

אפשר להשתמש ב-Let's Encrypt לתעודת השרת וב-CA הפרטי שלך לתעודות הלקוח:

```nginx
ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
ssl_client_certificate /etc/nginx/ssl/ca.crt;  # ה-CA הפרטי שלך
```

---

## שאלות נפוצות

**ש: כמה זמן התעודות תקפות?**
ת: 10 שנים (3650 ימים). אפשר לשנות בקוד.

**ש: אפשר להשתמש בדומיין במקום IP?**
ת: כן! הסקריפט שואל על דומיין בנפרד מה-IP. אם תזין שניהם, התעודה תתמוך בגישה דרך שניהם:
- `https://192.168.1.100`
- `https://app.example.com`

התעודה תכלול את שניהם ב-SAN, וקונפיגורציית NGINX תתאים אוטומטית.

**ש: מה קורה אם מישהו מאבד את המחשב?**
ת: השתמש באפשרות "Revoke certificate" כדי לבטל את התעודה מיידית.

**ש: אפשר להתקין תעודה על טלפון?**
ת: כן, שלח את קובץ ה-P12 לטלפון והתקן אותו דרך ההגדרות.

**ש: איך יודעים מי התחבר?**
ת: השתמש באפשרות "Connection statistics" או בדוק את הלוגים:
```bash
grep "CN=" /var/log/nginx/*-access.log
```

**ש: מה קורה אם ה-CA נפרץ?**
ת: צריך ליצור CA חדש, להנפיק מחדש את כל התעודות, ולהפיץ אותן לכל המשתמשים.

**ש: כמה תעודות אפשר ליצור?**
ת: ללא הגבלה.

---

## פקודות מהירות

```bash
# התקנה ראשונית
sudo ./ssl-setup.sh           # עם TCP port
sudo ./ssl-setup-socket.sh    # עם Unix socket

# ניהול תעודות
sudo ./cert-manager.sh

# בדיקת NGINX
sudo nginx -t
sudo systemctl status nginx
sudo systemctl reload nginx

# צפייה בלוגים
sudo tail -f /var/log/nginx/*-access.log
sudo tail -f /var/log/nginx/*-error.log

# רשימת תעודות
ls -la /etc/nginx/ssl/client_*.p12

# גיבוי
sudo tar -czf ssl-backup.tar.gz /etc/nginx/ssl/
```

---

**גרסה:** 2.0
**עודכן לאחרונה:** דצמבר 2024
**נבדק על:** Ubuntu 24.04.3 LTS, NGINX 1.24.0
