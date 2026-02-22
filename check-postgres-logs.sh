#!/bin/bash
# Check PostgreSQL logs for errors during installation

echo "=========================================="
echo "PostgreSQL Log Analysis"
echo "=========================================="
echo ""

ssh -o StrictHostKeyChecking=no root@10.42.42.9 << 'ENDSSH'
echo "1. Finding PostgreSQL log file..."
LOG_FILE=$(sudo -u postgres psql -t -c "SHOW log_directory;" | xargs)/postgresql-$(date +%Y-%m-%d)*.log
echo "   Log location: $LOG_FILE"
echo ""

echo "2. Recent errors and rollbacks..."
sudo tail -200 /var/log/postgresql/postgresql-*.log 2>/dev/null || \
  sudo tail -200 /var/lib/postgresql/*/main/log/postgresql-*.log 2>/dev/null || \
  sudo journalctl -u postgresql -n 200 --no-pager | grep -i "error\|rollback\|exception"
echo ""

echo "3. Checking for specific iqgeo database errors..."
sudo tail -500 /var/log/postgresql/postgresql-*.log 2>/dev/null | grep -i "iqgeo" | tail -50 || \
  sudo journalctl -u postgresql -n 500 --no-pager | grep -i "iqgeo" | tail -50
ENDSSH

echo ""
echo "=========================================="
