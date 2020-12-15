// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../interfaces/flamincome/Controller.sol";
import "../../interfaces/flamincome/Vault.sol";

import "./StrategyBaseline.sol";

contract StrategyBaselineAmmonia is StrategyBaseline {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    constructor(address _want, address _controller)
        public
        StrategyBaseline(_want, _controller)
    {}

    function deposit(bool fromNVault) public override {}

    function withdraw(IERC20 _asset)
        external
        override
        returns (uint256 balance)
    {
        require(msg.sender == controller, "!controller");
        require(want != address(_asset), "want");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(controller, balance);
    }

    function withdrawF(uint256 _amount) external virtual override {
        require(msg.sender == controller, "!controller");
        uint256 _balance = IERC20(want).balanceOf(address(this)).sub(balanceOfVaultN);
        _amount = Math.min(_balance, _amount);
        address vault = Controller(controller).vaultsF(address(want));
        require(vault != address(0), "!vault");
        IERC20(want).safeTransfer(vault, _amount);
    }
    
    function withdrawN(uint256 _amount) external virtual override {
        require(msg.sender == controller, "!controller");
        require(_amount <= balanceOfVaultN, "!amount");
        uint256 _balance = IERC20(want).balanceOf(address(this));
        require(balanceOfVaultN <= _balance, "!balance");
        address vault = Controller(controller).vaultsN(address(want));
        require(vault != address(0), "!vault");
        balanceOfVaultN = balanceOfVaultN.sub(_amount);
        IERC20(want).safeTransfer(vault, _amount);
    }

    function withdrawAllF() external override returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        balance = IERC20(want).balanceOf(address(this)).sub(balanceOfVaultN);
        address vault = Controller(controller).vaultsF(address(want));
        require(vault != address(0), "!vault");
        IERC20(want).safeTransfer(vault, balance);
    }
    
    function withdrawAllN() external override returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        balance = balanceOfVaultN;
        address vault = Controller(controller).vaultsN(address(want));
        require(vault != address(0), "!vault");
        balanceOfVaultN = 0;
        IERC20(want).safeTransfer(vault, balance);
    }

    function balanceOfF() public override view returns (uint256) {
        return IERC20(want).balanceOf(address(this)).sub(balanceOfVaultN);
    }
    
    function balanceOfN() public override view returns (uint256) {
        return balanceOfVaultN;
    }
}
