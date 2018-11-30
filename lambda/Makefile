build:
	go build -o handler

build-docker:
	docker build -t tacm .
	docker run --rm -v $(PWD):/src tacm build -o handler
