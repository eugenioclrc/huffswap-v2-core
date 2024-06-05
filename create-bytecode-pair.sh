echo -n "hex\"" > pair.bytecode
huffc -e paris -b --optimize src/LPToken.huff >> pair.bytecode
echo -n "\"" >> pair.bytecode
sed -i "s/c00ffec00ffec00ffec00ffec00ffec00ffec00f/\",abi.encode(address(this)),hex\"/g" pair.bytecode
sed -i "s/beefbeefbeefbeefbeefbeefbeefbeefbeefbeef/\",abi.encode(token0),hex\"/g" pair.bytecode
sed -i "s/c0dec0dec0dec0dec0dec0dec0dec0dec0dec0de/\",abi.encode(token1),hex\"/g" pair.bytecode