#echo "remove dangling images"
#docker rmi $(docker images -f "dangling=true" -q)

echo "build nitro node"
docker build . -t nitro-node-dev --target nitro-node-dev

echo "tag nitro node"
docker tag nitro-node-dev:latest nitro-node-dev-testnode

echo "run sequecer"
docker-compose up sequencer 