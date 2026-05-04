#!/bin/bash
# Syslog Proxy User Data - Amazon Linux 2023
# Receives FortiGate logs via syslog-ng, rotates every 10 minutes,
# uploads to cross-account S3 via AssumeRole

set -euo pipefail

# Variables from Terraform
S3_BUCKET="${s3_bucket_name}"
S3_REGION="${s3_bucket_region}"
TARGET_ACCOUNT_ID="${target_account_id}"
CROSS_ACCOUNT_ROLE="${cross_account_role}"
CRON_SCHEDULE="${cron_schedule}"

ROLE_ARN="arn:aws:iam::$${TARGET_ACCOUNT_ID}:role/$${CROSS_ACCOUNT_ROLE}"

# ---- 1. System Update and Package Installation ----
dnf update -y
dnf install -y syslog-ng awscli cronie

# ---- 2. Create Log Directory ----
mkdir -p /var/log/fortigate
chmod 0750 /var/log/fortigate

# ---- 3. Configure syslog-ng ----
cat > /etc/syslog-ng/syslog-ng.conf << 'SYSLOG_CONF'
@version: 4.2
@include "scl.conf"

source s_fortigate {
    udp(
        ip(0.0.0.0)
        port(514)
        flags(no-parse)
    );
    tcp(
        ip(0.0.0.0)
        port(514)
        flags(no-parse)
    );
};

destination d_fortigate {
    file(
        "/var/log/fortigate/$${SOURCEIP}/fortigate.log"
        owner("root")
        group("root")
        perm(0640)
        dir_perm(0750)
        create_dirs(yes)
    );
};

log {
    source(s_fortigate);
    destination(d_fortigate);
    flags(flow-control);
};
SYSLOG_CONF

# ---- 4. Enable and Start syslog-ng ----
systemctl enable syslog-ng
systemctl start syslog-ng

# ---- 5. Configure AWS CLI default region ----
mkdir -p /root/.aws
cat > /root/.aws/config << AWS_CONFIG
[default]
region = $${S3_REGION}
output = json
AWS_CONFIG

# ---- 6. Create S3 Upload Script ----
cat > /usr/local/bin/upload-fortigate-logs.sh << 'UPLOAD_SCRIPT'
#!/bin/bash
# Rotate active log files, upload completed files to cross-account S3

S3_BUCKET="${s3_bucket_name}"
S3_REGION="${s3_bucket_region}"
TARGET_ACCOUNT_ID="${target_account_id}"
CROSS_ACCOUNT_ROLE="${cross_account_role}"
ROLE_ARN="arn:aws:iam::$${TARGET_ACCOUNT_ID}:role/$${CROSS_ACCOUNT_ROLE}"
LOG_DIR="/var/log/fortigate"
TIMESTAMP=$$(date +%Y%m%d_%H%M)

# Assume cross-account role for S3 access
CREDS=$$(aws sts assume-role \
  --role-arn "$${ROLE_ARN}" \
  --role-session-name "syslog-upload-$$$$" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text 2>/dev/null) || {
    echo "$$(date): Failed to assume role $${ROLE_ARN}" >> /var/log/s3-upload.log
    exit 1
}

export AWS_ACCESS_KEY_ID=$$(echo "$$CREDS" | cut -d' ' -f1)
export AWS_SECRET_ACCESS_KEY=$$(echo "$$CREDS" | cut -d' ' -f2)
export AWS_SESSION_TOKEN=$$(echo "$$CREDS" | cut -d' ' -f3)

# Rotate active log files and upload
find "$${LOG_DIR}" -name "fortigate.log" -type f | while read -r logfile; do
    src_dir=$$(dirname "$${logfile}")
    src_ip=$$(basename "$${src_dir}")

    # Skip empty files
    if [ ! -s "$${logfile}" ]; then
        continue
    fi

    # Rotate: rename current file with timestamp
    rotated="$${src_dir}/fortigate_$${TIMESTAMP}"
    mv "$${logfile}" "$${rotated}"
    touch "$${logfile}"
    chmod 0640 "$${logfile}"

    # Upload to S3
    aws s3 cp "$${rotated}" "s3://$${S3_BUCKET}/fortigate-logs/$${src_ip}/fortigate_$${TIMESTAMP}" \
        --region "$${S3_REGION}" --quiet 2>>/var/log/s3-upload.log

    if [ $$? -eq 0 ]; then
        rm -f "$${rotated}"
        echo "$$(date): Uploaded $${rotated} to S3" >> /var/log/s3-upload.log
    else
        echo "$$(date): Upload failed for $${rotated}, keeping local" >> /var/log/s3-upload.log
    fi
done

# Clean up any leftover rotated files (older than 24 hours)
find "$${LOG_DIR}" -name "fortigate_[0-9]*" -type f -mmin +1440 -delete 2>/dev/null || true
UPLOAD_SCRIPT

chmod +x /usr/local/bin/upload-fortigate-logs.sh

# ---- 7. Set up Cron Job ----
(crontab -l 2>/dev/null; echo "$${CRON_SCHEDULE} /usr/local/bin/upload-fortigate-logs.sh") | crontab -

systemctl enable crond
systemctl start crond

# ---- 8. Verify S3 bucket access at startup ----
echo "Testing S3 access..." >> /var/log/s3-upload.log
aws sts assume-role \
  --role-arn "$${ROLE_ARN}" \
  --role-session-name "startup-test" \
  --query 'Credentials.AccessKeyId' --output text 2>/dev/null && \
    echo "AssumeRole OK" >> /var/log/s3-upload.log || \
    echo "WARNING: Cannot assume role $${ROLE_ARN}. Check IAM setup." >> /var/log/s3-upload.log
