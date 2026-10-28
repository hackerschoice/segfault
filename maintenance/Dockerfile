FROM sf-base
RUN apt-get update && apt-get install -y --no-install-recommends xfsprogs e2fsprogs util-linux procps && rm -rf /var/lib/apt/lists/*
CMD ["/sf/sfbin/cronjob", "daemon"]
