#echo "remove dangling images"
#docker rmi $(docker images -f "dangling=true" -q)

docker stop $(docker ps -q)
docker rm $(docker ps -aq)
docker network rm nitro_default