FROM alpine:3.3
MAINTAINER Csaba Kollar <csaba.kollar@gmail.com>

COPY application.go /tmp
RUN apk add -U go && \
    cd /usr/local/bin && \
    go build /tmp/application.go

EXPOSE 8484
CMD ["application"]
