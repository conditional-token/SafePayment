// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "interfaces/IERCConditionalToken.sol";

contract ConditionalToken is IERCConditional {
    // Token data
    struct Transaction {
        uint256 transactionID;

        // issuer address that issued the transaction
        address issuer;
        // spender represents the address that will be able to receive funds locked by this transaction.
        address spender;
        // validators are the possible transaction validators.
        mapping(address => bool) validators;

        
        uint256 lockedValue;
        uint256 revokedValue;
        uint256 approvedValue;
        
        uint256 totalValue;
        // Validation prize is the ammount of tokens to be paid to the validator of the transaction.
        uint256 validationPrize;

        // Deadline represents a timestamp.
        // If the transaction is not finished before the deadline, all the money still locked will be returned.
        uint deadline; 
    }

    struct AddressOwnedConditions {
        bool exists;
        uint256[] issuer;
        uint256[] spender;
        uint256[] validator;
    }

    // Mapping from transaction ID to transaction.
    mapping(uint256 => Transaction) private _transactions;
    // Number of transactions emitted, index of the next transaction.
    uint256 private _transactionsNextIndex;

    mapping(address => uint256) balanceOf;

    // Maps an address to all conditions it is related to.
    mapping(address => AddressOwnedConditions) private _ownedConditions;

      // Allow validators to revoke the condition
    function revokeCondition(uint256 conditionID, uint256 value) external returns(bool) {
        Transaction storage condition = _transactions[conditionID];
        require(condition.transactionID != 0);
        require(condition.validators[msg.sender]);

        if (condition.deadline != 0) {
            require(condition.deadline > block.timestamp);
        }

        return false;
    }

    // Allows validators to approve a specific condition
    function approveCondition(uint256 conditionID, uint256 value) external returns(bool) {
        return false;
    }

    // valueLeft = totalConditionVal - approvedVal - revokedVal
    function valueLeft(uint256 conditionID) external view returns(uint256){
        return 0;
    }

    // issuerOf should return all the condition ids where argument address is the issuer.
    function issuerOf(address issuer) external view returns (uint256[] memory){
        uint256[] storage list = _ownedConditions[issuer].issuer;
        return list;
    }
    // issuerOf should return all the condition ids where argument address is the validator.
    function validatorOf(address validator) external view returns (uint256[] memory){
        uint256[] storage list = _ownedConditions[validator].issuer;
        return list;
    }
    // issuerOf should return all the condition ids where argument address is the spender.
    function spenderOf(address spender) external view returns (uint256[] memory){
        uint256[] storage list = _ownedConditions[spender].issuer;
        return list;
    }

    function issueTransaction(address spender, address[] calldata validators, uint256 allowedVal, uint256 validationPrize) public returns(uint256) {
        address issuer = msg.sender;
        uint256 txID = _transactionsNextIndex;

        _transactions[_transactionsNextIndex] = Transaction({
            issuer: issuer,
            transactionID: txID,
            spender: spender,
            validators: validators,
            dueValue: allowedVal,
            balance: 0,
            paid: 0, 
            validationPrize: validationPrize,
            deadline: 0
        });

        return txID;
    }
}