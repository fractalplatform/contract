pragma solidity ^0.4.24;

contract Regedit {
    /**
     * @dev Global registry.
     */
    mapping(address => mapping(string => bytes)) registerList;

    /**
     * @dev User upload data.
     */
    function set(string _key, bytes _value) external {
        bytes memory key;
        bool isLegal = false;
        (key, isLegal) = checkAndChangeKey(bytes(_key));
        require(isLegal, "Key is illegal.");

        registerList[msg.sender][string(key)] = _value;
    }

    /**
     * @dev User fetch data.
     */
    function get(string _accountName, string _key) external view returns(bytes _value){
        uint256 accountId = getaccountid(_accountName);
        require(accountId != 0, "account is not exist");
        bytes memory key;
        bool isLegal = false;
        (key, isLegal) = checkAndChangeKey(bytes(_key));
        require(isLegal, "Key is illegal.");

        return registerList[address(accountId)][string(key)];
    }

    /**
     * @dev Check the key format and conversion case.
     */
    function checkAndChangeKey(bytes _key) private pure returns (bytes, bool) {
        bytes memory key = _key;
        if (key.length == 0) return (key, false);
        for (uint256 i = 0; i < key.length; i++) {
            if (!(key[i] >= 33 && key[i] <= 126)) return (key, false);

            if (key[i] >= 65 && key[i] <= 90) {
                key[i] = bytes1(uint8(key[i]) + 32);
            }
        }
        return (key, true);
    }
}