// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../interfaces/flamincome/Controller.sol";
import "../../interfaces/flamincome/Vault.sol";

import "./StrategyBaseline.sol";

abstract contract StrategyBaselineCarbon is StrategyBaseline {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public feen = 5e15;
    uint256 public constant feed = 1e18;

    constructor(address _want, address _controller)
        public
        StrategyBaseline(_want, _controller)
    {}

    function DepositToken(uint256 _amount) internal virtual;

    function WithdrawToken(uint256 _amount) internal virtual;

    function Harvest() external virtual;

    function GetDeposited() public virtual view returns (uint256);

    function deposit(bool fromNVault) public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            if (fromNVault) {
                balanceOfVaultN = balanceOfVaultN.add(_want);
            }
            DepositToken(_want);
        }
    }

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

    function withdrawF(uint256 _aw) external override {
        require(msg.sender == controller, "!controller");
        uint256 _w = IERC20(want).balanceOf(address(this));
        if (_w < _aw) {
            WithdrawToken(_aw.sub(_w));
        }
        _w = IERC20(want).balanceOf(address(this));
        address _vault = Controller(controller).vaultsF(address(want));
        require(_vault != address(0), "!vault");
        IERC20(want).safeTransfer(_vault, Math.min(_aw, _w));
    }

    function withdrawN(uint256 _aw) external override {
        require(msg.sender == controller || msg.sender == address(this), "!controller");
        uint256 _w = IERC20(want).balanceOf(address(this));
        if (_w < _aw) {
            WithdrawToken(_aw.sub(_w));
        }
        _w = IERC20(want).balanceOf(address(this));
        address _vault = Controller(controller).vaultsN(address(want));
        require(_vault != address(0), "!vault");
        uint256 amount = Math.min(_aw, _w);
        balanceOfVaultN = balanceOfVaultN.sub(amount);
        IERC20(want).safeTransfer(_vault, amount);
    }

    function withdrawAllF() external override returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        WithdrawToken(GetDeposited());
        balance = IERC20(want).balanceOf(address(this)).sub(balanceOfVaultN);
        address _vault = Controller(controller).vaultsF(address(want));
        require(_vault != address(0), "!vault");
        IERC20(want).safeTransfer(_vault, balance);
    }

    function withdrawAllN() external override returns (uint256 balance) {
        balance = balanceOfVaultN;
        this.withdrawN(balance);       
    }

    function balanceOfF() public override view returns (uint256) {
        uint256 _want = IERC20(want).balanceOf(address(this));
        return GetDeposited().add(_want).sub(balanceOfVaultN);
    }

    function balanceOfN() public override view returns (uint256) {
        return balanceOfVaultN;
    }

    function setFeeN(uint256 _feen) external {
        require(msg.sender == governance, "!governance");
        feen = _feen;
    }
}
