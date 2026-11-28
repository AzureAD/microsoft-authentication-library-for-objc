FROM postgres:18-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 gnupg ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /backup
COPY AuthPlatform/BackupRunner/backup_once.py /backup/backup_once.py
COPY AuthPlatform/BackupRunner/server.py /backup/server.py

EXPOSE 10000
ENTRYPOINT ["python3"]
CMD ["/backup/server.py"]
