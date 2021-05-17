// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../utils/math/SafeMath.sol";
import "../utils/Ownable.sol";
import "../utils/Pausable.sol";
import "../token/IERC20.sol";

contract HoldersRoi is Ownable, Pausable {


using SafeMath for uint256;
	IERC20 public token;
	
	uint256 constant internal WITHDRAW_COOLDOWN = 1 hours; 
    uint256 constant internal FEE = 100;
    uint256 constant internal REFERRAL_PERCENTS= 10; 
	uint256 constant internal PERCENTS_DIVIDER = 1000;
	uint256 constant internal TIME_UPDATE = 1 hours;
	uint256 constant internal uplineLevels = 10;

    uint256 public usersCount;
	uint256 public lastBalanceUpdate;
	uint256 public rewardPerUser;
	uint256 public totalInvest;
	uint256 public totalWithdrawn;
	

	event Newbie(address user);
	event Withdrawn(address indexed user, uint256 amount);
	event WithdrawnRefBonus(address indexed user, uint256 amount);
	event RefBonus(address indexed referrer, address indexed referral, uint indexed level, uint amount);
	event NewDeposit(address indexed user, uint amount);
	
    mapping(address => User) private users;

    struct User {
    		address referrer;
    		uint256 totalInvest;
    		uint256 totalWithdrawn;
    		uint256 checkpoint;
    		uint bonus;
	    }
	
	constructor(IERC20 token_)  public{ 
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
		require(isUser(user_) && (block.timestamp.sub(user_.checkpoint)).div(WITHDRAW_COOLDOWN) >= 1, "try again later");
		_;
	}
	
	modifier checkUserReferralWithdraw() {
		User memory user_ = users[msg.sender];
		require(isUser(user_), "try again later");
		_;
	}
	
	function unpause() external whenPaused returns(bool){
	    _unpause();
	    return true;
	}

	function isUser(User memory user_) internal pure returns(bool) {
		return (user_.checkpoint > 0);
	}

	function register(address referrer, uint depAmount ) external {
        token.transferFrom(msg.sender, address(this), depAmount);
		token.transferFrom(msg.sender, owner(), depAmount.mul(FEE).div(PERCENTS_DIVIDER));
		
		User storage user = users[msg.sender];
		User memory  uplineHandler = users[referrer];    
		
		if (user.referrer == address(0) ){
		    if(user.checkpoint == 0){
		        usersCount++;
		        emit Newbie(msg.sender);
		    }
		    
		    if( isUser( uplineHandler )  && referrer != msg.sender )
			    user.referrer = referrer;
		}

		if (user.referrer != address(0)) {
			address upline = user.referrer;
			uint uplineReward = depAmount.mul(REFERRAL_PERCENTS).div(PERCENTS_DIVIDER);
			for (uint i = 0; i < uplineLevels; i++) {
				if (upline != address(0)) {
				    User storage userUpline = users[upline];
					userUpline.bonus = userUpline.bonus.add(uplineReward);
					emit RefBonus(upline, msg.sender, i, uplineReward);
					upline = userUpline.referrer;
				} else break;
			}

		}
		user.checkpoint = block.timestamp;
		user.totalInvest = user.totalInvest.add(depAmount);
		totalInvest = totalInvest.add(depAmount);
		updatebaseReward();
		emit  NewDeposit(msg.sender,depAmount);
		
	}
        
    function userData(address userAddress) external view returns (User memory user_, uint256 nextWithdraw_ ) {
    User memory  user = users[userAddress];    
    user_ = user;
    nextWithdraw_ = user.checkpoint.add(WITHDRAW_COOLDOWN);
    }
	function getContractBalance() public view returns (uint256) {
		return token.balanceOf(address(this));
	}

	function updatebaseReward() internal {
		if(block.timestamp.sub(lastBalanceUpdate) >= TIME_UPDATE){
			rewardPerUser = getContractBalance().div(usersCount);
			lastBalanceUpdate = block.timestamp;
		}
	}
	
	function referralWithdraw()  external contractHasfunds_ whenNotPaused  checkUserReferralWithdraw returns (bool) {
	    updatebaseReward();
	    User storage user = users[msg.sender];
	    uint256 amount  = user.bonus;
	    require(amount > 0, 'you do not bonus currently');
	    user.bonus=0;
	    token.transfer(msg.sender, amount);
	    user.totalWithdrawn = user.totalWithdrawn.add(amount);
	    totalWithdrawn = totalWithdrawn.add(amount);
	    emit WithdrawnRefBonus( msg.sender, amount);
	    return true;
	}

	function withdraw() external contractHasfunds_ whenNotPaused  checkUser_ returns (bool) {
		updatebaseReward();
		User storage user = users[msg.sender];
		uint256 contractBalance = getContractBalance();
		uint256 withdrawAmt = rewardPerUser;
		user.checkpoint = block.timestamp;
		if(withdrawAmt > contractBalance)
			withdrawAmt = contractBalance;
		user.totalWithdrawn = user.totalWithdrawn.add(withdrawAmt);
		token.transfer(msg.sender, withdrawAmt);
		totalWithdrawn = totalWithdrawn.add(withdrawAmt);
		emit Withdrawn(msg.sender, withdrawAmt);
		return true;
	}
}
