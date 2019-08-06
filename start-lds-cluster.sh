#!/usr/bin/env bash

docker network create lds-cluster

docker stop $(docker ps -f "name=pulsar" -q)
docker rm $(docker ps -f "name=pulsar" -aq)
docker run --network=lds-cluster -it --name pulsar -p 6650:6650 -p 8080:8080 -v $PWD/data:/pulsar/data apachepulsar/pulsar:2.4.0 bin/pulsar standalone

docker pull neo4j:3.5
docker run --network=lds-cluster -d --name neo4j-lds-cluster -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo4j/PasSW0rd neo4j:3.5

docker stop $(docker ps -q -f "name=lds01" -f "name=lds02" -f "name=lds03") && docker rm $(docker ps -aq -f "name=lds01" -f "name=lds02" -f "name=lds03")

docker stop $(docker ps -q -f "name=lds01") && docker rm $(docker ps -aq -f "name=lds01")
docker stop $(docker ps -q -f "name=lds02") && docker rm $(docker ps -aq -f "name=lds02")
docker stop $(docker ps -q -f "name=lds03") && docker rm $(docker ps -aq -f "name=lds03")

docker run --network=lds-cluster -d --name lds01 -p 127.0.0.1:8011:9090 -v $PWD/schemas:/schemas -v $PWD/lds01conf:/conf -v $PWD/sagalogs:/sagalogs lds-neo4j:dev
docker run --network=lds-cluster -d --name lds02 -p 127.0.0.1:8012:9090 -v $PWD/schemas:/schemas -v $PWD/lds02conf:/conf -v $PWD/sagalogs:/sagalogs lds-neo4j:dev
docker run --network=lds-cluster -d --name lds03 -p 127.0.0.1:8013:9090 -v $PWD/schemas:/schemas -v $PWD/lds03conf:/conf -v $PWD/sagalogs:/sagalogs lds-neo4j:dev

docker logs -f $(docker ps -f name=lds01 -aq)
docker logs -f $(docker ps -f name=lds02 -aq)
docker logs -f $(docker ps -f name=lds03 -aq)

docker build -t haproxy-lds:latest .
# verify configuration
docker run --network=lds-cluster -it --rm --name haproxy-syntax-check haproxy-lds:latest haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
docker run -d --network=lds-cluster --name haproxy-lds -p 8010:80 haproxy-lds:latest

# configure to localhost:8010/ns from browser
docker run -d --name gsim-browser -p 8000:80 linked-data-store-client:0.1

docker rm $(docker ps -aq)
docker ps --filter=network=lds-cluster

curl -X PUT "http://localhost:8010/ns/Agent/b00fa34f-a589-49ee-80da-8b5129eda5fd?sync=true&saga=failBefore%20E" -H "content-type: application/json; charset=utf-8" --data-binary "@examples/Agent_NMA.json"
