FROM golang:1.10.4-alpine3.8 as build

RUN apk --no-cache add curl \
    && echo "Pulling watchdog binary from Github." \
    && curl -sSLf https://github.com/openfaas-incubator/of-watchdog/releases/download/0.4.6/of-watchdog > /usr/bin/fwatchdog \
    && chmod +x /usr/bin/fwatchdog \
    && apk del curl --no-cache

RUN mkdir -p /go/src/goodfirstissue
WORKDIR /go/src/goodfirstissue
COPY . .

# Run a gofmt and exclude all vendored code.
RUN test -z "$(gofmt -l $(find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./function/vendor/*"))" || { echo "Run \"gofmt -s -w\" on your Golang code"; exit 1; }

RUN CGO_ENABLED=0 GOOS=linux \
    go build --ldflags "-s -w" -a -installsuffix cgo -o goodfirstissue . && \
    go test $(go list ./... | grep -v /vendor/) -cover

FROM alpine:3.8
# Add non root user and certs
RUN apk --no-cache add ca-certificates \
    && addgroup -S app && adduser -S -g app app \
    && mkdir -p /home/app \
    && chown app /home/app

WORKDIR /home/app

COPY --from=build /go/src/goodfirstissue/goodfirstissue    .
COPY --from=build /usr/bin/fwatchdog                       .

USER app

ENV fprocess="./goodfirstissue"
ENV mode="http"
ENV upstream_url="http://127.0.0.1:8080"

CMD ["./fwatchdog"]
