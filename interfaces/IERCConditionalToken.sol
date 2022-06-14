// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

interface IERCConditional {
  // Allow validators to revoke the condition
  function revokeCondition(uint256 conditionID, uint256 value) external returns(bool);
  // Allows validators to approve a specific condition
  function approveCondition(uint256 conditionID, uint256 value) external returns(bool);

  // valueLeft = totalConditionVal - approvedVal - revokedVal
  function valueLeft(uint256 conditionID) external view returns(uint256);

  // issuerOf should return all the condition ids where argument address is the issuer.
  function issuerOf(address issuer) external view returns (uint256[] calldata);
  // issuerOf should return all the condition ids where argument address is the validator.
  function validatorOf(address validator) external view returns (uint256[] calldata);
  // issuerOf should return all the condition ids where argument address is the spender.
  function spenderOf(address spender) external view returns (uint256[] calldata);

  event ConditionCreated(
    uint256 indexed conditionID,
    address indexed issuer,
    address indexed spender,
    uint256 totalValue
  );

  event ConditionApproved(
    uint256 indexed conditionID,
    address indexed validator,
    bool value
  );

  event ConditionRevoked(
    uint256 indexed conditionID,
    address indexed validator,
    bool value
  );
}