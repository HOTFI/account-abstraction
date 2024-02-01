// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./InitializableAccount.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * A factory contract for InitializableAccount
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract InitializableAccountFactory is Ownable{
    InitializableAccount public immutable accountImplementation;

    bytes[] public initOps;

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new InitializableAccount(_entryPoint);
    }

    /**
     * Initiate the user options which will be executed when account create
     * Note user account will execuute erc20 approve function to
     * approve tokens to paymasters when they deployed.
     * The Opdatas only can be initiated once by the owner
     */
    function init(address[] calldata tokens, address[] calldata paymasters) external onlyOwner{
        require(initOps.length == 0, "Factory was initiated");
        unchecked {
            uint256 value = uint256(0) - 1;
            for (uint256 index = 0; index < tokens.length; ++index) {
                bytes memory opData = abi.encode(tokens[index], 0, abi.encodeWithSignature("approve(address,uint256)", paymasters[index], value));
                initOps.push(opData);
            }
        }
        
    }


    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(address owner, uint256 salt) public returns (InitializableAccount ret) {
        address addr = getAddress(owner, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return InitializableAccount(payable(addr));
        }
        ret = InitializableAccount(payable(new ERC1967Proxy{salt : bytes32(salt)}(
                address(accountImplementation),
                abi.encodeCall(InitializableAccount.initialize, (owner, initOps))
            )));
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(address owner, uint256 salt) public view returns (address) {
        return Create2.computeAddress(bytes32(salt), keccak256(abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    address(accountImplementation),
                    abi.encodeCall(InitializableAccount.initialize, (owner, initOps))
                )
            )));
    }
}
