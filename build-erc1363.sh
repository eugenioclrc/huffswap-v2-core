cat src/ERC1363/template.huff                                        > src/ERC1363/main.huff
balls src/ERC1363/TransferAndCall.balls -d             | head -n -1 >> src/ERC1363/main.huff
balls src/ERC1363/TransferFromAndCall.balls -d         | head -n -1 >> src/ERC1363/main.huff
balls src/ERC1363/TransferFromAndCallHook.balls -g 0.2 | head -n -1 >> src/ERC1363/main.huff
balls src/ERC1363/ApproveAndCall.balls -d              | head -n -1 >> src/ERC1363/main.huff


sed -i "s/\[_APPROVAL_EVENT_SIGNATURE\]/__EVENT_HASH(Approval)/g" src/ERC1363/main.huff
sed -i "s/\[_TRANSFER_EVENT_SIGNATURE\]/__EVENT_HASH(Transfer)/g" src/ERC1363/main.huff
sed -i "s/\[SIG_onTransferReceived\]/__FUNC_SIG(\"onTransferReceived(address,address,uint256,bytes)\")/g" src/ERC1363/main.huff
sed -i "s/\[SIG_onApprovalReceived\]/__FUNC_SIG(\"onApprovalReceived(address,uint256,bytes)\")/g" src/ERC1363/main.huff


# sanity check
huffc src/mocks/PayableToken.huff

