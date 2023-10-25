FROM golang:latest AS build
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -tags prod -ldflags '-w'

FROM alpine:latest
WORKDIR /app/
COPY --from=build /build/logpipe /app/logpipe
ENTRYPOINT ["/app/logpipe"]