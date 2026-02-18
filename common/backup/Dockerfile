FROM huacnlee/gobackup:latest

RUN apk add --no-cache postgresql16-client

COPY --chmod=755 event-backup.sh /app/event-backup.sh
