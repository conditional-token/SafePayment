// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/IERCValidatable.sol";

// PaymentContract main contract for a safe payment platform.
// A safe payment must be validated by a third party.
contract PaymentContract is IERCValidatable {

    struct Payment {
        // payment identifier
        uint256 id;
        // issuer represents the issuer of the payment.
        address issuer;
        // Validators are the possible transaction validators.
        mapping(address => bool) isValidator;

        bool isValidated;
        bool isApproved;
        address validator;

        // Payment receiver
        address payableTo;
        // represents the value that must be paid to receiver.
        uint256 paymentValue;
        // represents the payment of the value.
        bool isPaid;
        // represents the value that will be paid for the validator.
        uint256 validationFee;
    }

    // Mapping from paymentID to transaction.
    mapping(uint256 => Payment) public _payments;
    uint256 _nextPaymentID = 1;

    uint256 contractBalance;

    // Main logic
    /// @notice creates a payment on the contract.
    function createPayment(
        uint256 paymentValue,
        uint256 validationFee,
        address payableTo,
        address[] calldata validators
    ) public payable returns (uint256) {
        require(paymentValue + validationFee == msg.value, "Value must be equal paymentValue and validationFee");
        contractBalance += msg.value;
        
        uint256 paymentID = _nextPaymentID;
        _nextPaymentID++;

        Payment storage p = _payments[paymentID];
        p.id = paymentID;
        p.issuer = msg.sender;
        p.paymentValue = paymentValue;
        p.payableTo = payableTo;
        p.validationFee = validationFee;
        for(uint256 i=0; i < validators.length; i++) {
            p.isValidator[validators[i]] = true;
        }
        emit ConditionCreated(paymentID, msg.sender);
        return paymentID;
    }

    function _transfer(address payable _to, uint256 _ammount) internal {
        _to.transfer(_ammount);
    }

    function claimPayment(uint256 conditionID) external {
        Payment storage p = _payments[conditionID];
        require(p.id != 0, "payment id doesn't exist.");
        require(p.payableTo == msg.sender, "sender is not the receiver of the payment.");
        require(!p.isPaid, "payment was already made.");
        require(p.isApproved, "payment should have been approved to be claimed.");
        _transfer(payable(msg.sender), p.paymentValue);
        p.isPaid = true;
    }

    // IERCValidatable implementation

    /// @notice Get the status of a condition. Status is represented by two boleans, isApproved and isValidated.
    /// @param conditionID Identifier of the condition
    /// @return isApproved bool representing if condition was approved.
    /// @return isValidated bool representing if condition was validated. A validated condition has it's isApproved status as final.
    function getConditionStatus(uint256 conditionID) external view override returns(bool isApproved, bool isValidated) {
        Payment storage p = _payments[conditionID];
        require(p.id != 0, "payment id doesn't exist");
        return (p.isApproved, p.isValidated);
    }

    /// @notice Returns who validated the condition. If condition was not yet validated, raises an error.
    /// @param conditionID Identifier of the condition
    /// @return address of validator.
    function getConditionValidator(uint256 conditionID) external view override returns(address) {
        Payment storage p = _payments[conditionID];
        require(p.id != 0, "payment id doesn't exist");
        require(p.isValidated, "payment was not validated yet");
        return p.validator;
    }

    /// @notice allows sender to reject a condition.  Should raise error if condition was already validated.
    /// @param conditionID Identifier of the condition
    function rejectCondition(uint256 conditionID) external override  {
        Payment storage p = _payments[conditionID];
        require(p.id != 0, "payment id doesn't exist");
        require(!p.isValidated, "payment was already validated");
        require(p.isValidator[msg.sender], "msg.sender is not a valid validator for the payment");

        p.validator = msg.sender;
        p.isApproved = false;
        p.isValidated = true;
        _transfer(payable(msg.sender), p.validationFee);
        emit ConditionRevoked(p.id, msg.sender);
    }

    /// @notice allows sender to approve a condition. Should raise error if condition was already validated.
    /// @param conditionID Identifier of the condition
    function approveCondition(uint256 conditionID) external override {
        Payment storage p = _payments[conditionID];
        require(p.id != 0, "payment id doesn't exist");
        require(!p.isValidated, "payment was already validated");
        require(p.isValidator[msg.sender], "msg.sender is not a valid validator for the payment");

        p.validator = msg.sender;
        p.isApproved = true;
        p.isValidated = true;
        _transfer(payable(msg.sender), p.validationFee);
        emit ConditionApproved(p.id, msg.sender);
    }

    /// @notice should return the issuer of the condition.
    /// @param conditionID Identifier of the condition.
    /// @return address of the issuer.
    function issuerOf(uint256 conditionID) external view override returns (address) {
        Payment storage p = _payments[conditionID];
        require(p.id != 0, "payment id doesn't exist");
        return p.issuer;
    }
}