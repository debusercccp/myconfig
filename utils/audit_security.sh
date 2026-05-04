#!/bin/bash
echo "=== SECURITY AUDIT ==="
echo
echo "1. SSH Config Check"
sudo sshd -T | grep -E "PasswordAuthentication|PermitRootLogin|AllowUsers"
echo
echo "2. MariaDB Listening"
sudo ss -tulnp | grep mysql
echo
echo "3. Firewall Status"
sudo ufw status
echo
echo "4. Failed SSH Attempts (last 24h)"
sudo journalctl -u ssh -S "24 hours ago" | grep "Failed\|error" | wc -l
echo
echo "5. Running Services"
systemctl list-units --type=service --state=running | grep -E "ssh|mysql|ufw"
echo
echo "6. User Accounts with Shell Access"
grep -E 'bash|sh' /etc/passwd | cut -d: -f1
echo
echo "7. Sudo Usage (last 10)"
sudo journalctl -u sudo -n 10 --no-pager
