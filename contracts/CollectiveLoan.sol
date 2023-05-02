// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/IERCValidableEvent.sol";

// SafePayment main contract for a safe payment platform.
// A safe payment event is a payment that can be validated by another party.
contract CollectiveLoan is ValidableEvent {

    //tem sim que ter dois tipos de transação, uma coletiva para arrecadar os fundos e outra para devolver o valor pago
    //os detalhes da transação ficaram em texto livre para interpretação da aplicação cliente
    //quem verifica data, taxa de juros e pagamentos são os validadores
    //fazer calculo de juros e verificação de data foge do padrão, em vez disso colocar um mecanismo de críticas e penalidades

    struct CollectivePayment {
        // Involved Parties
        //invested value != 0 returns the same of isInvester
        //mapping(address => bool) isInvester; // issuer address of the payment issuer.
        address receiver; // Original Receiver
        //uint256 id;
        string description;//describe loan fees, due dates and any loan detail

        // Validators are the possible transaction validators.
        mapping(address => bool) isValidator; // mapping for quick check of validators.
        address[] validators; // list of validators.
        address[] investers; // list of possible issuers.

        // Flags
        bool isCreated; // achieved the necessary ammount
        bool isRefunded; // the fund returns to the investers (if it was not created)
        bool isPaid; // if the payment was already made.
        //it doesnt need this. negative comments just do that
        //bool isRegular;//with no debits or questions, default is true. any investitor may set this. with this seted, the payment can not be done
        
        // Values
        mapping(address => uint256) investedValues; // represents the values that was paid by the issuers
        uint256 dueValue; // represents the value that must be paid to investers.
        uint256 paymentValue; // represents the value that must be paid to receiver.
        mapping(address => uint) validationFees; // represents the value that will be paid for the validator.

        uint256 contractBalance;

        uint256 nextCommentID;// = 1;
    }
    
    struct Comment {// critica que pode ser positiva ou negativa
        uint256 paymentId;
        uint nature;//0: neutral (validator describe payment of fee), 1: complaint, 2: severe
        string description;
        uint sort;
    }

    // Mapping from paymentID to transaction.
    mapping(uint256 => CollectivePayment) public payments;
    mapping(uint256 => Comment[]) public paymentComments;
    uint256 nextPaymentID = 1;

    // Contract ethereum balance
    uint256 private balance;

    // Indexes
    mapping(address => uint256[]) private investitorIndex;
    mapping(address => uint256[]) private validatorIndex;
    mapping(address => uint256[]) private receiverIndex;

    //address payable public owner;
    //set the owner to the msg.sender 
    //constructor () { 
    //    owner = payable(msg.sender); 
    //}

    //create a modifier that the msg.sender must be the owner modifier 
    //modifier onlyOwner {
    //    require(msg.sender == owner, 'Not owner'); 
    //    _;
    //} 

    
    function checkValidators(address[] memory _validators, address _receiver) private pure returns (bool) {
        unchecked { 
            
            address[] memory _vals = _validators;
            for (uint i =0; i < _vals.length; i = unsafe_inc(i)){
                if(_vals[i] == _receiver){
                    return false;
                }
            }

            return true;
            
        }
    }


    /// @notice is the payment event constructor.
    /// @param paymentId -
    /// @param description -
    /// @param nature -
    function createComment(
        uint256 paymentId,
        string memory description,
        uint nature//enum
    ) public returns (uint) {
        CollectivePayment storage p = payments[paymentId];
        require(p.investedValues[msg.sender] > 0, "You must be an invester");
        //require(description != string(""), "You must have a message");
        require(nature == 1 || nature == 2 || nature == 3, "You must be 1,2 or 3");

        Comment[] storage _comments = paymentComments[paymentId];

        Comment storage c = _comments[_comments.length];
        c.paymentId = paymentId;
        c.description = description;
        c.nature = nature;
        c.sort = _comments.length;

        return c.sort;
    }

    /// @notice is the payment event constructor.
    /// @param paymentValue is the value that must be paid to payable to. It must be sent in the tx value.
    /// @param dueValue is the value that must be paid to payable to. It must be sent in the tx value.
    /// @param validationFees is the fee for each validator
    /// @param issuerValidationFee is the fee for issuer validator
    /// @param receiver the address that this payment is addressed to.
    /// @param validators an array of addresses that can validate this payment.
    function createLoan(
        uint256 paymentValue,
        uint256 dueValue,
        uint[] calldata validationFees,
        uint issuerValidationFee,
        address receiver,
        address[] calldata validators
    ) public returns (uint256) {
        //require(paymentValue + validationFee == msg.value, "Value must be equal paymentValue and validationFee");
        require(validationFees.length == validators.length, "You need to arg diferent fees for all validators");
        //receiver diferente de todos os validadores inclusive do criador
        require(receiver != msg.sender, "Receiver is the same of issuer");
        //retirado porque o recebedor pode receber o repace do validador
        //require(checkValidators(validators,receiver), "Receiver may not be any validator");
        uint256 paymentID = nextPaymentID;
        nextPaymentID++;

        CollectivePayment storage p = payments[paymentID];
        p.paymentValue = paymentValue;
        p.dueValue = dueValue;
        p.receiver = receiver;
        p.validators = validators;
        for(uint256 i=0; i < p.validators.length; i++) {
            p.isValidator[validators[i]] = true;
            // validator index
            validatorIndex[validators[i]].push(paymentID);
            p.validationFees[validators[i]] = validationFees[i];
        }
        p.validators[validators.length] = msg.sender;
        p.isValidator[p.validators[validators.length]] = true;
        p.validationFees[p.validators[validators.length]] = issuerValidationFee;
        validatorIndex[p.validators[validators.length]].push(paymentID);

        receiverIndex[receiver].push(paymentID);

        address[] memory parties = new address[](1);
        parties[0] = receiver;
        emit EventCreated(paymentID, msg.sender, parties, validators);

        return paymentID;
    }

    
    /// @notice add new investitor in this loan.
    /// @param _ammount is the value that must be paid
    /// @param paymentId is the value that must be paid to payable to. It must be sent in the tx value.
    function addInvestitor(
        uint256 _ammount,
        uint256 paymentId
    ) public payable returns (uint256) {
        CollectivePayment storage p = payments[paymentId];
        require(p.paymentValue >= _ammount, "Value must be greater or equal to paymentValue");

        _transfer(payable(address(this)), _ammount);

        balance += _ammount;
        p.contractBalance += _ammount;

        p.investers[p.investers.length] = msg.sender;
        //p.isInvester[p.investers[p.investers.length]] = true;
        investitorIndex[p.investers[p.investers.length]].push(paymentId);
        p.investedValues[p.investers[p.investers.length]] = _ammount;


        //address[] memory parties = new address[](1);

        //emit EventCreated(paymentId, msg.sender, parties, _ammount);

        return paymentId;
    }

    /// @notice returns the total locked value on the contract
    function getContractLockedValue() external view returns(uint256) {
        return balance;
    }

    /// @notice returns the number of payments created on the contract.
    function getTotalPayments() external view returns (uint256) {
        return nextPaymentID - 1;
    }

    /// @notice is the getter for all ids of payments where address passed is a validator
    /// @param validator address of the validator.
    function getValidatorIndex(address validator) external view returns(uint256[] memory paymentIDs ) {
        return validatorIndex[validator];
    }

    /// @notice is the getter for all ids of payments where address passed is an issuer
    /// @param issuer address of the issuer.
    function getIssuerIndex(address issuer) external view returns(uint256[] memory paymentIDs ) {
        return investitorIndex[issuer];
    }

    /// @notice is the getter for all ids of payments where address passed is a receiver
    /// @param receiver address of the receiver.
    function getReceiverIndex(address receiver) external view returns(uint256[] memory paymentIDs ) {
        return receiverIndex[receiver];
    }

     // Event emmited when a transfer is made.
    event EthTransfer(
        address  to,
        uint256  ammount
    );

    function _transfer(address payable _to, uint256 _ammount) internal {
        _to.transfer(_ammount);
        balance -= _ammount;
        emit EthTransfer(_to, _ammount);
    }

    function _transferAll(address[] memory _to, uint256[] memory _ammount) internal {
        require(_to.length == _ammount.length, "provide all the values.");
        for(uint256 i=0; i < _to.length; i++) {
            payable(_to[i]).transfer(_ammount[i]);
            balance -= _ammount[i];
            emit EthTransfer(_to[i], _ammount[i]);
        }
    }





















    /// @notice allows sender to approve an event. Should raise error if event was already validated.
    /// @param paymentID Identifier of the event.
    /// @param approvalRate A rate that can be used by contracts to measure approval when needed.
    function approveEvent(uint256 paymentID, uint256 approvalRate) external override {
        CollectivePayment storage p = payments[paymentID];
        require(p.receiver != address(0), "payment id doesn't exist.");
        require(!p.isCreated, "payment was created.");
        //será que tem que ser um dos validadores?
        require(p.receiver == msg.sender,"msg.sender is not the receiver of the payment.");
        require(p.contractBalance >= p.paymentValue, "the ammount is not enouth");

        p.isCreated = true;

        (bool success,  bytes memory data) = payable(msg.sender).call{value:p.contractBalance}("");

        if(success){
            emit EthTransfer(msg.sender, p.contractBalance);
            p.contractBalance = 0;   
        }

        emit EventApproved(paymentID, msg.sender, approvalRate);
        //_transfer(payable(msg.sender), p.contractBalance); 
    }

    function unsafe_inc(uint x) private pure returns (uint) {
        unchecked { return x + 1; }
    }

    // function payFees(uint256 paymentID) external {
    //     Payment storage p = payments[paymentID];
    //     require(p.receiver != address(0), "payment id doesn't exist.");
    //     require(p.isCreated, "payment was not created.");
    //     require(p.receiver == msg.sender,"msg.sender is not the receiver of the payment.");
    //     require(block.timestamp < p.dueDate, "due date is future");

    //     //fees = array de valores feito sem gastar gas
    //     //incluir tb a quantidade de dias para faturamento

    //     uint _fee = p.loanFee;
    //     uint[] memory _fees = new uint[](p.investers.length);
    //     address[] memory _investers = p.investers;
    //     for (uint i =0; i < _fees.length; i = unsafe_inc(i)){
    //         _fees[i] = p.investedValues[_investers[i]] * (_fee / 100);
    //     }

    //     _transferAll(p.investers, _fees);
    //     uint _days = p.dueDays;
    //     p.dueDate = p.dueDate + (_days * 60 * 60 * 24);
    // }

    function due(uint256 paymentID, address invester) private view returns(uint256 dueValue){
        CollectivePayment storage p = payments[paymentID];
        require(p.investedValues[invester] > 0, "this address is not an invester of this loan");
        uint256 _value = p.investedValues[invester];
        uint256 _due = p.dueValue / _value;
        if(_due > 0){
            if(_due > _value){
                return _due;
            }
            return _value;
        }
        return 0;
    }

    function pay(uint256 paymentID) external {
        CollectivePayment storage p = payments[paymentID];
        require(p.receiver != address(0), "payment id doesn't exist.");
        require(p.isCreated, "payment was not created.");
        require(p.receiver == msg.sender,"msg.sender is not the receiver of the payment.");
        //require(block.timestamp < p.dueDate, "due date is past");

        //fees = array de valores feito sem gastar gas
        //incluir tb a quantidade de dias para faturamento

        uint256[] memory _values = new uint[](p.investers.length);
        address[] memory _investers = p.investers;
        for (uint i =0; i < _values.length; i = unsafe_inc(i)){
            //_values[i] = p.investedValues[_investers[i]];
            _values[i] = due(paymentID, _investers[i]);
        }

        _transferAll(p.investers, _values);
        
        p.isPaid = true;
    }

    // IERCValidatable implementation

    /// @notice Get the status of an event. Status is represented by two boleans, isApproved and isFinal.
    /// @param paymentID Identifier of the payment event.
    /// @return isApproved bool representing if event was acchieved the necessary ammounto to be loan.
    /// @return isFinal bool representing if event was paid back to investitors.
    function getEventStatus(uint256 paymentID) external view override returns(bool isApproved, bool isFinal){
        CollectivePayment storage p = payments[paymentID];
        require(p.receiver != address(0), "payment id doesn't exist.");
        return (p.isCreated, p.isPaid);
    }

    // nao sei para que serve
    /// @notice Get the approval and reject rates of the event.
    /// For the payment contract, rates are not used.
    /// @param paymentID Identifier of the event.
    /// @return approvalRate uint256 representing the rate of approval.
    /// @return rejectRate uint256 representing the rate of rejection.
    function getEventRates(uint256 paymentID) external view override returns(uint256 approvalRate, uint256 rejectRate) {
        CollectivePayment storage p = payments[paymentID];
        require(p.receiver != address(0), "payment id doesn't exist.");
        if (p.isCreated && p.isPaid) {
            return (1, 0);
        }
        return (0,0);
    }

    /// @notice Returns possible addresses that can validate the event with paymentID.
    /// @param paymentID Identifier of the event.
    /// @return address of validator.
    function getEventValidators(uint256 paymentID) external view override returns(address[] memory){ 
        CollectivePayment storage p = payments[paymentID];
        require(p.receiver != address(0), "payment id doesn't exist.");
        return p.validators;
    }

    /// @notice Returns a boolean if the address is a possible event validator. 
    /// @param paymentID Identifier of the event.
    /// @param validator Address of the possible validator.
    /// @return bool representing if validator can approve or reject the event with paymentID.
    function isEventValidator(uint256 paymentID, address validator) external view override returns(bool){ 
        CollectivePayment storage p = payments[paymentID];
        require(p.receiver != address(0), "payment id doesn't exist.");
        return p.isValidator[validator];
    }


    /// @notice allows sender to refund an event. Should raise error if event was already created.
    /// For this contract, rates are ignored.
    /// @param paymentID Identifier of the event.
    /// @param rejectRate A rate that can be used by contracts to measure approval when needed.
    function rejectEvent(uint256 paymentID, uint256 rejectRate) external override {
        CollectivePayment storage p = payments[paymentID];
        require(p.receiver != address(0), "payment id doesn't exist.");
        require(!p.isCreated, "loan was already created");
        require(!p.isRefunded, "loan was already refunded");
        require(!p.isPaid, "loan was already paid");
        require(p.isValidator[msg.sender], "msg.sender is not a valid validator for the payment");

        p.isRefunded = true;
        //_transfer(payable(msg.sender), p.validationFee);

        

        uint256[] memory _values;// = new uint[](p.validationFees.length);
        address[] memory _investers = p.investers;
        for (uint i =0; i < _investers.length; i = unsafe_inc(i)){
            _values[i] = p.investedValues[_investers[i]];
        }

        _transferAll(_investers, _values);


        emit EventRejected(paymentID, msg.sender, rejectRate);
    }

    /// @notice should return the issuer of the event.
    /// @param paymentID Identifier of the event.
    /// @return address of the issuer.
    function issuerOf(uint256 paymentID) external view override returns (address) {
        CollectivePayment storage p = payments[paymentID];
        require(p.receiver != address(0), "payment id doesn't exist.");

        address[] memory _validators = p.validators;
        
        return _validators[_validators.length-1];
    }
}