balls src/SWAP/GetReserves.balls -d --output-path src/SWAP/GetReserves.huff
balls src/SWAP/Update.balls -d --output-path src/SWAP/Update.huff
balls src/SWAP/Mint.balls -d --output-path src/SWAP/Mint.huff
balls src/SWAP/Burn.balls -d --output-path src/SWAP/Burn.huff
balls src/SWAP/Skim.balls -d --output-path src/SWAP/Skim.huff
balls src/SWAP/Sync.balls -d --output-path src/SWAP/Sync.huff
balls src/SWAP/Swap.balls -d --output-path src/SWAP/Swap.huff
balls src/SWAP/Utils.balls -d --output-path src/SWAP/Utils.huff

cat src/SWAP/template.huff        > src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/GetReserves.huff    >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Update.huff         >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Mint.huff           >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Burn.huff           >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Skim.huff           >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Sync.huff           >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Swap.huff           >> src/SWAP/main.huff
echo "\n"                        >> src/SWAP/main.huff
cat src/SWAP/Utils.huff           >> src/SWAP/main.huff
  

# ERC20 events mac syntax
sed -i "" "s/\[_APPROVAL_EVENT_SIGNATURE\]/__EVENT_HASH(Approval)/g" src/SWAP/main.huff
sed -i "" "s/\[_TRANSFER_EVENT_SIGNATURE\]/__EVENT_HASH(Transfer)/g" src/SWAP/main.huff

# ERC20 events linux syntax
sed -i "s/\[_APPROVAL_EVENT_SIGNATURE\]/__EVENT_HASH(Approval)/g" src/SWAP/main.huff
sed -i "s/\[_TRANSFER_EVENT_SIGNATURE\]/__EVENT_HASH(Transfer)/g" src/SWAP/main.huff

# Pair events mac syntax
sed -i "" "s/\[_SYNC_EVENT_SIGNATURE\]/__EVENT_HASH(Sync)/g" src/SWAP/main.huff
sed -i "" "s/\[_MINT_EVENT_SIGNATURE\]/__EVENT_HASH(Mint)/g" src/SWAP/main.huff
sed -i "" "s/\[_SWAP_EVENT_SIGNATURE\]/__EVENT_HASH(Swap)/g" src/SWAP/main.huff
sed -i "" "s/\[_BURN_EVENT_SIGNATURE\]/__EVENT_HASH(Burn)/g" src/SWAP/main.huff

sed -i "" "s/\[SIG_onTransferReceived\]/__FUNC_SIG(\"onTransferReceived(address,address,uint256,bytes)\")/g" src/SWAP/main.huff
sed -i "" "s/\[SIG_onApprovalReceived\]/__FUNC_SIG(\"onApprovalReceived(address,uint256,bytes)\")/g" src/SWAP/main.huff
sed -i "" "s/\[SIG_uniswapV2Call\]/__FUNC_SIG(\"uniswapV2Call(address,uint256,uint256,bytes)\")/g" src/SWAP/main.huff

# Pair events linux syntax
sed -i "s/\[_SYNC_EVENT_SIGNATURE\]/__EVENT_HASH(Sync)/g" src/SWAP/main.huff
sed -i "s/\[_MINT_EVENT_SIGNATURE\]/__EVENT_HASH(Mint)/g" src/SWAP/main.huff
sed -i "s/\[_SWAP_EVENT_SIGNATURE\]/__EVENT_HASH(Swap)/g" src/SWAP/main.huff
sed -i "s/\[_BURN_EVENT_SIGNATURE\]/__EVENT_HASH(Burn)/g" src/SWAP/main.huff

sed -i "s/\[SIG_onTransferReceived\]/__FUNC_SIG(\"onTransferReceived(address,address,uint256,bytes)\")/g" src/SWAP/main.huff
sed -i "s/\[SIG_onApprovalReceived\]/__FUNC_SIG(\"onApprovalReceived(address,uint256,bytes)\")/g" src/SWAP/main.huff
sed -i "s/\[SIG_uniswapV2Call\]/__FUNC_SIG(\"uniswapV2Call(address,uint256,uint256,bytes)\")/g" src/SWAP/main.huff


# sanity check
huffc src/mocks/LPTokenMint.huff
huffc src/mocks/LPTokenUpdate.huff

