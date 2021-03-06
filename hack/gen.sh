#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

RETVAL=0
ROOT=$PWD
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ALIAS="Mgoogle/api/annotations.proto=github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis/google/api,"
ALIAS+="Mweb-api/dtypes/dtypes.proto=github.com/sgipc/web-api/dtypes,"
ALIAS+="Mweb-api/auth/auth.proto=github.com/sgipc/web-api/auth"

clean() {
	(find . | grep pb.go | xargs rm) || true
	(find . | grep pb.gw.go | xargs rm) || true
	# Do NOT delete schema.json files as they contain handwritten validation rules.
	# contact tamal@ / sadlil@ if in doubt.
	# (find . | grep schema.json | xargs rm) || true
	(find . | grep schema.go | xargs rm) || true
	(find . | grep php | xargs rm) || true
}

gen_proto() {
  if [ $(ls -1 *.proto 2>/dev/null | wc -l) = 0 ]; then
    return
  fi
  rm -rf *.pb.go
  protoc -I /usr/local/include -I . \
         -I ${GOPATH}/src/github.com/sgipc \
         -I ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
         -I ${GOPATH}/src/github.com/google/googleapis/google \
         --go_out=plugins=grpc,${ALIAS}:. *.proto
}

gen_gateway_proto() {
  if [ $(ls -1 *.proto 2>/dev/null | wc -l) = 0 ]; then
    return
  fi
  rm -rf *.pb.gw.go
  protoc -I /usr/local/include -I . \
         -I ${GOPATH}/src/github.com/sgipc \
         -I ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
         -I ${GOPATH}/src/github.com/google/googleapis/google \
         --grpc-gateway_out=logtostderr=true,${ALIAS}:. *.proto
}

gen_swagger_def() {
  if [ $(ls -1 *.proto 2>/dev/null | wc -l) = 0 ]; then
    return
  fi
   rm -rf *.swagger.json
   protoc -I /usr/local/include -I . \
          -I ${GOPATH}/src/github.com/sgipc \
          -I ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
          -I ${GOPATH}/src/github.com/google/googleapis/google \
          --swagger_out=logtostderr=true,${ALIAS}:. *.proto
}

gen_server_protos() {
	echo "Generating server protobuf files"
    for d in */ ; do
      pushd ${d}
      gen_proto
      if [ -d */ ]; then
        for dd in */ ; do
          pushd ${dd}
          gen_proto
          popd
        done
      fi
      popd
    done
}

gen_proxy_protos() {
    echo "Generating gateway protobuf files"
    for d in */ ; do
      pushd ${d}
      gen_gateway_proto
      if [ -d */ ]; then
        for dd in */ ; do
          pushd ${dd}
          gen_gateway_proto
          popd
        done
      fi
      popd
    done
}

gen_swagger_defs() {
    echo "Generating swagger api definition files"
    for d in */ ; do
      pushd ${d}
      gen_swagger_def
      if [ -d */ ]; then
        for dd in */ ; do
          pushd ${dd}
          gen_swagger_def
          popd
        done
      fi
      popd
    done
    # fix host, schemes
    python $DIR/schema.py fix_swagger_schema
}

gen_py() {
  if [ $(ls -1 *.proto 2>/dev/null | wc -l) = 0 ]; then
    return
  fi
  rm -rf *.py
  protoc -I /usr/local/include -I . \
         -I ${GOPATH}/src/github.com/sgipc \
         -I ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
         -I ${GOPATH}/src/github.com/google/googleapis/google \
         --python_out=plugins=grpc,${ALIAS}:. *.proto
}

gen_python_protos() {
  gen_py
  for d in */ ; do
    pushd ${d}
    gen_py
    if [ -d */ ]; then
      for dd in */ ; do
        pushd ${dd}
        gen_py
        popd
      done
    fi
    popd
  done
}

gen_php() {
  if [ $(ls -1 *.proto 2>/dev/null | wc -l) = 0 ]; then
    return
  fi
  rm -rf *.php
  protoc -I /usr/local/include -I . \
         -I ${GOPATH}/src/github.com/sgipc \
         -I ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
         -I ${GOPATH}/src/github.com/google/googleapis/google \
         --plugin=protoc-gen-php="$(which protoc-gen-php)" \
         --php_out=':.' *.proto
}

gen_php_protos() {
  for d in */ ; do
    pushd ${d}
    gen_php
    if [ -d */ ]; then
      for dd in */ ; do
        pushd ${dd}
        gen_php
        popd
      done
    fi
    popd
  done
}

compile() {
  echo "compiling files"
  go install ./...
}

gen_protos() {
  clean
  gen_server_protos
  gen_proxy_protos
  gen_swagger_defs
  # gen_python_protos
  # gen_php_protos
  compile
}

if [ $# -eq 0 ]; then
	gen_protos
	exit $RETVAL
fi

case "$1" in
  compile)
      compile
      ;;
	server)
		gen_server_protos
		;;
	proxy)
		gen_proxy_protos
		;;
	swagger)
		gen_swagger_defs
		;;
	all)
		gen_protos
		;;
	clean)
	  clean
	  ;;
	py)
	  gen_python_protos
	  ;;
	php)
	  gen_php_protos
	  ;;
	*)  echo $"Usage: $0 {compile|server|proxy|swagger|json-schema|all|clean}"
		RETVAL=1
		;;
esac
exit $RETVAL
