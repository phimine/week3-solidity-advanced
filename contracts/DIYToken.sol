// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Error
error DIYToken__NotOwner();
error DIYToken__InvalidAmount();
error DIYToken__InvalidAccount();
error DIYToken__InsuffienceAmount();
error DIYToken__InsuffienceAllowanceAmount();

/**
 * @title 自定义的ERC20 token
 * @author Carl Fu
 * @notice
 */
contract DIYToken {
    // Tyep Declaration
    // State Variable: owner、名称、符号、小数点位数、总量
    address private immutable i_owner;
    string private name;
    string private symbol;
    uint256 private constant DECIMALS = 18;
    uint256 private totalSupply;

    mapping(address => uint256) private balances;
    // 授权额度：address 到 address + amount
    mapping(address => mapping(address => uint256)) private allowances;

    // Event
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed delegator,
        uint256 amount
    );

    // Modifier
    modifier onlyOwner() {
        if (i_owner != msg.sender) {
            revert DIYToken__NotOwner();
        }
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount <= 0) {
            revert DIYToken__InvalidAmount();
        }
        _;
    }

    modifier validAccount(address account) {
        if (account == address(0)) {
            revert DIYToken__InvalidAccount();
        }
        _;
    }

    modifier enoughAmount(address account, uint256 amount) {
        if (balances[account] < amount) {
            revert DIYToken__InsuffienceAmount();
        }
        _;
    }

    // Constructor
    constructor() {
        name = "DIYToken";
        symbol = "DIY";
        i_owner = msg.sender;
    }

    // Functions：代币铸造、销毁、转账、授权
    // external

    function approve(
        address account,
        uint256 amount
    ) public validAmount(amount) {
        // Check：amount大于0、amount小于owner的余额、account可用余额小于owner的余额-amount
        uint256 totalAmount = balances[msg.sender];
        uint256 curApprovedAmount = allowances[msg.sender][account];
        if (amount + curApprovedAmount > totalAmount) {
            revert DIYToken__InsuffienceAmount();
        }

        // Effect：allowance增加
        allowances[msg.sender][account] = curApprovedAmount + amount;

        // Interaction
        emit Approval(msg.sender, account, amount);
    }

    /**
     * 向目标地址转移代币
     * @param to 目标账号
     * @param amount 数量
     */
    function transfer(address to, uint256 amount) public validAmount(amount) {
        // Check：msg.sender的余额大于amount
        if (balances[msg.sender] < amount) {
            revert DIYToken__InvalidAmount();
        }

        // Effect：msg.sender余额减少、to余额增加
        balances[msg.sender] -= amount;
        balances[to] += amount;

        // Interaction
        emit Transfer(msg.sender, to, amount);
    }

    /**
     * 从一个地址转向另一个地址代币（需要实现授权）
     * @param from from账号
     * @param to to账号
     * @param amount 数量
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public validAmount(amount) {
        // Check: from的余额大于amount、from授权msg.sender的数量大于amount、from和msg.sender相同时调用transfer()
        if (from == msg.sender) {
            transfer(to, amount);
            return;
        }
        if (balances[from] < amount) {
            revert DIYToken__InsuffienceAmount();
        }

        if (allowances[from][msg.sender] < amount) {
            revert DIYToken__InsuffienceAllowanceAmount();
        }

        // Effect：from余额减少、to余额增加、msg.sender授权减少
        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
    }

    /**
     * 指定地址增发代币
     * @param account 地址
     * @param amount 增发数量
     */
    function mint(
        address account,
        uint256 amount
    ) external onlyOwner validAmount(amount) validAccount(account) {
        // Check: 调用者必须是owner、增发amount大于0、地址account不能为0

        // Effect: 指定地址的余额增加、代币总量增加
        balances[account] += amount;
        totalSupply += amount;

        // Interaction
        emit Transfer(address(0), account, amount);
    }

    function burn(
        address account,
        uint256 amount
    )
        external
        onlyOwner
        validAmount(amount)
        validAccount(account)
        enoughAmount(account, amount)
    {
        // Check：调用者必须是owner、amount大于0、地址account不能为0、account余额大于amount
        // Effect：指定地址的余额减少、代币总量减少
        balances[account] -= amount;
        totalSupply -= amount;

        // Interaction
        emit Transfer(account, address(0), amount);
    }

    // internal/private
    // view/pure
    function getTotalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function getName() public view returns (string memory) {
        return name;
    }

    function getSymbol() public view returns (string memory) {
        return symbol;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function allowanceOf(
        address owner,
        address account
    ) public view returns (uint256) {
        return allowances[owner][account];
    }

    function getDecimals() public pure returns (uint256) {
        return DECIMALS;
    }
}
