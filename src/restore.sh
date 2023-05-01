#! /bin/sh

set -ue
set -o pipefail
set -x

source ./env.sh

s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}"

if [ -z "$PASSPHRASE" ]; then
  file_type=".dump"
else
  file_type=".dump.gpg"
fi

if [ $# -eq 1 ]; then
  timestamp="$1"
  key_suffix="${POSTGRES_DATABASE}_${timestamp}${file_type}"
else
  echo "Finding latest backup for ${POSTGRES_DATABASE}..."
  key_suffix=$(
    aws $aws_args s3 ls "${s3_uri_base}/${POSTGRES_DATABASE}" \
      | sort \
      | tail -n 1 \
      | awk '{ print $4 }'
  )
fi

echo "Fetching backup from S3..."
aws $aws_args s3 cp "${s3_uri_base}/${key_suffix}" "db${file_type}"

if [ -n "$PASSPHRASE" ]; then
  echo "Decrypting backup..."
  gpg --decrypt --batch --passphrase "$PASSPHRASE" db.dump.gpg > db.dump
  rm db.dump.gpg
fi

if [ -z "$TARGET_DATABASE" ]; then
  TARGET_DATABASE=$POSTGRES_DATABASE
fi

if [ ! "$BACKUP_FORMAT" = plain]; then
  TARGET_DATABASE=$POSTGRES_DATABASE
fi

conn_opts="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER"

echo "Creating DB \"$TARGET_DATABASE\""
createdb $conn_opts -T template0 $TARGET_DATABASE
echo "Restoring from backup..."
if [ "$BACKUP_FORMAT" = plain]; then
  psql $conn_opts -d $TARGET_DATABASE < db.dump
else
  pg_restore $conn_opts -d $TARGET_DATABASE --clean --if-exists db.dump
fi
rm db.dump

echo "Restore complete."
