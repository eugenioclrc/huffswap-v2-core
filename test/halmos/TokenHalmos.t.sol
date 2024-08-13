// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

interface IToken {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    error InsufficientBalance();
    error InsufficientAllowance();
    error Overflow();
}

contract TokenHalmosTest is Test, SymTest {
    IToken token;

    function setUp() public {
        
        // source 
        bytes memory bytecode =
            hex"6103d180600a3d393df360003560e01c806306fdde031461008c57806395d89b41146100ab578063313ce567146100c6578063095ea7b3146100d1578063dd62ed3e1461011b57806318160ddd1461013657806370a0823114610156578063a9059cbb1461029257806323b872dd1461030757806340c10f19146101635780639dc29fac146101fa5763ffffffff6000526004601cfd5b6f0f4875666653776170205061697256326020600052602f5260606000f35b6b0b48554646535741502d56326020600052602b5260606000f35b602060006012600052f35b602060016000600435602435600081833360205260005260406000205552337f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b92560206000a3526000f35b60206024356004356020526000526040600020546000526000f35b602074010000000000000000000000000000000000000000546000526000f35b6020600435546000526000f35b60243560043573ffffffffffffffffffffffffffffffffffffffff1690600081838374010000000000000000000000000000000000000000548101908110156101b4576335278d126000526004601cfd5b7401000000000000000000000000000000000000000055540183555260007fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef60206000a3005b60243560043573ffffffffffffffffffffffffffffffffffffffff16600091806000528181740100000000000000000000000000000000000000005403740100000000000000000000000000000000000000005554908103908111156102685763f4d678b86000526004601cfd5b81557fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef60206000a3005b6001600073ffffffffffffffffffffffffffffffffffffffff60043516337fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef60206000602435803354908103908111156102f45763f4d678b86000526004601cfd5b3355808654018655600052a35260206000f35b600160443573ffffffffffffffffffffffffffffffffffffffff6024351673ffffffffffffffffffffffffffffffffffffffff600435168233826020526000526040600020805490816000191461037657828290810390811115610373576313be252b6000526004601cfd5b81555b5050509091808254908103908111156103975763f4d678b86000526004601cfd5b81600052825582540182557fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef60206000a360005260206000f3";
        /// @solidity memory-safe-assembly
        IToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
                
        token = IToken(_token);
    }

    function check_metadata() public {
        assert(keccak256(abi.encode(token.symbol())) == keccak256(abi.encode("HUFFSWAP-V2")));
        assert(keccak256(abi.encode(token.name())) == keccak256(abi.encode("HuffSwap PairV2")));
        assert(token.decimals() == 18);
    }

    function check_allowance(address owner, address spender, uint256 amount) public {
        assert(token.allowance(owner, spender) == 0);
        
        vm.prank(owner);
        assert(token.approve(spender, amount));

        assert(token.allowance(owner, spender) == amount);
    }

    function check_transfer(address from, address to, uint256 amount) public {
        assert(token.balanceOf(from) == 0);
        assert(token.balanceOf(to) == 0);

        vm.prank(from);
        token.mint(from, amount);
        assert(token.balanceOf(from) == amount);

        assert(token.transfer(to, amount));
        if(from != to) {
            assert(token.balanceOf(from) == 0);
            assert(token.balanceOf(to) == amount);
        } else {
            assert(token.balanceOf(from) == amount);
        }
    }

    function check_transferFrom(address owner, address spender, address to, uint256 amount) public {
        vm.assume(owner != address(0));
        vm.assume(spender != address(0));
        assert(token.balanceOf(owner) == 0);
        assert(token.balanceOf(to) == 0);

        vm.prank(owner);
        token.mint(owner, amount);
        assert(token.balanceOf(owner) == amount);

        assert(token.approve(spender, amount));
        assert(token.allowance(owner, spender) == amount);

        vm.prank(spender);
        assert(token.transferFrom(owner, to, amount));

        if(owner != to) {
            assert(token.balanceOf(owner) == 0);
            assert(token.balanceOf(to) == amount);
        } else {
            assert(token.balanceOf(owner) == amount);
        }

    }

}
