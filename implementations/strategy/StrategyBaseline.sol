// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../interfaces/flamincome/Controller.sol";

abstract contract StrategyBaseline {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public want;
    address public governance;
    address public controller;
    uint256 public balanceOfVaultN;

    constructor(address _want, address _controller) public {
        governance = msg.sender;
        controller = _controller;
        want = _want;
    }

    function deposit(bool fromNVault) public virtual;

    function withdraw(IERC20 _asset) external virtual returns (uint256 balance);

    function withdrawF(uint256 _amount) external virtual;
    
    function withdrawN(uint256 _amount) external virtual;

    function withdrawAllF() external virtual returns (uint256);
    
    function withdrawAllN() external virtual returns (uint256);

    function balanceOfF() public virtual view returns (uint256);
    
    function balanceOfN() public virtual view returns (uint256);

    function SetGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function SetController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }
}
