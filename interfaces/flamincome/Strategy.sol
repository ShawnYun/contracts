// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

interface Strategy {
    function want() external view returns (address);
    function deposit(bool) external;
    function withdraw(address) external;
    function withdrawF(uint) external;
    function withdrawN(uint) external;
    function withdrawAllF() external returns (uint);
    function withdrawAllN() external returns (uint);
    function balanceOfF() external view returns (uint);
    function balanceOfN() external view returns (uint);
}
