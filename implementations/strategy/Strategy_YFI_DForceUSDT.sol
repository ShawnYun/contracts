// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../interfaces/flamincome/Controller.sol";
import "../../interfaces/flamincome/Vault.sol";
import "../../interfaces/external/DForce.sol";
import "../../interfaces/external/Uniswap.sol";


contract Strategy_YFI_DForceUSDT {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    address constant public want = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address constant public d = address(0x868277d475E0e475E38EC5CdA2d9C83B5E1D9fc8);
    address constant public pool = address(0x324EebDAa45829c6A8eE903aFBc7B61AF48538df);
    address constant public df = address(0x431ad2ff6a9C365805eBaD47Ee021148d6f7DBe0);
    address constant public uni = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address constant public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // used for df <> weth <> usdc route
    
    uint public performanceFee = 5000;
    uint constant public performanceMax = 10000;

    uint public withdrawalFeeF = 50;
    uint public withdrawalFeeN = 20;
    uint constant public withdrawalMax = 10000;

    uint256 public balanceOfVaultN = 0;
    
    address public governance;
    address public controller;
    address public strategist;
    
    constructor(address _controller) public {
        governance = msg.sender;
        strategist = msg.sender;
        controller = _controller;
    }
    
    function getName() external pure returns (string memory) {
        return "StrategyDForceUSDT";
    }
    
    function setStrategist(address _strategist) external {
        require(msg.sender == governance, "!governance");
        strategist = _strategist;
    }
    
    function setWithdrawalFeeF(uint _withdrawalFee) external {
        require(msg.sender == governance, "!governance");
        withdrawalFeeF = _withdrawalFee;
    }

    function setWithdrawalFeeN(uint _withdrawalFee) external {
        require(msg.sender == governance, "!governance");
        withdrawalFeeN = _withdrawalFee;
    }
    
    function setPerformanceFee(uint _performanceFee) external {
        require(msg.sender == governance, "!governance");
        performanceFee = _performanceFee;
    }
    
    function deposit(bool fromNVault) public {
        uint _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            if (fromNVault) {
                balanceOfVaultN = balanceOfVaultN.add(_want);
            }
            IERC20(want).safeApprove(d, 0);
            IERC20(want).safeApprove(d, _want);
            IDERC20(d).mint(address(this), _want);
        }
        
        uint _d = IERC20(d).balanceOf(address(this));
        if (_d > 0) {
            IERC20(d).safeApprove(pool, 0);
            IERC20(d).safeApprove(pool, _d);
            IDRewards(pool).stake(_d);
        }       
    }
    
    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint balance) {
        require(msg.sender == controller, "!controller");
        require(want != address(_asset), "want");
        require(d != address(_asset), "d");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(controller, balance);
    }
    
    // Withdraw partial funds, normally used with a vault withdrawal
    function withdrawF(uint _amount) external {
        require(msg.sender == controller, "!controller");
        uint _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }
        
        uint _fee = _amount.mul(withdrawalFeeF).div(withdrawalMax);
               
        IERC20(want).safeTransfer(Controller(controller).rewards(), _fee);
        address _vault = Controller(controller).vaultsF(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        _amount = _amount.sub(_fee);
        IERC20(want).safeTransfer(_vault, _amount);
    }

    function withdrawN(uint _amount) external {
        require(msg.sender == controller || msg.sender == address(this), "!controller");

        balanceOfVaultN = balanceOfVaultN.sub(_amount);

        uint _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }
        
        uint _fee = _amount.mul(withdrawalFeeN).div(withdrawalMax);
               
        IERC20(want).safeTransfer(Controller(controller).rewards(), _fee);
        address _vault = Controller(controller).vaultsN(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        
        _amount = _amount.sub(_fee);
        IERC20(want).safeTransfer(_vault, _amount);
    }
    
    // Withdraw all funds, normally used when migrating strategies
    function withdrawAllF() external returns (uint balance) {
        require(msg.sender == controller, "!controller");
        _withdrawAll();   
        
        balance = IERC20(want).balanceOf(address(this));
        
        address _vault = Controller(controller).vaultsF(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        balance = balance.sub(balanceOfVaultN);
        IERC20(want).safeTransfer(_vault, balance);
    }

    function withdrawAllN() external returns (uint balance) {
        balance = balanceOfVaultN;
        this.withdrawN(balance);
    }
    
    function _withdrawAll() internal {
        IDRewards(pool).exit();
        uint _d = IERC20(d).balanceOf(address(this));
        if (_d > 0) {
            IDERC20(d).redeem(address(this),_d);
        }
    }
    
    function harvest() public {
        require(msg.sender == strategist || msg.sender == governance, "!authorized");
        IDRewards(pool).getReward();
        uint _df = IERC20(df).balanceOf(address(this));
        if (_df > 0) {
            IERC20(df).safeApprove(uni, 0);
            IERC20(df).safeApprove(uni, _df);
            
            address[] memory path = new address[](3);
            path[0] = df;
            path[1] = weth;
            path[2] = want;
            
            IUniV2(uni).swapExactTokensForTokens(_df, uint(0), path, address(this), now.add(1800));
        }
        uint _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            uint _fee = _want.mul(performanceFee).div(performanceMax);
            IERC20(want).safeTransfer(Controller(controller).rewards(), _fee);
            deposit(false);
        }
    }
    
    function _withdrawSome(uint256 _amount) internal returns (uint) {
        uint _d = _amount.mul(1e18).div(IDERC20(d).getExchangeRate());
        uint _before = IERC20(d).balanceOf(address(this));
        IDRewards(pool).withdraw(_d);
        uint _after = IERC20(d).balanceOf(address(this));
        uint _withdrew = _after.sub(_before);
        _before = IERC20(want).balanceOf(address(this));
        IDERC20(d).redeem(address(this), _withdrew);
        _after = IERC20(want).balanceOf(address(this));
        _withdrew = _after.sub(_before);
        return _withdrew;
    }
    
    function balanceOfWant() public view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }
    
    function balanceOfPool() public view returns (uint) {
        return (IDRewards(pool).balanceOf(address(this))).mul(IDERC20(d).getExchangeRate()).div(1e18);
    }
    
    function getExchangeRate() public view returns (uint) {
        return IDERC20(d).getExchangeRate();
    }
    
    function balanceOfD() public view returns (uint) {
        return IDERC20(d).getTokenBalance(address(this));
    }
    
    function balanceOf() public view returns (uint) {
        return balanceOfWant()
               .add(balanceOfD())
               .add(balanceOfPool());
    }

    function balanceOfF() public view returns (uint) {
        return balanceOf().sub(balanceOfVaultN);
    }

    function balanceOfN() public view returns (uint) {
        return balanceOfVaultN;
    }
    
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }
    
    function setController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }
}