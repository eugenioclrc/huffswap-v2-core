cat src/ERC20/template.huff > src/ERC20/main.huff
balls src/ERC20/Metadata.balls -d           | head -n -1 >> src/ERC20/main.huff
balls src/ERC20/Approve-Allowance.balls -d  | head -n -1 >> src/ERC20/main.huff
cat src/ERC20/Approve-Allowance.huff                     >> src/ERC20/main.huff
balls src/ERC20/Transfers.balls -d          | head -n -1 >> src/ERC20/main.huff
balls src/ERC20/Mint-Burn.balls -d          | head -n -1 >> src/ERC20/main.huff

sed -i "s/\[_APPROVAL_EVENT_SIGNATURE\]/__EVENT_HASH(Approval)/g" src/ERC20/main.huff
sed -i "s/\[_TRANSFER_EVENT_SIGNATURE\]/__EVENT_HASH(Transfer)/g" src/ERC20/main.huff

# sanity check
huffc src/mocks/TokenMock.huff
