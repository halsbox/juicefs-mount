FROM golang:alpine AS builder
ARG GIT_TAG=v1.2.1
ENV GO111MODULE=on
WORKDIR /build
RUN apk add --no-cache git upx musl-dev gcc \
  && git clone --depth=1 --branch $GIT_TAG https://github.com/juicedata/juicefs.git \
  && cd juicefs \
  && CGO_ENABLED=1 CGO_LDFLAGS="-static" \
    go build -tags \
    nogateway,nowebdav,nocos,nobos,nohdfs,noibmcos,noobs,nooss,noqingstor,noscs,nosftp,noswift,noupyun,noazure,nogs,noufile,nob2,nonfs,nodragonfly,nosqlite,nomysql,nopg,notikv,nobadger,noetcd \
    -ldflags="-s -w -linkmode external -extldflags '-static'" -o juicefs . \
  && upx -9 juicefs

FROM busybox:uclibc
ENV PATH=/bin JUICE_MP=/data JUICE_META="redis://redis:6379/15" JUICE_OPTIONS="-o allow_other,writeback_cache --writeback"
COPY --from=gcr.io/distroless/static / /
COPY --from=builder /build/juicefs/juicefs /bin/juicefs
RUN echo -e "#!/bin/sh\ntrap 'test -e \${JUICE_MP}/.config && umount \${JUICE_MP}' TERM INT HUP; juicefs mount \${JUICE_OPTIONS} \${JUICE_META} \${JUICE_MP} & p=\$!; wait \$p" > /bin/mount.sh \
  && echo -e "#!/bin/sh -e\nexec \"\$@\"" >> /bin/entrypoint.sh \
  && chmod a+x /bin/*.sh
ENTRYPOINT ["/bin/entrypoint.sh"]
CMD ["mount.sh"]
