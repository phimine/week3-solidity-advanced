// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Error
error IDOToken__ZeroAmount();
error IDOToken__ExceedMaxAmount();
error IDOToken__AleadyPurchased();

/**
 * @title IDO 允许项目团队通过去中心化交易所直接向投资者出售新代币，以筹集资金。
 * 购买代币、提现
 * @author Carl Fu
 * @notice
 */
contract IDOToken is ERC20("IDO Token", "IDO"), Ownable(msg.sender) {
    // Type Declaration
    // State Variable：IDO价格（对比USDT），最大购买量（USDT），USDT地址，购买账户
    uint256 private constant IDO_PRICE = 0.1 * 10 ** 18; // 0.1 USDT
    uint256 private constant MAX_BUY_AMOUNT = 100; // 100 USDT
    address private constant USDT_ADDRESS =
        0x606D35e5962EC494EAaf8FE3028ce722523486D2;
    mapping(address => uint256) private buyers;
    mapping(address => bool) public isBuyer;

    // Event: 购买代币、提现
    event Purchase(address indexed buyer, uint256 amount);
    event Withdraw(uint256 amount);

    // Modifier
    // Constructor
    // Functions
    // receive/fallback
    // external
    function purchase(uint256 amount) external {
        // Check: amount大于0、用户没购买过、amouunt小于MAX_BUY_AMOUNT
        if (amount <= 0) {
            revert IDOToken__ZeroAmount();
        }
        if (amount > MAX_BUY_AMOUNT) {
            revert IDOToken__ExceedMaxAmount();
        }
        if (isBuyer[msg.sender]) {
            revert IDOToken__AleadyPurchased();
        }

        // Effect: buyers、isBuyer
        buyers[msg.sender] = amount;
        isBuyer[msg.sender] = true;

        // Interaction: 从msg.sender转usdt到合约、向msg.sender铸造代币
        uint256 mintVal = (amount / IDO_PRICE) * 10 ** 18;
        IERC20(USDT_ADDRESS).transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, mintVal);

        emit Purchase(msg.sender, amount);
    }

    function withdraw() external onlyOwner {
        uint256 totalAmount = IERC20(USDT_ADDRESS).balanceOf(address(this));
        if (totalAmount <= 0) {
            revert IDOToken__ZeroAmount();
        }
        IERC20(USDT_ADDRESS).transfer(msg.sender, totalAmount);
        emit Withdraw(totalAmount);
    }
    // view/pure
}
