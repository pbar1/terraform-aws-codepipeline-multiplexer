FROM library/golang:1.11.2-stretch
ENV GOBIN=/bin
WORKDIR /src
COPY main.go .
RUN go get -t ./...
ENTRYPOINT ["go"]
