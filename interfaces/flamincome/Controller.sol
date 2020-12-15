// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

interface Controller {
    function strategist() external view returns (address);
    function vaultsN(address) external view returns (address);
    function vaultsF(address) external view returns (address);
    function rewards() external view returns (address);
    function balanceOf(address) external view returns (uint);
    function withdraw(address, uint) external;
    function earn(address, uint) external;
}
