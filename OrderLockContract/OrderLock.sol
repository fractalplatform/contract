pragma solidity ^0.4.24;

library SafeMath {

    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

contract OrderLockContract {
    address owner;
    uint256 originalAssetId;
    uint256 lockAssetId;
    uint256 minLockAmount;
    bool paused;

    enum UnLockOrderStatus {None, Apply}

    struct ApplyUnLockRecord{
        UnLockOrderStatus status;
        uint256 time;
    }

    mapping(address => uint256) accountBalance;
    mapping(address => ApplyUnLockRecord) applyUnLockMap;

    uint256 constant nanosecond = 10 ** 9;

    constructor(uint256 _originalAssetId, uint256 _lockAssetId, uint256 _minLockAmount) public {
        owner = msg.sender;
        originalAssetId = _originalAssetId;
        lockAssetId = _lockAssetId;
        minLockAmount = _minLockAmount;
        paused = false;
    }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }
    modifier whenPaused() {
        require(paused);
        _;
    }
    function pause() external whenNotPaused {
        require(msg.sender == owner);
        paused = true;
    }
    function unpause() external whenPaused {
        require(msg.sender == owner);
        paused = false;
    }

    function setMinAmount(uint256 _minAmount) external {
        require(owner == msg.sender);
        minLockAmount = _minAmount;
    }

    function getBaseInfo() external view returns (uint256 _originalAssetId, uint256 _lockAssetId, uint256 _minLockAmount) {
        return (originalAssetId, lockAssetId, minLockAmount);
    }

    function lock() external payable whenNotPaused {
        require(msg.assetid == originalAssetId);
        require(msg.value >= minLockAmount && msg.value > 0);
        require(applyUnLockMap[msg.sender].status == UnLockOrderStatus.None);
        require(addasset(lockAssetId, msg.sender, msg.value) != 0);
        accountBalance[msg.sender] = SafeMath.add(accountBalance[msg.sender], msg.value);
    }

    function applyUnLock() external whenNotPaused {
        require(accountBalance[msg.sender] > 0);
        require(applyUnLockMap[msg.sender].status == UnLockOrderStatus.None);
        applyUnLockMap[msg.sender].status = UnLockOrderStatus.Apply;
        applyUnLockMap[msg.sender].time = now/nanosecond;
    }

    function cancleApply() external whenNotPaused {
        require(applyUnLockMap[msg.sender].status == UnLockOrderStatus.Apply);
        applyUnLockMap[msg.sender].status = UnLockOrderStatus.None;
        applyUnLockMap[msg.sender].time = 0;
    }

    function unLock() external payable whenNotPaused {
        require(msg.assetid == lockAssetId);
        require(applyUnLockMap[msg.sender].status == UnLockOrderStatus.Apply);
        require(msg.value == accountBalance[msg.sender]);
        uint256 nowTime = now/nanosecond;
        require(nowTime >= SafeMath.add(applyUnLockMap[msg.sender].time, (7 days)));

        require(destroyasset(lockAssetId, msg.value) != 0);
        msg.sender.transfer(originalAssetId, msg.value);
        accountBalance[msg.sender] = 0;
        applyUnLockMap[msg.sender].status = UnLockOrderStatus.None;
        applyUnLockMap[msg.sender].time = 0;
    }
}