// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

// SafePayment main contract for a safe payment platform.
// A safe payment event is a payment that can be validated by another party.
contract BuyAndSell {

    // Payment struct represents a validable payment event.
    struct Transaction {
        // Involved Parties
        address buyer; // issuer address of the payment issuer.
        address seller; // Original Receiver

        // Validators are the possible transaction validators.
        address validatorBuyer;
        address validatorSeller;
        address thirdValidator;

        // Flags
        bool isAccepted;
        bool isApprovedSeller; // final approval status (0 non approved, 1 aproved by one validator or 2 aproved by other).
        bool isApprovedBuyer; // final approval status (0 non approved, 1 aproved by one validator or 2 aproved by other).
        bool isThirdApproved;
        bool isPaid; // if the payment was already made.
        
        bool isSellerDisputed; // seller disputed the result
        bool isBuyerDisputed; // buyer dispute de result

        uint256 contractBalance; // if 0, it is a buy, else it is a sell

        // Values
        uint256 paymentValue; // represents the value that must be paid to receiver.
        uint256 validationFee; // represents the value that will be paid for the validator.
        uint256 thirdValidationFee; // represents the value that will be paid for the validator.
    }
    
    struct Comment {// critica que pode ser positiva ou negativa
        uint256 transactionId;
        uint nature;//0: neutral (validator describe payment of fee), 1: complaint, 2: severe
        string description;
        uint sort;
    }

    mapping(uint256 => Comment[]) public comments;

    // Mapping from paymentID to transaction.
    mapping(uint256 => Transaction) public transactions;
    uint256 nextTransactionID = 1;

    // Contract ethereum balance
    uint256 private contractBalance;

    /// @notice is the payment event constructor.
    /// @param paymentValue is the value that must be paid to payable to. It must be sent in the tx value.
    /// @param validationFee is the fee for the validator. It must be sent in the tx value.
    /// @param thirdValidationFee is the fee for the validator. It must be sent in the tx value.
    /// @param buyerValidator an array of addresses that can validate this payment.
    /// @param thirdValidator an array of addresses that can validate this payment.
    function createBuy(
        uint256 paymentValue,
        uint256 validationFee,
        uint256 thirdValidationFee,
        address buyerValidator,
        address thirdValidator
    ) external returns (uint256) {
        //sell
        //require(paymentValue + 2 * validationFee + thirdValidationFee == msg.value, "Value must be equal paymentValue and validationFee");
        //contractBalance += msg.value;
        
        uint256 buyID = nextTransactionID;
        nextTransactionID++;

        Transaction storage b = transactions[buyID];
        b.buyer = msg.sender;
        b.paymentValue = paymentValue;
        b.thirdValidationFee = thirdValidationFee;
        b.validationFee = validationFee;
        
        b.validatorBuyer = buyerValidator;

        b.thirdValidator = thirdValidator;

        address[] memory validators = new address[](1);
        validators[0] = buyerValidator;
        validators[1] = thirdValidator;
        emit EventCreated(buyID, msg.sender, validators, validators);

        return buyID;
    }


    /// @notice is the payment event constructor.
    /// @param paymentValue is the value that must be paid to payable to. It must be sent in the tx value.
    /// @param validationFee is the fee for the validator. It must be sent in the tx value.
    /// @param thirdValidationFee is the fee for the validator. It must be sent in the tx value.
    /// @param sellerValidator an array of addresses that can validate this payment.
    /// @param thirdValidator an array of addresses that can validate this payment.
    function createSell(
        uint256 paymentValue,
        uint256 validationFee,
        uint256 thirdValidationFee,
        address sellerValidator,
        address thirdValidator
    ) public payable returns (uint256) {
        //sell
        require(paymentValue + 2 * validationFee + thirdValidationFee == msg.value, "Value must be equal paymentValue and validationFee");
        contractBalance += msg.value;
        
        uint256 sellID = nextTransactionID;
        nextTransactionID++;

        Transaction storage s = transactions[sellID];
        s.seller = msg.sender;
        s.paymentValue = paymentValue;
        s.thirdValidationFee = thirdValidationFee;
        s.validationFee = validationFee;
        
        s.validatorSeller = sellerValidator;

        s.thirdValidator = thirdValidator;


        address[] memory validators = new address[](1);
        validators[0] = sellerValidator;
        validators[1] = thirdValidator;
        emit EventCreated(sellID, msg.sender, validators, validators);

        return sellID;
    }

    function takeBuy(uint256 buyID,
        address sellerValidator) public payable returns (uint256) {
        Transaction storage b = transactions[buyID];
        require(b.buyer != address(0), "payment id doesn't exist.");
        require(b.seller == address(0),"buy just have a seller");
        require(b.paymentValue + 2 * b.validationFee + b.thirdValidationFee == msg.value, "Value must be equal paymentValue and validationFee");
        contractBalance += msg.value;

        b.seller = msg.sender;
        b.validatorSeller = sellerValidator;
        b.isAccepted = true;

        address[] memory validators = new address[](1);
        validators[0] = sellerValidator;
        emit EventCreated(buyID, msg.sender, validators, validators);

        return buyID;
    }

    function takeSell(uint256 sellID,
        address buyerValidator) external returns (uint256) {
        Transaction storage s = transactions[sellID];
        require(s.seller != address(0), "payment id doesn't exist.");
        require(s.buyer == address(0),"sell just have a buyer");

        s.buyer = msg.sender;
        s.validatorBuyer = buyerValidator;


        address[] memory validators = new address[](1);
        validators[0] = buyerValidator;
        emit EventCreated(sellID, msg.sender, validators, validators);

        return sellID;
    }

    function acceptSell(uint256 sellID) external returns (uint256) {
        Transaction storage s = transactions[sellID];
        require(s.seller != address(0), "payment id doesn't exist.");
        require(s.buyer != address(0),"sell does not have a buyer");
        require(s.validatorSeller == msg.sender || s.thirdValidator == msg.sender,"you need to be a validator");

        s.isAccepted = true;

        return sellID;
    }

    function refuseSell(uint256 sellID) external returns (uint256) {
        Transaction storage s = transactions[sellID];
        require(s.seller != address(0), "payment id doesn't exist.");
        require(s.buyer != address(0),"sell does not have a buyer");
        require(!s.isAccepted,"sell alreary was accepted");
        require(s.contractBalance > 0,"this id is a buy");
        require(s.validatorSeller == msg.sender || s.thirdValidator == msg.sender,"you need to be a validator");

        s.buyer = address(0);
        s.validatorBuyer = address(0);

        s.isAccepted = false;

        return sellID;
    }

    /// @notice is the payment event constructor.
    /// @param transactionId -
    /// @param description -
    /// @param nature -
    function createComment(
        uint256 transactionId,
        string memory description,
        uint nature//enum
    ) public returns (uint) {
        Transaction storage t = transactions[transactionId];
        require(nature == 1 || nature == 2 || nature == 3, "You must be 1,2 or 3");
        require(!t.isPaid, "-");
        require(t.isAccepted, "-");
        require(t.isBuyerDisputed && (t.buyer == msg.sender || t.validatorBuyer == msg.sender) && nature == 2, "-");
        require(t.isSellerDisputed && (t.seller == msg.sender || t.validatorSeller == msg.sender) && nature == 2, "-");
        require(t.isApprovedBuyer && (t.buyer == msg.sender || t.validatorBuyer == msg.sender) && nature == 1, "-");
        require(t.isApprovedSeller && (t.seller == msg.sender || t.validatorSeller == msg.sender) && nature == 1, "-");

        Comment[] storage _comments = comments[transactionId];

        Comment storage c = _comments[_comments.length];
        c.transactionId = transactionId;
        c.description = description;
        c.nature = nature;
        c.sort = _comments.length;

        return c.sort;
    }

    function aproveBySeller(uint256 id) external returns (uint256) {
        Transaction storage t = transactions[id];
        require(t.seller != address(0), "transaction does not have a seller");
        require(t.buyer != address(0),"transaction does not have a buyer");
        require(t.isAccepted,"transaction was not accepted");
        require(!t.isSellerDisputed,"transaction was dispuded by seller");
        require(!t.isApprovedSeller,"transaction already was approved by seller");
        require(!t.isPaid,"transaction already was paid");
        require(t.contractBalance > 0,"this id has no funds");
        require(t.validatorSeller == msg.sender,"you need to be a validator");

        t.isApprovedSeller = true;

        emit EthTransfer(msg.sender, t.validationFee);
        t.contractBalance -= t.validationFee;

        return id;
    }

    function aproveByBuyer(uint256 id) external returns (uint256) {
        Transaction storage t = transactions[id];
        require(t.seller != address(0), "transaction does not have a seller");
        require(t.buyer != address(0),"transaction does not have a buyer");
        require(t.isAccepted,"transaction was not accepted");
        require(!t.isBuyerDisputed,"transaction was dispuded by buyer");
        require(!t.isApprovedBuyer,"transaction already was approved by buyer");
        require(!t.isPaid,"transaction already was paid");
        require(t.contractBalance > 0,"this id has no funds");
        require(t.validatorBuyer == msg.sender,"you need to be a validator");

        t.isApprovedBuyer = true;

        emit EthTransfer(msg.sender, t.validationFee);
        t.contractBalance -= t.validationFee;

        return id;
    }

    function aproveByThirdValidator(uint256 id) external returns (uint256) {
        Transaction storage t = transactions[id];
        require(t.seller != address(0), "transaction does not have a seller");
        require(t.buyer != address(0),"transaction does not have a buyer");
        require(t.isAccepted,"transaction was not accepted");
        require(t.isBuyerDisputed || t.isSellerDisputed,"transaction was not dispuded by any validator");
        require(!t.isApprovedBuyer || !t.isApprovedSeller,"transaction already was approved by all validators");
        require(!t.isPaid,"transaction already was paid");
        require(t.contractBalance > 0,"this id has no funds");
        require(t.thirdValidator == msg.sender,"you need to be a validator");

        t.isThirdApproved = true;

        return id;
    }

    function disputeBySeller(uint256 id) external returns (uint256) {
        Transaction storage t = transactions[id];
        require(t.seller != address(0), "transaction does not have a seller");
        require(t.buyer != address(0),"transaction does not have a buyer");
        require(t.isAccepted,"transaction was not accepted");
        require(!t.isSellerDisputed,"transaction was dispuded by seller");
        require(!t.isApprovedSeller,"transaction already was approved by seller");
        require(!t.isPaid,"transaction already was paid");
        require(t.contractBalance > 0,"this id has no funds");
        require(t.validatorSeller == msg.sender,"you need to be a validator");

        t.isSellerDisputed = true;

        emit EthTransfer(msg.sender, t.validationFee);
        t.contractBalance -= t.validationFee;

        return id;
    }

    function disputeByBuyer(uint256 id) external returns (uint256) {
        Transaction storage t = transactions[id];
        require(t.seller != address(0), "transaction does not have a seller");
        require(t.buyer != address(0),"transaction does not have a buyer");
        require(t.isAccepted,"transaction was not accepted");
        require(!t.isBuyerDisputed,"transaction was dispuded by buyer");
        require(!t.isApprovedBuyer,"transaction already was approved by buyer");
        require(!t.isPaid,"transaction already was paid");
        require(t.contractBalance > 0,"this id has no funds");
        require(t.validatorBuyer == msg.sender,"you need to be a validator");

        t.isBuyerDisputed = true;

        emit EthTransfer(msg.sender, t.validationFee);
        t.contractBalance -= t.validationFee;

        return id;
    }
    
    /// @notice claimPayment allows the payment target to withdraw the value from the contract after the payment was validated.
    /// It also allows issuer to retrieve the money is payment was not approved.
    /// @param id is the payment ID.
    function claimPayment(uint256 id) external {
        Transaction storage t = transactions[id];
        
        require(t.seller != address(0), "transaction does not have a seller");
        require(t.buyer != address(0),"transaction does not have a buyer");
        require(t.isAccepted,"transaction was not accepted");
        require((t.isApprovedBuyer && t.isApprovedSeller) || t.isThirdApproved,"transaction was not approved");
        require(!t.isPaid,"transaction already was paid");
        require(t.contractBalance > 0,"this id has no funds");
        require(t.buyer == msg.sender,"you need to be the buyer");

        t.isPaid = true;

        emit EthTransfer(t.thirdValidator, t.thirdValidationFee);
        t.contractBalance -= t.thirdValidationFee ;
        emit EthTransfer(msg.sender, t.contractBalance);

        //emit EventApproved(id, msg.sender);
        //_transfer(payable(msg.sender), p.contractBalance); 
    }

    /// @notice returns the total locked value on the contract
    function getContractLockedValue() external view returns(uint256) {
        return contractBalance;
    }

    /// @notice returns the number of payments created on the contract.
    function getTotalPayments() external view returns (uint256) {
        return nextTransactionID - 1;
    }

     // Event emmited when a transfer is made.
    event EthTransfer(
        address  to,
        uint256  ammount
    );

    function _transfer(address payable _to, uint256 _ammount) internal {
        _to.transfer(_ammount);
        contractBalance -= _ammount;
        emit EthTransfer(_to, _ammount);
    }

    // IERCValidatable implementation

    /// @notice Get the status of an event. Status is represented by two boleans, isApproved and isFinal.
    /// @param id Identifier of the payment event.
    /// @return isAccepted bool representing if event was approved.
    /// @return isPaid bool representing if event was validated and isApproved is a final approval status.
    function getEventStatus(uint256 id) external view override returns(bool isAccepted, bool isPaid){
        Transaction storage t = transactions[id];
        require(t.buyer != address(0) || t.seller != address(0), "transaction id doesn't exist.");
        return (t.isAccepted, t.isPaid);
    }

    /// @notice Returns possible addresses that can validate the event with paymentID.
    /// @param id Identifier of the event.
    /// @return address of validator.
    function getEventValidators(uint256 id) external view override returns(address[] memory){ 
        Transaction storage t = transactions[id];
        require(t.buyer != address(0) || t.seller != address(0), "transaction id doesn't exist.");

        

        address[] memory validators = new address[](3);
        validators[0] = t.validatorBuyer;
        validators[1] = t.validatorSeller;
        validators[2] = t.thirdValidator;



        return validators;
    }

    /// @notice Returns a boolean if the address is a possible event validator. 
    /// @param id Identifier of the event.
    /// @param validator Address of the possible validator.
    /// @return bool representing if validator can approve or reject the event with paymentID.
    function isEventValidator(uint256 id, address validator) external view override returns(bool){ 
        Transaction storage t = transactions[id];
        require(t.buyer != address(0) || t.seller != address(0), "transaction id doesn't exist.");
        return t.validatorBuyer == validator || t.validatorSeller == validator || t.thirdValidator == validator;
    }
}