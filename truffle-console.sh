echo "Copying build files..."

cp -r canyacoin/build/contracts/** build/contracts/
cp -r canwork-job/build/contracts/** build/contracts/
cp -r canwork-admin/build/contracts/** build/contracts/

echo "starting truffle network..."

truffle console --network local
