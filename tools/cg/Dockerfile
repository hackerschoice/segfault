FROM golang:1.20 as BUILD
WORKDIR /app
COPY *.go go.mod go.sum /app/
RUN go mod tidy && go mod vendor
RUN CGO_ENABLED=0 go build -ldflags='-s -w' -o cg

FROM sf-router
COPY --from=BUILD /app/cg /app/cg
ENTRYPOINT ["/app/cg"]
