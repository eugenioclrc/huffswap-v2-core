echo 'hex"' > pair.bytecode
huffc -e paris -b --optimize src/LPToken.huff >> pair.bytecode
echo '"' >> pair.bytecode
