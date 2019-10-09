pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
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
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
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

contract DposReward {
    uint256 constant NANOSECOND_LEVEL = 10 ** 9;
    uint256 constant PRODUCER_NUM = 21;
    uint256 constant BACKUP_NODE_NUM = 7;
    uint256 constant FULL_BLOCK_OUT_RATIO = 95; // When the block rate reaches 95%,
                                                // it is considered to be full block.
    uint256 constant TICKET_PRECISION = 10 ** 18; // Conversion ratio between equity and single ticket.
    /**
     * @dev The maximum amount that producers and voters can receive each time.
     * @dev Through excessive gas consumption, the transaction is not successful.
     */
    uint256 constant PRODUCER_GET_REWAED_LIMIT = 52;
    uint256 constant VOTER_GET_REWAED_LIMIT = 52;

    uint256 constant FT_ID = 0;

    /**
     * @dev Producer ranking corresponding weight.
     */
    uint256[] rankingWeights = [100,95,94,93,92,91,90,85,80,75,70,65,60,55,54,53,52,51,50,49,48,45,42,39,36,33,30,27];

    /**
     * @dev Allows additional bonus whitelist.
     */
    mapping (address => bool) whiteList;

    /**
     * @dev Cycle information (initial producer list and producer ranking).
     */
    struct cycleInfo {
        bool      isInitRanking;
        uint256   cycleUnLockTime;
        uint256[] rewardListIndexs;
        uint256[] initialProducerList;
        uint256[] producerRanking;
    }
    mapping(uint256 => cycleInfo) cycleInfoMap;

    /**
     * @dev Reward information.
     */
    struct RewardInfo {
        uint256   rewardTime;
        uint256   cycleNum;
        uint256   rewardAmount;
        uint256   lockRatio;
        uint256[] singleTicketValue; // The single ticket value of the producers this cycle.
                                    // stored in the order of the initial producers of the cycle.
        uint256[] rankingWeights;
    }
    RewardInfo[] rewardInfos;

    address assetProtocol;
    bytes4 methodId;
    /**
     * @dev Record the account's reward location.
     */
    mapping (address => uint256) public producerGetStartPosition;
    mapping (address => uint256) public voterGetStartPosition;

    bool paused;
    address owner;

    /**
     * @dev Get the scope of the collection when you receive the reward.
     */
    event getRewardRange(uint256 _start, uint256 _end);

    constructor() public {
        owner = msg.sender;
        paused = false;
        methodId = bytes4(keccak256("lock(address,uint256)"));
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

    /**
     * @dev Set the reward asset type.
     */
    function setAssetProtocol(address _assetProtocol) external {
        require(msg.sender == owner);
        require(_assetProtocol != address(0));

        assetProtocol = _assetProtocol;
    }

    /**
     * @dev Add a whitelist account.
     */
    function setWhiteList(address _account) external {
        require(msg.sender == owner);
        require(_account != address(0));
        require(false == whiteList[_account]);

        whiteList[_account] = true;
    }

    /**
     * @dev Delete whitelist account.
     */
    function delWhiteList(address _account) external {
        require(msg.sender == owner);
        require(_account != address(0));
        require(true == whiteList[_account]);

        delete whiteList[_account];
    }

    /**
     * @dev Add reward by cycle.
     * @param _cycleNum Valid cycle number.
     * @param _rankingWeights Custom producer ranking weight.
     * @param _lockRatio The reward is awarded in lock-up form.
     */
    function appendReward(uint256 _cycleNum, uint256 _lockRatio, uint256[] _rankingWeights) external payable whenNotPaused {
        require(whiteList[msg.sender] == true);
        uint256 currentCycleNum = 0;
        (currentCycleNum,) = getepoch(0, 0);
        require(currentCycleNum > _cycleNum);
        require(FT_ID == msg.assetid);
        require(0 <= _lockRatio && _lockRatio <= 100);
        require(_rankingWeights.length == 0 || _rankingWeights.length == PRODUCER_NUM + BACKUP_NODE_NUM);

        // Initialization cycle data.
        if (cycleInfoMap[_cycleNum].isInitRanking == false) {
            initProducerAndCalcRanking(_cycleNum);
            cycleInfoMap[_cycleNum].isInitRanking = true;
        }
        if (_lockRatio != 0 && cycleInfoMap[_cycleNum].cycleUnLockTime == 0) {
            cycleInfoMap[_cycleNum].cycleUnLockTime = calcRewardUnLockTime(_cycleNum);
        }
        cycleInfoMap[_cycleNum].rewardListIndexs.push(rewardInfos.length);

        // Additional reward information.
        rewardInfos.length = rewardInfos.length + 1;
        rewardInfos[rewardInfos.length - 1].rewardTime = now;
        rewardInfos[rewardInfos.length - 1].cycleNum = _cycleNum;
        rewardInfos[rewardInfos.length - 1].rewardAmount = msg.value;
        rewardInfos[rewardInfos.length - 1].lockRatio = _lockRatio;
        rewardInfos[rewardInfos.length - 1].rankingWeights = _rankingWeights;
        // Calculate the single ticket value of the award.
        calcTicketValue(rewardInfos.length - 1);
    }

    /**
     * @dev Get the unlock time of the locked assets (one year after the cycle time).
     */
    function calcRewardUnLockTime(uint256 _cycleNum) private returns(uint256) {
        uint256 cycleTime = 0;
        (, cycleTime) = getepoch(3, _cycleNum);
        cycleTime = cycleTime / NANOSECOND_LEVEL;
        uint256 fmtCycleTime = DateTime.getDate(cycleTime + (1 weeks));
        uint256 fmtUnLockTime = 0;

        fmtUnLockTime = fmtCycleTime + 10 ** 4;
        if (fmtCycleTime / 100 % 100 == 2 && fmtCycleTime % 100 == 29) {
            fmtUnLockTime--;
        }
        return fmtUnLockTime;
    }

    /**
     * @dev Producer receives rewards.
     * @dev Receive all rewards currently available.
     */
    function producersGetReward() external whenNotPaused {
        uint256 startIndex = 0;
        uint256 nextStartIndex = 0;
        (startIndex,nextStartIndex) = getProducerGetRange(msg.sender);
        emit getRewardRange(startIndex, nextStartIndex);
        uint256 currFmtTime = DateTime.getDate(now / NANOSECOND_LEVEL);
        uint256 unLockAmount = 0;
        for (uint256 rewardIndex = startIndex; rewardIndex < nextStartIndex; rewardIndex++) {
            uint256 cycleNum = rewardInfos[rewardIndex].cycleNum;
            // Determine whether the recipient is a producer in the current cycle.
            if (false == isProducer(msg.sender, cycleNum)) continue;

            uint256 producerReward = SafeMath.mul(SafeMath.div(rewardInfos[rewardIndex].rewardAmount, 5), 4);
            uint256 producerIndex = getProducerRanking(uint256(msg.sender), cycleNum);
            producerReward = calcRankingReward(cycleInfoMap[cycleNum].initialProducerList.length, rewardIndex, producerIndex, producerReward);
            if (producerReward == 0) continue;
            // Producers count rewards and hand them out.
            // All FT awards will be distributed.
            if (rewardInfos[rewardIndex].lockRatio == 0) {
                unLockAmount = SafeMath.add(unLockAmount, producerReward);
                continue;
            }
            // Give out rewards by locking up warehouses.
            uint256 lockAmount = SafeMath.div(SafeMath.mul(producerReward, rewardInfos[rewardIndex].lockRatio), 100);
            uint256 spotAmount = SafeMath.sub(producerReward, lockAmount);
            unLockAmount = SafeMath.add(unLockAmount, spotAmount);
            if (cycleInfoMap[cycleNum].cycleUnLockTime <= currFmtTime) {
                unLockAmount = SafeMath.add(unLockAmount, lockAmount);
            } else {
                require(assetProtocol.call.value(lockAmount)(methodId, msg.sender, cycleInfoMap[cycleNum].cycleUnLockTime));
            }
        }
        if (unLockAmount != 0) {
            (msg.sender).transfer(FT_ID, unLockAmount);
        }
        producerGetStartPosition[msg.sender] = nextStartIndex;
    }

    /**
     * @dev Voters receive rewards.
     */
    function votersGetReward() external whenNotPaused {
        uint256 startIndex = 0;
        uint256 nextStartIndex = 0;
        (startIndex,nextStartIndex) = getVoterGetRange(msg.sender);
        emit getRewardRange(startIndex, nextStartIndex);
        uint256 currFmtTime = DateTime.getDate(now / NANOSECOND_LEVEL);
        uint256 unLockAmount = 0;
        for (uint256 i = startIndex; i < nextStartIndex; i++) {
            uint256 cycleNum = rewardInfos[i].cycleNum;

            uint256 voterReward = 0;
            for (uint256 j = 0; j < cycleInfoMap[cycleNum].initialProducerList.length; j++) {

                uint256 singleTicketValue = rewardInfos[i].singleTicketValue[j];
                uint256 producerPledgeStake = 0;

                uint256 voterVoteNum = getvoterstake(cycleNum, uint256(msg.sender), cycleInfoMap[cycleNum].initialProducerList[j]);
                voterVoteNum = SafeMath.div(voterVoteNum, TICKET_PRECISION);
                voterReward = SafeMath.add(voterReward, SafeMath.mul(singleTicketValue, voterVoteNum));

                if (uint256(msg.sender) == cycleInfoMap[cycleNum].initialProducerList[j]) {
                    (,producerPledgeStake,,,,,) = getcandidate(cycleNum, j);
                    producerPledgeStake = SafeMath.div(producerPledgeStake, TICKET_PRECISION);
                    voterReward = SafeMath.add(voterReward, SafeMath.mul(singleTicketValue, producerPledgeStake));
                }
            }
            if (voterReward == 0) continue;
            // Voters count rewards and hand them out.
            // All FT awards will be distributed.
            if (rewardInfos[i].lockRatio == 0) {
                unLockAmount = SafeMath.add(unLockAmount, voterReward);
                continue;
            }
            // Give out rewards by locking up warehouses.
            uint256 lockAmount = SafeMath.div(SafeMath.mul(voterReward, rewardInfos[i].lockRatio), 100);
            uint256 spotAmount = SafeMath.sub(voterReward, lockAmount);
            unLockAmount = SafeMath.add(unLockAmount, spotAmount);
            if (cycleInfoMap[cycleNum].cycleUnLockTime <= currFmtTime) {
                unLockAmount = SafeMath.add(unLockAmount, lockAmount);
            } else {
                require(assetProtocol.call.value(lockAmount)(methodId, msg.sender, cycleInfoMap[cycleNum].cycleUnLockTime));
            }
        }
        if (unLockAmount != 0) {
            (msg.sender).transfer(FT_ID, unLockAmount);
        }
        voterGetStartPosition[msg.sender] = nextStartIndex;
    }

    /**
     * @dev Get reward information through index.
     */
    function getRewardInfo(uint256 _index) external view returns(uint256 _rewardTime, uint256 _cycleNum, uint256 _amount,
                                                                uint256 _lockRatio, uint256[] _singleTicketValue, uint256[] _weights) {
        require(_index < rewardInfos.length);

        uint256[] memory weights;
        if (rewardInfos[_index].rankingWeights.length == 0) {
            weights = rankingWeights;
        } else {
            weights = rewardInfos[_index].rankingWeights;
        }
        return (rewardInfos[_index].rewardTime, rewardInfos[_index].cycleNum, rewardInfos[_index].rewardAmount,
                rewardInfos[_index].lockRatio, rewardInfos[_index].singleTicketValue, weights);
    }

    /**
     * @dev Get the cycle Info by cycle number.
     */
    function getCycleInfo(uint256 _cycleNum) external view returns(uint256 _time, uint256[] _indexs, uint256[] _ranking) {
        require(cycleInfoMap[_cycleNum].isInitRanking == true);

        return (cycleInfoMap[_cycleNum].cycleUnLockTime, cycleInfoMap[_cycleNum].rewardListIndexs, cycleInfoMap[_cycleNum].producerRanking);
    }

    /**
     * @dev Get the list of single ticket values corresponding to the producers in the cycle.
     */
    function getSingleTicketValue(uint256 _index) external view returns (uint256[] _producerIDs, uint256[] _singleTicketValue) {
        require(_index < rewardInfos.length);

        uint256 cycleNum = rewardInfos[_index].cycleNum;
        return (cycleInfoMap[cycleNum].initialProducerList, rewardInfos[_index].singleTicketValue);
    }

    /**
     * @dev The range of rewards available to producers.
     */
    function getProducerGetRange(address _producer) public view returns(uint256 _start, uint256 _end) {
        if (SafeMath.sub(rewardInfos.length, producerGetStartPosition[_producer]) > PRODUCER_GET_REWAED_LIMIT) {
            return (producerGetStartPosition[_producer], SafeMath.add(producerGetStartPosition[_producer], PRODUCER_GET_REWAED_LIMIT));
        }
        return (producerGetStartPosition[_producer], rewardInfos.length);
    }

    /**
     * @dev Get a single award amount
     */
    function getProducerRewardAmount(address _account, uint256 _index) external view returns(uint256 _cycleNum, uint256 _lockRatio, uint256 _amount) {
        require(_account != address(0));
        require(_index < rewardInfos.length);
        uint256 cycleNum = rewardInfos[_index].cycleNum;
        if (false == isProducer(_account, cycleNum)) {
            return (cycleNum, rewardInfos[_index].lockRatio, 0);
        }

        uint256 producerReward = SafeMath.mul(SafeMath.div(rewardInfos[_index].rewardAmount, 5), 4);
        uint256 producerIndex = getProducerRanking(uint256(_account), cycleNum);
        producerReward = calcRankingReward(cycleInfoMap[cycleNum].initialProducerList.length, _index, producerIndex, producerReward);
        return (cycleNum, rewardInfos[_index].lockRatio, producerReward);
    }

    /**
     * @dev The range of rewards available to voters.
     */
    function getVoterGetRange(address _voter) public view returns(uint256 _start, uint256 _end) {
        if (SafeMath.sub(rewardInfos.length, voterGetStartPosition[_voter]) > VOTER_GET_REWAED_LIMIT) {
            return (voterGetStartPosition[_voter], SafeMath.add(voterGetStartPosition[_voter], VOTER_GET_REWAED_LIMIT));
        }
        return (voterGetStartPosition[_voter], rewardInfos.length);
    }

    /**
     * @dev Get a single award amount
     */
    function getVoterRewardAmount(address _account, uint256 _index) external view returns(uint256 _cycleNum, uint256 _lockRatio, uint256 _amount) {
        require(_account != address(0));
        require(_index < rewardInfos.length);

        uint256 cycleNum = rewardInfos[_index].cycleNum;
        uint256 voterReward = 0;
        for (uint256 j = 0; j < cycleInfoMap[cycleNum].initialProducerList.length; j++) {

            uint256 singleTicketValue = rewardInfos[_index].singleTicketValue[j];
            uint256 producerPledgeStake = 0;

            uint256 voterVoteNum = getvoterstake(cycleNum, uint256(_account), cycleInfoMap[cycleNum].initialProducerList[j]);
            voterVoteNum = SafeMath.div(voterVoteNum, TICKET_PRECISION);
            voterReward = SafeMath.add(voterReward, SafeMath.mul(singleTicketValue, voterVoteNum));

            if (uint256(_account) == cycleInfoMap[cycleNum].initialProducerList[j]) {
                (,producerPledgeStake,,,,,) = getcandidate(cycleNum, j);
                producerPledgeStake = SafeMath.div(producerPledgeStake, TICKET_PRECISION);
                voterReward = SafeMath.add(voterReward, SafeMath.mul(singleTicketValue, producerPledgeStake));
            }
        }
        return (cycleNum, rewardInfos[_index].lockRatio, voterReward);
    }

    /**
     * @dev Calculate the value of a single voter in a reward.
     */
    function calcTicketValue(uint256 _rewardIndex) private {
        uint256 stakeSum = 0;
        uint256 cycleNum = rewardInfos[_rewardIndex].cycleNum;
        uint256 producerNum = cycleInfoMap[cycleNum].initialProducerList.length;
        rewardInfos[_rewardIndex].singleTicketValue.length = producerNum;

        uint256 voterTotalReward = SafeMath.div(rewardInfos[_rewardIndex].rewardAmount, 5);
        for (uint i = 0; i < cycleInfoMap[cycleNum].initialProducerList.length; i++) {
            uint256 producerTicketValue = 0;
            (,, stakeSum,,,,) = getcandidate(cycleNum, i);
            stakeSum = SafeMath.div(stakeSum, TICKET_PRECISION);
            uint256 producerIndex = getProducerRanking(cycleInfoMap[cycleNum].initialProducerList[i], cycleNum);
            producerTicketValue = calcRankingReward(producerNum, _rewardIndex, producerIndex, voterTotalReward);
            rewardInfos[_rewardIndex].singleTicketValue[i] = SafeMath.div(producerTicketValue, stakeSum);
        }
    }

    /**
     * @dev Determines whether the user is a producer during the cycle.
     */
    function isProducer(address _user, uint256 _cycleNum) private view returns(bool) {
        for (uint256 producerIndex = 0; producerIndex < cycleInfoMap[_cycleNum].initialProducerList.length; producerIndex++) {
            if (uint256(_user) == cycleInfoMap[_cycleNum].initialProducerList[producerIndex]) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Get the producers' ranking position in this cycle.
     */
    function getProducerRanking(uint256 _userID, uint256 _cycleNum) private view returns(uint256) {
        for (uint256 producerIndex = 0; producerIndex < cycleInfoMap[_cycleNum].producerRanking.length; producerIndex++) {
            if (cycleInfoMap[_cycleNum].producerRanking[producerIndex] == _userID) {
                return producerIndex;
            }
        }
    }

    /**
     * @dev Calculate the producer weight corresponding reward.
     * @param _rewardIndex Reward list index.
     * @param _producerIndex Producer list index.
     * @param _reward Reward amount.
     * @return The amount of rewards assigned to the producer based on the producer ranking.
     */
    function calcRankingReward(uint256 _producerNum, uint256 _rewardIndex, uint256 _producerIndex, uint256 _reward) private view returns (uint256){
        uint256 producerReward = 0;
        uint256 i = 0;
        uint256 weightSum = 0;
        if (rewardInfos[_rewardIndex].rankingWeights.length == 0) {
            for (i = 0; i < _producerNum; i++) {
                weightSum = SafeMath.add(weightSum, rankingWeights[i]);
            }
            producerReward = SafeMath.mul(_reward, rankingWeights[_producerIndex]);
            producerReward = SafeMath.div(producerReward, weightSum);
        } else {
            for (i = 0; i < _producerNum; i++) {
                weightSum = SafeMath.add(weightSum, rewardInfos[_rewardIndex].rankingWeights[i]);
            }
            producerReward = SafeMath.mul(_reward, rewardInfos[_rewardIndex].rankingWeights[_producerIndex]);
            producerReward = SafeMath.div(producerReward, weightSum);
        }
        return producerReward;
    }

    /**
     * @dev Initialize the cycle producer list and calculate the producer ranking.
     */
    function initProducerAndCalcRanking(uint256 _cycleNum) private {
        uint256 producerNum = getcandidatenum(_cycleNum);
        require(producerNum >= PRODUCER_NUM / 3 * 2 + 1);
        uint256 actProducerNum = producerNum >= PRODUCER_NUM ? PRODUCER_NUM : producerNum;
        uint256[] memory initProducers = new uint256[](producerNum);
        uint256[] memory producerStatus = new uint256[](producerNum);
        uint256[] memory shouldOutBlock = new uint256[](producerNum);
        uint256[] memory producerWeight = new uint256[](producerNum);
        uint256[] memory backupNodeReplace = new uint256[](producerNum - actProducerNum);

        // Store the alternate location of the alternate node.
        for (uint256 i = 0;  i < backupNodeReplace.length; i++) {
            (,,,,,backupNodeReplace[i],) = getcandidate(_cycleNum, actProducerNum + i);
        }

        for (i = 0; i < producerNum; i++) {
            uint256 count = 0;
            uint256 actCount = 0;
            uint256 outBlockSum = 0;
            uint256 shouldOutBlockSum = 0;
            (initProducers[i],,, count, actCount,, producerStatus[i]) = getcandidate(_cycleNum, i);
            shouldOutBlock[i] = count;
            if (count != 0) {
                (outBlockSum, shouldOutBlockSum) = getPrePositionData(i, _cycleNum, actProducerNum, backupNodeReplace);
            } else {
                producerStatus[i] = 2;
            }
            producerWeight[i] = getProducerWeight(actCount, count, outBlockSum, shouldOutBlockSum);
        }
        cycleInfoMap[_cycleNum].initialProducerList = initProducers;
        cycleInfoMap[_cycleNum].producerRanking = producerSort(initProducers, producerStatus, shouldOutBlock, producerWeight);
    }

    /**
     * @dev Producer data for sorting.
     */
    struct ProducerData {
        uint256 producerID;
        uint256 shouldOutBlock;
        uint256 producerWeight;
    }
    function producerSort(uint256[] _initProducers, uint256[] _producerStatus, uint256[] _shouldOutBlock, uint256[] _producerWeight) private pure returns(uint256[]) {
        require(_initProducers[0] != _initProducers[1]);
        uint256[] memory producerRanking = new uint256[](_initProducers.length);
        uint256[3] memory producerTypeCount;
        for (uint256 i = 0; i < _producerStatus.length; i++) {
            if (_producerStatus[i] == 0) producerTypeCount[0]++;
            else if (_producerStatus[i] == 1) producerTypeCount[1]++;
        }
        ProducerData[] memory normalProducers = new ProducerData[](producerTypeCount[0]);
        ProducerData[] memory kickOutProducers = new ProducerData[](producerTypeCount[1]);
        uint256 normalLocation = 0;
        uint256 kickOutLocation = 0;
        ProducerData memory producerData;
        for (i = 0; i < _initProducers.length; i++) {
            producerData = ProducerData(_initProducers[i], _shouldOutBlock[i], _producerWeight[i]);
            if (_producerStatus[i] == 0) {
                normalProducers[normalLocation] = producerData;
                if (normalLocation == 0) {
                    normalLocation++;
                    continue;
                }
                for (uint j = normalLocation; j > 0; j--) {
                    if (normalProducers[j].producerWeight > normalProducers[j - 1].producerWeight) {
                        (normalProducers[j], normalProducers[j - 1]) = (normalProducers[j - 1], normalProducers[j]);
                    } else if (normalProducers[j].producerWeight == normalProducers[j - 1].producerWeight) {
                        if (normalProducers[j].shouldOutBlock > normalProducers[j - 1].shouldOutBlock) {
                            (normalProducers[j], normalProducers[j - 1]) = (normalProducers[j - 1], normalProducers[j]);
                        }
                    }
                }
                normalLocation++;
            } else if (_producerStatus[i] == 1) {
                kickOutProducers[kickOutLocation] = producerData;
                if (kickOutLocation == 0) {
                    kickOutLocation++;
                    continue;
                }
                for (j = kickOutLocation; j > 0; j--) {
                    if (kickOutProducers[j].producerWeight > kickOutProducers[j - 1].producerWeight) {
                        (kickOutProducers[j], kickOutProducers[j - 1]) = (kickOutProducers[j - 1], kickOutProducers[j]);
                    } else if (kickOutProducers[j].producerWeight == kickOutProducers[j - 1].producerWeight) {
                        if (kickOutProducers[j].shouldOutBlock > kickOutProducers[j - 1].shouldOutBlock) {
                            (kickOutProducers[j], kickOutProducers[j - 1]) = (kickOutProducers[j - 1], kickOutProducers[j]);
                        }
                    }
                }
                kickOutLocation++;
            }
        }
        i = 0;
        for (j = 0; j < normalProducers.length; j++) {
            producerRanking[i++] = normalProducers[j].producerID;
        }
        for (j = 0; j < _initProducers.length; j++) {
            if (_producerStatus[j] == 2) {
                producerRanking[i++] = _initProducers[j];
            }
        }
        for(j = 0; j < kickOutProducers.length; j++) {
            producerRanking[i++] = kickOutProducers[j].producerID;
        }
        return producerRanking;
    }

    /**
     * @dev Get the data in the previous position of the node.
     */
    function getPrePositionData(uint256 _producerIndex, uint256 _cycleNum, uint256 _actProducerNum, uint256[] _replaces) private returns(uint256, uint256) {
        uint256 count = 0;
        uint256 actCount = 0;
        uint256 prePosition = 0;
        uint256 outBlockSum = 0;
        uint256 shouldOutBlockSum = 0;

        if (_producerIndex == 0) {
            prePosition = _actProducerNum;
        } else if (_producerIndex > 0 && _producerIndex < _actProducerNum) {
            prePosition = _producerIndex;
        } else {
            if (_replaces[_producerIndex - _actProducerNum] == 0) {
                return (0, 0);
            }
            prePosition = _replaces[_producerIndex - _actProducerNum] == 1 ? _actProducerNum : _replaces[_producerIndex - _actProducerNum] - 1;
        }

        (,,, count, actCount,,) = getcandidate(_cycleNum, prePosition - 1);
        shouldOutBlockSum = SafeMath.add(shouldOutBlockSum, count);
        outBlockSum = SafeMath.add(outBlockSum, actCount);
        for (uint i = 0; i < _replaces.length; i++) {
            if (_replaces[i] == prePosition) {
                (,,, count, actCount,,) = getcandidate(_cycleNum, _actProducerNum + i);
                shouldOutBlockSum = SafeMath.add(shouldOutBlockSum, count);
                outBlockSum = SafeMath.add(outBlockSum, actCount);
            }
        }
        return (outBlockSum, shouldOutBlockSum);
    }
    /**
     * @dev Get producer production block ratio.
     */
    function getProducerWeight(uint256 _outBlock, uint256 _shouldOutBlock, uint256 _preOutBlock, uint256 _preShouldOutBlock) private pure returns(uint256) {
        uint256 producerWeight = 0;
        if (_shouldOutBlock != 0) {
            require(_preShouldOutBlock != 0);
            uint256 outBlockRate = SafeMath.div(SafeMath.mul(_outBlock, 100), _shouldOutBlock);
            if (outBlockRate >= FULL_BLOCK_OUT_RATIO) {
                outBlockRate = 100;
            }
            uint256 preOutBlockRate = SafeMath.div(SafeMath.mul(_preOutBlock, 100), _preShouldOutBlock);
            if (preOutBlockRate >= FULL_BLOCK_OUT_RATIO) {
                preOutBlockRate = 100;
            }

            producerWeight = SafeMath.div(SafeMath.mul(outBlockRate, preOutBlockRate), 100);
        } else {
            producerWeight = 100;
        }
        return producerWeight;
    }
}