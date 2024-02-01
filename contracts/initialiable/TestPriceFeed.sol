// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestPriceFeed is Ownable, AggregatorInterface{

    struct Answer{
        int256 answer;
        uint256 timestamp;
    }

    uint256 private _latestRound;

    mapping(uint256 => Answer) private _answers;

    constructor(){
        _answers[_latestRound].answer = 0.00008 ether;
        _answers[_latestRound].timestamp = block.timestamp;
    }

    function latestAnswer() external view returns (int256){
        return _answers[_latestRound].answer;
    }

    function latestTimestamp() external view returns (uint256){
        return _answers[_latestRound].timestamp;
    }

    function latestRound() external view returns (uint256){
        return _latestRound;
    }

    function getAnswer(uint256 roundId) external view returns (int256){
        return _answers[roundId].answer;
    }

    function getTimestamp(uint256 roundId) external view returns (uint256){
        return _answers[roundId].timestamp;
    }

    function feed(int256 answer) external onlyOwner{
        ++_latestRound;
        _answers[_latestRound].answer = answer;
        _answers[_latestRound].timestamp = block.timestamp;
    }
}