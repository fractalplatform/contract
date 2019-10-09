pragma solidity ^0.4.24;

library DateTime {
    
    struct _DateTime {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
        uint8 weekday;
    }

    uint constant DAY_IN_SECONDS = 86400;
    uint constant YEAR_IN_SECONDS = 31536000;
    uint constant LEAP_YEAR_IN_SECONDS = 31622400;

    uint constant HOUR_IN_SECONDS = 3600;
    uint constant MINUTE_IN_SECONDS = 60;

    uint16 constant ORIGIN_YEAR = 1970;

    function isLeapYear(uint16 _year) internal pure returns (bool) {
        if (_year % 4 != 0) {
            return false;
        }
        if (_year % 100 != 0) {
            return true;
        }
        if (_year % 400 != 0) {
            return false;
        }
        return true;
    }

    function leapYearsBefore(uint _year) internal pure returns (uint) {
        uint year = _year - 1;
        return year / 4 - year / 100 + year / 400;
    }

    function getDaysInMonth(uint8 _month, uint16 _year) internal pure returns (uint8) {
        if (_month == 1 || _month == 3 || _month == 5 || _month == 7 || _month == 8 || _month == 10 || _month == 12) {
            return 31;
        } else if (_month == 4 || _month == 6 || _month == 9 || _month == 11) {
            return 30;
        } else if (isLeapYear(_year)) {
            return 29;
        } else {
            return 28;
        }
    }

    function parseTimestamp(uint _timestamp) internal pure returns (_DateTime memory dt) {
        uint secondsAccountedFor = 0;
        uint buf;
        uint8 i;

        // Year
        dt.year = getYear(_timestamp);
        buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
        secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

        // Month
        uint secondsInMonth;
        for (i = 1; i <= 12; i++) {
            secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
            if (secondsInMonth + secondsAccountedFor > _timestamp) {
                dt.month = i;
                break;
            }
            secondsAccountedFor += secondsInMonth;
        }

        // Day
        for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
            if (DAY_IN_SECONDS + secondsAccountedFor > _timestamp) {
                dt.day = i;
                break;
            }
            secondsAccountedFor += DAY_IN_SECONDS;
        }

        // Hour
        dt.hour = getHour(_timestamp);

        // Minute
        dt.minute = getMinute(_timestamp);

        // Second
        dt.second = getSecond(_timestamp);

        // Day of week.
        dt.weekday = getWeekday(_timestamp);
    }

    function getYear(uint _timestamp) internal pure returns (uint16) {
        uint secondsAccountedFor = 0;
        uint16 year;
        uint numLeapYears;

        // Year
        year = uint16(ORIGIN_YEAR + _timestamp / YEAR_IN_SECONDS);
        numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
        secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

        while (secondsAccountedFor > _timestamp) {
            if (isLeapYear(uint16(year - 1))) {
                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
            } else {
                secondsAccountedFor -= YEAR_IN_SECONDS;
            }
            year -= 1;
        }
        return year;
    }

    function getMonth(uint _timestamp) internal pure returns (uint8) {
        return parseTimestamp(_timestamp).month;
    }

    function getDay(uint _timestamp) internal pure returns (uint8) {
        return parseTimestamp(_timestamp).day;
    }

    function getHour(uint _timestamp) internal pure returns (uint8) {
        return uint8((_timestamp / 60 / 60) % 24);
    }

    function getMinute(uint _timestamp) internal pure returns (uint8) {
        return uint8((_timestamp / 60) % 60);
    }

    function getSecond(uint _timestamp) internal pure returns (uint8) {
        return uint8(_timestamp % 60);
    }

    function getWeekday(uint _timestamp) internal pure returns (uint8) {
        return uint8((_timestamp / DAY_IN_SECONDS + 4) % 7);
    }

    function getDate(uint _timestamp) internal pure returns (uint256){
        _DateTime memory date = parseTimestamp(_timestamp);
        uint256 realDate = uint256(date.year)*10000 + uint256(date.month)*100 + uint256(date.day);
        return realDate;
    }
}
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

