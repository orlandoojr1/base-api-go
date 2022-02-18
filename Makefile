TARGET_FILE:=${shell head -n1 go.mod | sed -r 's/.*\/(.*)/\1/g' }
BUILD_DIR=build
COVER_PROFILE_FILE="${BUILD_DIR}/go-cover.tmp"
RESOURCES_FILE=resources/resources.go
RESOURCES_FILE_EXISTS=$(shell [ -e $(RESOURCES_FILE) ] && echo 1 || echo 0 )

.PHONY: target build run clean mk-build-dir build-deps bin-data build build-all\
 build-for-docker docker-build docker-run test cover-html badge

target: build

clean:
	rm -rf $(TARGET_FILE) $(BUILD_DIR)

############## build tasks

mk-build-dir:
	@mkdir -p ${BUILD_DIR}

build-deps:
	@go get -d -v ./...

bin-data: build-deps
ifeq ($(RESOURCES_FILE_EXISTS), 1)
	@rm -f $(RESOURCES_FILE) 
	@go get -d github.com/go-bindata/go-bindata/... 
	go-bindata -pkg resources -o $(RESOURCES_FILE) resources/ 
endif

build: clean build-deps test
	go build -o $(TARGET_FILE)

run:
	@go build -o $(TARGET_FILE) && go run .
############## docker build tasks

build-all: clean mk-build-dir build-deps test
	GOOS=linux go build && zip -9 $(TARGET_FILE)-linux64.zip $(TARGET_FILE) && rm $(TARGET_FILE)
	GOOS=windows go build && zip -9 $(TARGET_FILE)-win64.zip $(TARGET_FILE).exe && rm $(TARGET_FILE).exe
	GOOS=darwin go build && zip -9 $(TARGET_FILE)-osx64.zip $(TARGET_FILE) && rm $(TARGET_FILE)
	mv *.zip ${BUILD_DIR}

build-for-docker: clean build-deps
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -ldflags '-extldflags "-static"' -o main

docker-build: 
	docker build . -t $(TARGET_FILE)

docker-run: docker-build
	docker run -ti -p 8080:8080 $(TARGET_FILE)
	curl http://localhost:8080/stats 

############## test tasks

test: bin-data
	@go fmt ./...
	go test ./...
	$(MAKE) badge

cover-html: mk-build-dir test
	go test -coverprofile=${COVER_PROFILE_FILE} ./...
	go tool cover -html=${COVER_PROFILE_FILE}

badge:
	@go get github.com/jpoles1/gopherbadger/...
	gopherbadger -md="README.md" -png=false 1>&2 2> /dev/null
	@if [ -f coverage.out ]; then rm coverage.out ; fi; 
