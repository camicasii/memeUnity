// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../utils/math/SafeMath.sol";
import "../utils/Ownable.sol";
import "../utils/Pausable.sol";
import "../token/IERC20.sol";

contract HoldersRoi is Ownable, Pausable {
    using SafeMath for uint256;
    IERC20 public token;

    uint256 internal constant FEE = 100;
    uint256 internal constant REFERRAL_PERCENTS = 10;
    uint256 internal constant PERCENTS_DIVIDER = 1000;
    uint256 internal constant TIME_UPDATE = 30 seconds;
    uint256 internal constant uplineLevels = 10;

    uint256 internal usersID;

    uint256 public lastBalanceUpdate;
    uint256 public rewardPerUser;
    uint256 public totalInvest;
    uint256 public totalWithdrawn;
    uint256 public currentTotalBonus;

    event Newbie(address user);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawnRefBonus(address indexed user, uint256 amount);
    event RefBonus(
        address indexed referrer,
        address indexed referral,
        uint256 indexed level,
        uint256 amount
    );
    event NewDeposit(address indexed user, uint256 amount);

    mapping(address => User) public users;
    mapping(uint256 => address) private usersAutoPayment;

    struct User {
        address userAddress;
        address referrer;
        uint256 totalInvest;
        uint256 totalWithdrawn;
        uint256 bonus;
    }

    constructor(IERC20 token_) public {
        token = token_;
        lastBalanceUpdate = block.timestamp;
        _pause();
    }

    modifier contractHasfunds_() {
        require(getContractBalance() > 0, "insufficient funds");
        _;
    }

    modifier checkUser_() {
        User memory user_ = users[msg.sender];
        require(isUser(user_), "not is user");
        _;
    }

    function unpause() external whenPaused returns (bool) {
        _unpause();
        return true;
    }

    function isUser(User memory user_) internal pure returns (bool) {
        return (user_.userAddress != address(0));
    }

    function register(address referrer, uint256 depAmount) external {
        token.transferFrom(msg.sender, address(this), depAmount);
        token.transfer(owner(), depAmount.mul(FEE).div(PERCENTS_DIVIDER));

        User storage user = users[msg.sender];
        User memory uplineHandler = users[referrer];

        if (user.referrer == address(0)) {
            if (!isUser(user)) {
                usersAutoPayment[usersID] = msg.sender;
                user.userAddress = msg.sender;
                usersID++;
                emit Newbie(msg.sender);
            }

            if (
                referrer == owner() ||
                (isUser(uplineHandler) && referrer != msg.sender)
            ) user.referrer = referrer;
        }

        if (user.referrer != address(0)) {
            address upline = user.referrer;
            address lastUpline = msg.sender;
            uint256 uplineReward =
                depAmount.mul(REFERRAL_PERCENTS).div(PERCENTS_DIVIDER);
            for (uint256 i = 0; i < uplineLevels; i++) {
                if (upline != address(0) && lastUpline != upline) {
                    User storage userUpline = users[upline];
                    userUpline.bonus = userUpline.bonus.add(uplineReward);
                    currentTotalBonus = currentTotalBonus.add(uplineReward);
                    emit RefBonus(upline, msg.sender, i, uplineReward);
                    lastUpline = upline;
                    upline = userUpline.referrer;
                } else break;
            }
        }
        user.totalInvest = user.totalInvest.add(depAmount);
        totalInvest = totalInvest.add(depAmount);
        updatebaseReward();
        emit NewDeposit(msg.sender, depAmount);
    }

    function userData(address userAddress)
        external
        view
        returns (User memory user_)
    {
        User memory user = users[userAddress];
        user_ = user;
    }

    function getContractBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function usersCount() public view returns (uint256) {
        return usersID;
    }

    function updatebaseReward() internal returns (bool) {
        if (block.timestamp.sub(lastBalanceUpdate) >= TIME_UPDATE) {
            uint256 currentBalance =
                getContractBalance().sub(currentTotalBonus);
            rewardPerUser = currentBalance.div(usersCount());
            lastBalanceUpdate = block.timestamp;
            return true;
        }
        return false;
    }

    function referralWithdraw()
        external
        contractHasfunds_
        whenNotPaused
        checkUser_
        returns (bool)
    {
        User storage user = users[msg.sender];
        uint256 amount = user.bonus;
        require(amount > 0, "you do not bonus currently");
        user.bonus = 0;
        token.transfer(msg.sender, amount);
        user.totalWithdrawn = user.totalWithdrawn.add(amount);
        currentTotalBonus = currentTotalBonus.sub(amount);
        totalWithdrawn = totalWithdrawn.add(amount);
        emit WithdrawnRefBonus(msg.sender, amount);
        return true;
    }

    function withdraw()
        external
        contractHasfunds_
        whenNotPaused
        checkUser_
        returns (bool)
    {
        if (updatebaseReward()) {
            uint256 currentBalance =
                getContractBalance().sub(currentTotalBonus);
            for (uint256 i = 0; i < usersID; i++) {
                User storage user = users[usersAutoPayment[i]];
                user.totalWithdrawn = user.totalWithdrawn.add(rewardPerUser);
                token.transfer(user.userAddress, rewardPerUser);
                emit Withdrawn(user.userAddress, rewardPerUser);
            }
            totalWithdrawn = totalWithdrawn.add(currentBalance);
            return true;
        }
        return false;
    }
}