contract LockContract {
    address owner;
    uint256 originalAssetId;
    uint256 lockAssetId;
    uint256 minLockAmount;
    uint256 lockTotalAmount;
    bool paused;
    uint256 constant nanosecond = 10 ** 9;
    uint256 constant baseDateLower = 2 * (10 ** 7); //2000 00 00
    uint256 constant baseDateUpper = 10 ** 8;      //10000 00 00

    enum Date {Today, Past, Future}

    struct LockInfo {
        uint256 amount;
        uint256 unLockTime;
        uint256 next;
    }

    LockInfo[] LockList;

    mapping(address => uint256) listHeadMap;
    uint256 freeListHead;

    mapping(address => uint256) expireBalanceMap;
    mapping(address => bool) userWhiteList;

    constructor(uint256 _originalAssetId, uint256 _lockAssetId, uint256 _minLockAmount) public {
        owner = msg.sender;
        originalAssetId = _originalAssetId;
        lockAssetId = _lockAssetId;
        minLockAmount = _minLockAmount;
        lockTotalAmount = 0;
        paused = false;
        LockList.length = 1;
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

    function addUserWhiteList(address _Account) external {
        require(owner == msg.sender);
        userWhiteList[_Account] = true;
    }

    function delUserWhiteList(address _Account) external {
        require(owner == msg.sender);
        delete userWhiteList[_Account];
    }

    function getBaseInfo() external view returns (uint256 _originalAssetId, uint256 _lockAssetId, uint256 _minLockAmount, uint256 _lockTotalAmount) {
        return (originalAssetId, lockAssetId, minLockAmount, lockTotalAmount);
    }

    function lock(address _account, uint256 _unLockTime) external payable whenNotPaused {
        require(msg.assetid == originalAssetId);
        require(msg.value >= minLockAmount && msg.value > 0);
        require(verifyDate(_unLockTime));
        require(compareDate(_unLockTime) == Date.Future);
        require(addasset(lockAssetId, _account, msg.value) != 0);

        calculateExpireBalance(_account);
        listInsert(_account, _unLockTime, msg.value);

        lockTotalAmount = SafeMath.add(lockTotalAmount, msg.value);
    }

    function calculateExpireBalance(address _account) public {
        uint256 specialIndex;
        uint256 value;
        bool isHead;
        uint256 today = DateTime.getDate(now/nanosecond);
        if (listHeadMap[_account] == 0) return;
        (specialIndex, value, isHead) = calculateBalance(_account, today);
        if (value == 0) return;
        accumulatedUserBalance(_account, value);

        uint256 index = specialIndex;
        while (index != 0) {
            if (LockList[index].next == 0) {
                break;
            }
            index = LockList[index].next;
        }
        LockList[index].next = freeListHead;
        if (LockList[specialIndex].unLockTime <= today) {
            freeListHead = specialIndex;
            listHeadMap[_account] = 0;
        } else {
            freeListHead = LockList[specialIndex].next;
            LockList[specialIndex].next = 0;
        }
    }

    function calculateBalance(address _account,uint256 _date) private view returns (uint256, uint256, bool) {
        if (listHeadMap[_account] == 0) {
            return (0, 0, false);
        }
        uint256 specialIndex = findSpecialIndex(_account, _date);
        uint256 index = specialIndex;
        uint256 value;
        bool isHead = false;
        if (index == listHeadMap[_account]) {
            if (LockList[index].unLockTime <= _date) {
                value = SafeMath.add(value, LockList[index].amount);
            }
            isHead = true;
        }

        index = LockList[index].next;
        while (index != 0) {
            value = SafeMath.add(value, LockList[index].amount);
            index = LockList[index].next;
        }
        return (specialIndex, value, isHead);
    }

    function findSpecialIndex(address _account,uint256 _date) private view returns (uint256) {
        uint256 index = listHeadMap[_account];
        while (index != 0) {
            if (LockList[LockList[index].next].unLockTime <= _date) {
                return index;
            }
            index = LockList[index].next;
        }
    }

    function accumulatedUserBalance(address _account, uint256 _value) private {
        expireBalanceMap[_account] = SafeMath.add(expireBalanceMap[_account], _value);
    }

    function listInsert(address _account, uint256 _unLockTime, uint256 _amount) private {
        bool find = false;
        uint256 index = listHeadMap[_account];

        while (true) {
            if (LockList[index].unLockTime == _unLockTime) {
                find = true;
                break;
            }
            if (LockList[LockList[index].next].unLockTime < _unLockTime) {
                break;
            }
            index = LockList[index].next;
        }
        if (find) {
            LockList[index].amount = SafeMath.add(LockList[index].amount, _amount);
            return;
        }
        
        uint256 newIndex = getNewIndex();
        LockList[newIndex].amount = _amount;
        LockList[newIndex].unLockTime = _unLockTime;
        
        if (listHeadMap[_account] == 0) {
            LockList[newIndex].next = 0;
            listHeadMap[_account] = newIndex;
        } else {
            if (_unLockTime > LockList[listHeadMap[_account]].unLockTime) {
                LockList[newIndex].next = listHeadMap[_account];
                listHeadMap[_account] = newIndex;
                return;   
            }
            LockList[newIndex].next = LockList[index].next;
            LockList[index].next = newIndex;
        }
    }

    function getNewIndex() private returns (uint256) {
        uint256 newIndex = 0;
        if (freeListHead == 0) {
            LockList.length = LockList.length + 1;
            newIndex = LockList.length - 1; 
        } else {
            newIndex = freeListHead;
            freeListHead = LockList[freeListHead].next;
        }
        return newIndex;
    }

    function getPrevIndex(address _account, uint256 _index) private view returns (uint256) {
        uint256 temp = listHeadMap[_account];
        if (temp == _index) return 0;
        while (temp != 0 && LockList[temp].next != _index) {
            temp = LockList[temp].next;
        }
        return temp;
    }

    function transferTo(address _to, uint256 _unLockTime) external payable whenNotPaused {
        require(msg.value != 0);
        require(msg.assetid == lockAssetId);
        require(userWhiteList[msg.sender]);
        require(verifyDate(_unLockTime));
        require(compareDate(_unLockTime) == Date.Future);
        calculateExpireBalance(msg.sender);
        
        uint256 value;
        uint256 specialIndex;
        bool isHead;
        (specialIndex, value, isHead) = calculateBalance(msg.sender, _unLockTime);
        uint256 total = SafeMath.add(value, expireBalanceMap[msg.sender]);
        require(total >= msg.value);

        if(value == 0) {
            expireBalanceMap[msg.sender] = SafeMath.sub(expireBalanceMap[msg.sender], msg.value);
            _to.transfer(lockAssetId, msg.value);
            delete userWhiteList[msg.sender];
            listInsert(_to, _unLockTime, msg.value);
            return;
        }

        total = msg.value;
        uint256 startIndex = specialIndex;

        if (LockList[specialIndex].unLockTime > _unLockTime) {
            startIndex = LockList[specialIndex].next;
        }

        while (startIndex != 0) {
            if (total <= LockList[startIndex].amount) {
                LockList[startIndex].amount = SafeMath.sub(LockList[startIndex].amount, total); 
                total = 0;
                break;
            } else {
                total = SafeMath.sub(total, LockList[startIndex].amount);
                startIndex = LockList[startIndex].next;
            }
        }

        if (isHead) {
            if (total == 0) {
                if (LockList[startIndex].amount == 0) {
                    if (LockList[specialIndex].unLockTime <= _unLockTime) {
                        listHeadMap[msg.sender] = LockList[startIndex].next;
                        LockList[startIndex].next = freeListHead;
                        freeListHead = specialIndex;
                    } else {
                        uint256 temp = LockList[specialIndex].next;
                        LockList[specialIndex].next = LockList[startIndex].next;
                        LockList[startIndex].next = freeListHead;
                        freeListHead = temp;
                    }
                } else {
                    if (LockList[specialIndex].unLockTime <= _unLockTime) {
                        temp = getPrevIndex(msg.sender, startIndex);
                        if (temp != 0) {
                            LockList[temp].next = freeListHead;
                            freeListHead = specialIndex;
                            listHeadMap[msg.sender] = startIndex;
                        }
                    } else {
                        temp = getPrevIndex(msg.sender, startIndex);
                        if (temp != specialIndex) {
                            LockList[temp].next = freeListHead;
                            freeListHead = LockList[specialIndex].next;
                            LockList[specialIndex].next = startIndex;
                        }
                    }
                }
            } else {
                if (LockList[specialIndex].unLockTime <= _unLockTime) {
                    temp = getPrevIndex(msg.sender, 0);
                    LockList[temp].next = freeListHead;
                    freeListHead = specialIndex;
                    listHeadMap[msg.sender] = 0;
                } else {
                    temp = getPrevIndex(msg.sender, 0);
                    LockList[temp].next = freeListHead;
                    freeListHead = LockList[specialIndex].next;
                    LockList[specialIndex].next = 0;
                }
                expireBalanceMap[msg.sender] = SafeMath.sub(expireBalanceMap[msg.sender], total);
            }
        } else {
            if (total == 0) {
                if (LockList[startIndex].amount == 0) {
                    temp = LockList[specialIndex].next;
                    LockList[specialIndex].next = LockList[startIndex].next;
                    LockList[startIndex].next = freeListHead;
                    freeListHead = temp;
                } else {
                    if (LockList[specialIndex].next != startIndex) {
                        temp = getPrevIndex(msg.sender, startIndex);
                        LockList[temp].next = freeListHead;
                        freeListHead = LockList[specialIndex].next;
                        LockList[specialIndex].next = startIndex;
                    }
                }
            } else {
                temp = getPrevIndex(msg.sender, 0);
                LockList[temp].next = freeListHead;
                freeListHead = LockList[specialIndex].next;
                LockList[specialIndex].next = 0;
                expireBalanceMap[msg.sender] = SafeMath.sub(expireBalanceMap[msg.sender], total);
            }
        }

        _to.transfer(lockAssetId, msg.value);
        delete userWhiteList[msg.sender];
        listInsert(_to, _unLockTime, msg.value);
    }

    function getExpireBalance(address _account) external whenNotPaused returns (uint256 _expireBalance) {
        calculateExpireBalance(_account);
        return expireBalanceMap[_account];
    }

    function getLockInfo(address _account, uint256 _index) external view returns (uint256 _unLockTime, uint256 _amount) {
        require(listHeadMap[_account] != 0);
        uint256 index = _index;
        uint256 startIndex = listHeadMap[_account];
        while (index != 0) {
            startIndex = LockList[startIndex].next;
            require(startIndex != 0);
            index = index - 1;
        }
        return (LockList[startIndex].unLockTime, LockList[startIndex].amount);
    }

    function unLock() external payable whenNotPaused {
        require(msg.assetid == lockAssetId);
        calculateExpireBalance(msg.sender);
        require(expireBalanceMap[msg.sender] >= msg.value);
        expireBalanceMap[msg.sender] = SafeMath.sub(expireBalanceMap[msg.sender], msg.value);
        require(destroyasset(lockAssetId, msg.value) != 0);
        msg.sender.transfer(originalAssetId, msg.value);
        lockTotalAmount = SafeMath.sub(lockTotalAmount, msg.value);
    }

    function verifyDate(uint256 _date) private pure returns (bool) {
        if (_date < baseDateLower || _date >= baseDateUpper) return false;
        uint256 year = _date/10000;
        uint256 month = (_date - year*10000)/100;
        uint256 day = _date - year*10000 - month*100;
        if (year == 0 || month == 0 || day == 0) return false;
        if (month > 12 || day > 31) return false;
        bool leapYear = DateTime.isLeapYear(uint16(year));
        if (leapYear && month == 2 && day > 29) return false;
        if (!leapYear && month == 2 && day > 28) return false;
        if ((month == 4 || month == 6 || month == 9 || month == 11) && day > 30) return false;
        return true;
    }

    function compareDate(uint256 _date) private view returns (Date) {
        uint256 today = DateTime.getDate(now/nanosecond);
        if (_date > today) return Date.Future;
        if (_date < today) return Date.Past;
        return Date.Today;
    }
}