balls src/ERC20/Metadata.balls -d --output-path src/ERC20/Metadata.huff
balls src/ERC20/Approve-Allowance.balls -d --output-path src/ERC20/Approve-Allowance.huff 
balls src/ERC20/Transfers.balls -d --output-path src/ERC20/Transfers.huff
balls src/ERC20/Mint-Burn.balls -d --output-path src/ERC20/Mint-Burn.huff

cat src/ERC20/template.huff           > src/ERC20/main.huff
echo "\n"                            >> src/ERC20/main.huff
cat src/ERC20/Metadata.huff          >> src/ERC20/main.huff
echo "\n"                            >> src/ERC20/main.huff
cat src/ERC20/Approve-Allowance.huff >> src/ERC20/main.huff
echo "\n"                            >> src/ERC20/main.huff
cat src/ERC20/Transfers.huff         >> src/ERC20/main.huff
echo "\n"                            >> src/ERC20/main.huff
cat src/ERC20/Mint-Burn.huff         >> src/ERC20/main.huff

sed -i "" "s/\[_APPROVAL_EVENT_SIGNATURE\]/__EVENT_HASH(Approval)/g" src/ERC20/main.huff
sed -i "" "s/\[_TRANSFER_EVENT_SIGNATURE\]/__EVENT_HASH(Transfer)/g" src/ERC20/main.huff
sed -i "" "s/\/\/ balls-insert-start/ /g" src/ERC20/main.huff
sed -i "" "s/\/\/ balls-insert-end/ /g" src/ERC20/main.huff


# sanity check
huffc src/mocks/TokenMock.huff
