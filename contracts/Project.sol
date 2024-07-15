// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Error
error Project__NotCreator();
error Project__NotFail();
error Project__NotOngoing();
error Project__NotSuccess();
error Project__NotAfterDeadline();
error Project__NotBeforeDeadline();
error Project__NoDonation();

/**
 * @title 去中心化众筹平台
 * 构建一个去中心化的众筹平台，用户可以创建众筹项目，其他用户可以对项目进行捐款。
 * 在项目截止日期后，根据筹款目标是否达到，项目会被标记为成功或失败。
 * 项目成功时，创建者可以提取资金；项目失败时，捐款者可以撤回他们的资金。
 * @author Carl Fu
 * @notice
 */
contract Project {
    // Type Declaration: 项目状态（Ongoing、Success、Fail）、筹款（address、amount）
    enum State {
        Ongoing,
        Success,
        Fail
    }

    struct Donation {
        address donor;
        uint256 amount;
    }

    // State Variable：创建者、项目描述、目标筹资、截止日期；当前筹资、筹款列表、项目状态
    address private i_creator;
    string private description;
    uint256 private goalAmount;
    uint256 private deadline;

    uint256 private currentAmount;
    Donation[] private donations;
    State private state;

    // Event：捐款、提取、撤资
    event Donate(address indexed donor, uint256 amount);
    event FundsWithdraw(address indexed creator, uint256 amount);
    event FundsRefund(address indexed donar, uint256 amount);
    event ProjectStateChanged(State state);

    // Modifier：onlyCreator、onlyOngoing、onlyAfterDeadline
    modifier onlyCreator() {
        if (msg.sender != i_creator) {
            revert Project__NotCreator();
        }
        _;
    }

    modifier onlyOngoing() {
        if (state != State.Ongoing) {
            revert Project__NotOngoing();
        }
        _;
    }

    modifier onlySuccess() {
        if (state != State.Success) {
            revert Project__NotSuccess();
        }
        _;
    }

    modifier onlyFail() {
        if (state != State.Fail) {
            revert Project__NotFail();
        }
        _;
    }

    modifier onlyAfterDeadline() {
        if (block.timestamp < deadline) {
            revert Project__NotAfterDeadline();
        }
        _;
    }

    modifier onlyBeforeDeadline() {
        if (block.timestamp >= deadline) {
            revert Project__NotBeforeDeadline();
        }
        _;
    }

    // Constructor
    constructor() {}

    function initialize(
        address _creator,
        string memory _description,
        uint256 _goalAmount,
        uint256 _duration
    ) public {
        i_creator = _creator;
        description = _description;
        goalAmount = _goalAmount;
        deadline = block.timestamp + _duration;
        state = State.Ongoing;
    }

    // Functions：捐款、提款、撤资、更新项目状态
    // receive/fallback
    // external
    function donate() external payable onlyOngoing onlyBeforeDeadline {
        // Check: 状态Ongoing、在deadline之前
        // Effect: 记录捐款、目前筹款增加
        donations.push(Donation({donor: msg.sender, amount: msg.value}));
        currentAmount += msg.value;

        // Interaction
        emit Donate(msg.sender, msg.value);
    }

    function withdraw() external onlyCreator onlyAfterDeadline onlySuccess {
        // Check：状态Success、创建者调用、在deadline之后
        // Effect：目前筹款清空？
        // Interaction：将款项转给创建者账户
        payable(i_creator).transfer(currentAmount);

        emit FundsWithdraw(i_creator, currentAmount);
    }

    function refund() external onlyFail onlyAfterDeadline {
        // Check： 状态Fail、在deadline之后
        // 计算调用者所有捐款，所有捐款大于0
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < donations.length; ) {
            Donation storage donation = donations[i];
            if (donation.donor == msg.sender) {
                totalAmount += donation.amount;
            }
            unchecked {
                ++i;
            }
        }
        if (totalAmount == 0) {
            revert Project__NoDonation();
        }
        // Effect

        // Interaction: 将所有捐款退还给捐赠者
        payable(msg.sender).transfer(totalAmount);
        emit FundsRefund(msg.sender, totalAmount);
    }

    function updateState() external onlyCreator onlyOngoing onlyAfterDeadline {
        // Check：调用者是creator、进行中的状态、在deadline之前
        // Effect：根据目标更新state
        if (currentAmount >= goalAmount) {
            state = State.Success;
        } else {
            state = State.Fail;
        }

        // Interaction
        emit ProjectStateChanged(state);
    }

    // view/pure
    function getCreator() public view returns (address) {
        return i_creator;
    }

    function getGoalAmount() public view returns (uint256) {
        return goalAmount;
    }

    function getCurrentAmount() public view returns (uint256) {
        return currentAmount;
    }

    function getState() public view returns (State) {
        return state;
    }

    function getDeadline() public view returns (uint256) {
        return deadline;
    }
}
