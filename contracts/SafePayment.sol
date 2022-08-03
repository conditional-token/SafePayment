// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/IERCValidableEvent.sol";

// SafePayment main contract for a safe payment platform.
// A safe payment event is a payment that can be validated by another party.
contract SafePayment is ValidableEvent {

    // Payment struct represents a validable payment event.
    struct Payment {
        // payment id
        uint256 id;

        // Involved Parties
        address issuer; // issuer address of the payment issuer.
        address receiver; // Original Receiver
        address payableTo; // Payment receiver - can be delegated to another by the receiver

        // Validators are the possible transaction validators.
        mapping(address => bool) isValidator; // mapping for quick check of validators.
        address[] validators; // list of possible validators.

        // Flags
        bool isValidated; // has not received any reject or approve
        bool isApproved; // final approval status.
        bool isPaid; // if the payment was already made.
        
        // Values
        uint256 paymentValue; // represents the value that must be paid to receiver.
        uint256 validationFee; // represents the value that will be paid for the validator.
    }

    // Mapping from paymentID to transaction.
    mapping(uint256 => Payment) public _payments;
    uint256 _nextPaymentID = 1;

    // Contract ethereum balance
    uint256 private contractBalance;

    // Indexes
    mapping(address => uint256[]) public issuerIndex;
    mapping(address => uint256[]) public validatorIndex;
    mapping(address => uint256[]) public receiverIndex;


    /// @notice is the payment event constructor.
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
        p.receiver = payableTo;
        p.validationFee = validationFee;
        p.validators = validators;
        for(uint256 i=0; i < validators.length; i++) {
            p.isValidator[validators[i]] = true;
        }

        address[] memory parties = new address[](1);
        parties[0] = payableTo;
        emit EventCreated(paymentID, msg.sender, parties, validators);

        return paymentID;
    }

    function _transfer(address payable _to, uint256 _ammount) internal {
        _to.transfer(_ammount);
    }

    /// @notice claimPayment allows the payment target to withdraw the value from the contract after the payment was validated.
    /// @param eventID is the payment ID.
    function claimPayment(uint256 eventID) external {
        Payment storage p = _payments[eventID];
        require(p.id != 0, "payment id doesn't exist.");
        require(p.isApproved, "payment should have been approved to be claimed.");
        require(!p.isPaid, "payment was already made.");
        require(p.receiver == msg.sender, "sender is not the receiver of the payment.");

        _transfer(payable(p.receiver), p.paymentValue);
        p.isPaid = true;
    }

    // IERCValidatable implementation

    /// @notice Get the status of an event. Status is represented by two boleans, isApproved and isFinal.
    /// @param eventID Identifier of the payment event.
    /// @return isApproved bool representing if event was approved.
    /// @return isFinal bool representing if event was validated and isApproved is a final approval status.
    function getEventStatus(uint256 eventID) external view override returns(bool isApproved, bool isFinal){
        Payment storage p = _payments[eventID];
        require(p.id != 0, "payment id doesn't exist");
        return (p.isApproved, p.isValidated);
    }

    /// @notice Get the approval and reject rates of the event.
    /// For the payment contract, rates are not used.
    /// @param eventID Identifier of the event.
    /// @return approvalRate uint256 representing the rate of approval.
    /// @return rejectRate uint256 representing the rate of rejection.
    function getEventRates(uint256 eventID) external view override returns(uint256 approvalRate, uint256 rejectRate) {
        Payment storage p = _payments[eventID];
        require(p.id != 0, "payment id doesn't exist");
        if (p.isValidated && p.isApproved) {
            return (1, 0);
        }
        return (0,0);
    }

    /// @notice Returns possible addresses that can validate the event with eventID.
    /// @param eventID Identifier of the event.
    /// @return address of validator.
    function getEventValidators(uint256 eventID) external view override returns(address[] memory){ 
        Payment storage p = _payments[eventID];
        require(p.id != 0, "payment id doesn't exist");
        return p.validators;
    }

    /// @notice Returns a boolean if the address is a possible event validator. 
    /// @param eventID Identifier of the event.
    /// @param validator Address of the possible validator.
    /// @return bool representing if validator can approve or reject the event with eventID.
    function isEventValidator(uint256 eventID, address validator) external view override returns(bool){ 
        Payment storage p = _payments[eventID];
        require(p.id != 0, "payment id doesn't exist");
        return p.isValidator[validator];
    }


    /// @notice allows sender to reject an event. Should raise error if event was already validated.
    /// For this contract, rates are ignored.
    /// @param eventID Identifier of the event.
    /// @param rejectRate A rate that can be used by contracts to measure approval when needed.
    function rejectEvent(uint256 eventID, uint256 rejectRate) external override {
        Payment storage p = _payments[eventID];
        require(p.id != 0, "payment id doesn't exist");
        require(!p.isValidated, "payment was already validated");
        require(p.isValidator[msg.sender], "msg.sender is not a valid validator for the payment");

        p.isApproved = false;
        p.isValidated = true;
        _transfer(payable(msg.sender), p.validationFee);
        emit EventRejected(p.id, msg.sender, rejectRate);
    }

    /// @notice allows sender to approve an event. Should raise error if event was already validated.
    /// @param eventID Identifier of the event.
    /// @param approvalRate A rate that can be used by contracts to measure approval when needed.
    function approveEvent(uint256 eventID, uint256 approvalRate) external override {
        Payment storage p = _payments[eventID];
        require(p.id != 0, "payment id doesn't exist");
        require(!p.isValidated, "payment was already validated");
        require(p.isValidator[msg.sender], "msg.sender is not a valid validator for the payment");

        p.isApproved = true;
        p.isValidated = true;
        _transfer(payable(msg.sender), p.validationFee);
        emit EventApproved(p.id, msg.sender, approvalRate);
    }

    /// @notice should return the issuer of the event.
    /// @param eventID Identifier of the event.
    /// @return address of the issuer.
    function issuerOf(uint256 eventID) external view returns (address) {
        Payment storage p = _payments[eventID];
        require(p.id != 0, "payment id doesn't exist");
        return p.issuer;
    }
}