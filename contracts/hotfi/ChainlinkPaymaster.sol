// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable reason-string */

import "../core/BasePaymaster.sol";
import "../interfaces/UserOperation.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

/**
 * A sample paymaster that defines itself as a token to pay for gas.
 * The paymaster IS the token to use, since a paymaster cannot use an external contract.
 * Also, the exchange rate has to be fixed, since it can't reference an external Uniswap or other exchange contract.
 * subclass should override "getTokenValueOfEth" to provide actual token exchange rate, settable by the owner.
 * Known Limitation: this paymaster is exploitable when put into a batch with multiple ops (of different accounts):
 * - while a single op can't exploit the paymaster (if postOp fails to withdraw the tokens, the user's op is reverted,
 *   and then we know we can withdraw the tokens), multiple ops with different senders (all using this paymaster)
 *   in a batch can withdraw funds from 2nd and further ops, forcing the paymaster itself to pay (from its deposit)
 * - Possible workarounds are either use a more complex paymaster scheme (e.g. the DepositPaymaster) or
 *   to whitelist the account and the called method ids.
 */
contract ChainlinkPaymaster is BasePaymaster {

    using UserOperationLib for UserOperation;

    event OracleUpdated(address indexed oracle);

    //calculated cost of the postOp
    uint256 constant public COST_OF_POST = 20000;

    address public immutable theFactory;

    IERC20 private immutable feeToken;

    AggregatorV2V3Interface private immutable _tokenToEthFeed;

    uint256 private lastPrice;

    constructor(address accountFactory, address _entryPoint, address _feeToken, address tokenToEthFeed) BasePaymaster(IEntryPoint(_entryPoint)) {
        theFactory = accountFactory;
        feeToken = IERC20(_feeToken);
        _tokenToEthFeed = AggregatorV2V3Interface(tokenToEthFeed);
        unchecked {
            feeToken.approve(msg.sender, uint256(0) - 1);
        }
        lastPrice =  uint256(_tokenToEthFeed.latestAnswer());
    }

    function getTokenValueOfEth(uint256 ethOutput) internal view returns (uint256 tokenInput){
        uint _tokenDecimal = 10** IERC20Metadata(address(feeToken)).decimals();
        // input = output* decimals/price
        tokenInput = ethOutput * _tokenDecimal / lastPrice;
    }

    /**
      * validate the request:
      * if this is a constructor call, make sure it is a known account.
      * verify the sender has enough tokens.
      * (since the paymaster is also the token, there is no notion of "approval")
      */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 /*userOpHash*/, uint256 requiredPreFund)
    internal view override returns (bytes memory context, uint256 validationData) {
        uint256 tokenPrefund = getTokenValueOfEth(requiredPreFund);

        require(userOp.verificationGasLimit > COST_OF_POST, "TokenPaymaster: gas too low for postOp");

        if (userOp.initCode.length != 0) {
            _validateConstructor(userOp);
            require(feeToken.balanceOf(userOp.sender) >= tokenPrefund, "TokenPaymaster: no balance (pre-create)");
        } else {
            require(feeToken.balanceOf(userOp.sender) >= tokenPrefund, "TokenPaymaster: no balance");
        }

        require(feeToken.allowance(userOp.sender, address(this)) >= tokenPrefund, "TokenPaymaster: no allowance");
        uint256 gasPriceUserOp = userOp.gasPrice();
        return (abi.encode(userOp.sender, gasPriceUserOp), 0);
    }
    

    function transferOwnership(address newOwner) public virtual override onlyOwner{
        _transferOwnership(newOwner);
        unchecked {
            feeToken.approve(msg.sender, 0);
            feeToken.approve(newOwner, uint256(0) - 1);
        }
    }

    // when constructing an account, validate constructor code and parameters
    // we trust our factory (and that it doesn't have any other public methods)
    function _validateConstructor(UserOperation calldata userOp) internal virtual view {
        address factory = address(bytes20(userOp.initCode[0 : 20]));
        require(factory == theFactory, "TokenPaymaster: wrong account factory");
    }

    /**
     * actual charge of user.
     * this method will be called just after the user's TX with mode==OpSucceeded|OpReverted (account pays in both cases)
     * BUT: if the user changed its balance in a way that will cause  postOp to revert, then it gets called again, after reverting
     * the user's TX , back to the state it was before the transaction started (before the validatePaymasterUserOp),
     * and the transaction should succeed there.
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        //we don't really care about the mode, we just pay the gas with the user's tokens.
        (mode);
        lastPrice =  uint256(_tokenToEthFeed.latestAnswer());
        (address sender, uint256 gasPricePostOp) = abi.decode(context, (address, uint256));
        uint256 charge = getTokenValueOfEth(actualGasCost + COST_OF_POST * gasPricePostOp);
        //actualGasCost is known to be no larger than the above requiredPreFund, so the transfer should succeed.
        feeToken.transferFrom(sender, address(this), charge);
    }
}
