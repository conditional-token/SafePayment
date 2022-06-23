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
        // Value can be locked to guarantee payment.
        uint256 lockedValue;
        // value that was revoked from the totalValue
        uint256 revokedValue;
        // value that was approved, approved value is paid.
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
    mapping(uint256 => Transaction) public _transactions;
    // Number of transactions emitted, index of the next transaction.
    uint256 private _transactionsNextIndex;

    mapping(address => uint256) balanceOf;

    // Maps an address to all conditions it is related to.
    mapping(address => AddressOwnedConditions) private _transactionsOf;

    // Allow validators to revoke the condition
    function revokeCondition(uint256 conditionID, uint256 value) external override returns(bool) {
        Transaction storage condition = _transactions[conditionID];
        require(condition.validators[msg.sender]);
        if (condition.deadline != 0) {
            require(condition.deadline < block.timestamp);
        }
        require(valueLeft(conditionID) >= value);
        condition.revokedValue += value;
        checkNeedToRefund(conditionID);
        return true;
    }

    function checkNeedToRefund(uint256 conditionID) private {
        Transaction storage c = _transactions[conditionID];
        uint256 vleft = valueLeft(conditionID);
        if (c.deadline >= block.timestamp) {
            // return all locked value and revoke all vleft.
            c.lockedValue = 0;
            c.revokedValue += vleft;
            return;
        }

        if (c.lockedValue > vleft) {
            // uint256 exceeding = condition.lockedValue - valueLeft(conditionID);
            // Transfer exceeding back to issuer.
        }

    }

     // valueLeft = totalValue - approvedValue - revokedValue
    function valueLeft(uint256 conditionID) public view override returns(uint256){
        Transaction storage c = _transactions[conditionID];
        return c.totalValue - (c.revokedValue + c.approvedValue);
    }

    // revokeConditionWithDeadline special revoke condition that can be called by the owner
    function revokeConditionWithDeadline(uint256 conditionID) external {
        checkNeedToRefund(conditionID);
    }

    // Allows validators to approve a specific condition
    function approveCondition(uint256 conditionID, uint256 value) external override returns(bool) {
        Transaction storage c = _transactions[conditionID];
        require(c.validators[msg.sender]);
        uint256 vleft = valueLeft(conditionID);
        require(vleft >= value);
        c.approvedValue += value;
        // Transfer value to spender, from lockedValue or from issuer balance.
        return true;
    }

    // issuerOf should return all the condition ids where argument address is the issuer.
    function issuerOf(address issuer) external view override returns (uint256[] memory){
        uint256[] storage list = _transactionsOf[issuer].issuer;
        return list;
    }
    // issuerOf should return all the condition ids where argument address is the validator.
    function validatorOf(address validator) external view override returns (uint256[] memory){
        uint256[] storage list = _transactionsOf[validator].validator;
        return list;
    }
    // issuerOf should return all the condition ids where argument address is the spender.
    function spenderOf(address spender) external view override returns (uint256[] memory){
        uint256[] storage list = _transactionsOf[spender].spender;
        return list;
    }

    function issueTransaction(address spender, address[] calldata validators, uint256 allowedVal, uint256 validationPrize) public returns(uint256) {
        address issuer = msg.sender;
        uint256 txID = _transactionsNextIndex;
        _transactionsNextIndex++;

        Transaction storage newTx = _transactions[txID];
        newTx.issuer = issuer;
        newTx.transactionID =  txID;
        newTx.spender = spender;
        newTx.totalValue = allowedVal;
        newTx.approvedValue = 0;
        newTx.lockedValue = 0;
        newTx.revokedValue = 0;
        newTx.validationPrize = validationPrize;
        newTx.deadline = 0;

        _transactionsOf[issuer].issuer.push(txID);
        _transactionsOf[spender].spender.push(txID);
        for(uint256 i=0; i < validators.length; i++) {
            newTx.validators[validators[i]] = true;
            _transactionsOf[validators[i]].validator.push(txID);
        }
        
        return txID;
    }
}