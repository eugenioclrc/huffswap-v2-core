balls src/SWAP/GetReserves.balls -d --output-path src/SWAP/GetReserves.huff
balls src/SWAP/Update.balls -d --output-path src/SWAP/Update.huff
balls src/SWAP/Mint.balls -d --output-path src/SWAP/Mint.huff

cat src/SWAP/template.huff        > src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/GetReserves.huff    >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Update.huff         >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Mint.huff           >> src/SWAP/main.huff
  


sed -i "s/\[_APPROVAL_EVENT_SIGNATURE\]/__EVENT_HASH(Approval)/g" src/SWAP/main.huff
sed -i "s/\[_TRANSFER_EVENT_SIGNATURE\]/__EVENT_HASH(Transfer)/g" src/SWAP/main.huff
sed -i "s/\[_SYNC_EVENT_SIGNATURE\]/__EVENT_HASH(Sync)/g" src/SWAP/main.huff

sed -i "s/\[SIG_onTransferReceived\]/__FUNC_SIG(\"onTransferReceived(address,address,uint256,bytes)\")/g" src/SWAP/main.huff
sed -i "s/\[SIG_onApprovalReceived\]/__FUNC_SIG(\"onApprovalReceived(address,uint256,bytes)\")/g" src/SWAP/main.huff




# sanity check
huffc src/mocks/LPToken.huff

