
balls src/ERC1363/TransferAndCall.balls -d --output-path src/ERC1363/TransferAndCall.huff
balls src/ERC1363/TransferFromAndCall.balls -d --output-path src/ERC1363/TransferFromAndCall.huff
balls src/ERC1363/TransferFromAndCallHook.balls -d --output-path src/ERC1363/TransferFromAndCallHook.huff
balls src/ERC1363/ApproveAndCall.balls -d --output-path src/ERC1363/ApproveAndCall.huff

cat src/ERC1363/template.huff                 > src/ERC1363/main.huff
echo "\n"                                    >> src/ERC1363/main.huff
cat src/ERC1363/TransferAndCall.huff         >> src/ERC1363/main.huff
echo "\n"                                    >> src/ERC1363/main.huff
cat src/ERC1363/TransferFromAndCall.huff     >> src/ERC1363/main.huff
echo "\n"                                    >> src/ERC1363/main.huff
cat src/ERC1363/TransferFromAndCallHook.huff >> src/ERC1363/main.huff
echo "\n"                                    >> src/ERC1363/main.huff
cat src/ERC1363/ApproveAndCall.huff          >> src/ERC1363/main.huff


sed -i "s/\[_APPROVAL_EVENT_SIGNATURE\]/__EVENT_HASH(Approval)/g" src/ERC1363/main.huff
sed -i "s/\[_TRANSFER_EVENT_SIGNATURE\]/__EVENT_HASH(Transfer)/g" src/ERC1363/main.huff
sed -i "s/\[SIG_onTransferReceived\]/__FUNC_SIG(\"onTransferReceived(address,address,uint256,bytes)\")/g" src/ERC1363/main.huff
sed -i "s/\[SIG_onApprovalReceived\]/__FUNC_SIG(\"onApprovalReceived(address,uint256,bytes)\")/g" src/ERC1363/main.huff


# sanity check
huffc src/mocks/PayableToken.huff

