// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

// IERCConditional is an interface to represent a validatable token.
interface IERCValidatable {

  /// @notice Get the status of a condition. Status is represented by two boleans, isApproved and isValidated.
  /// @param conditionID Identifier of the condition.
  /// @return isApproved bool representing if condition was approved.
  /// @return isValidated bool representing if condition was validated. A validated condition has it's isApproved status as final.
  function getConditionStatus(uint256 conditionID) external view returns(bool isApproved, bool isValidated);

  /// @notice Returns who validated the condition. If condition was not yet validated, raises an error.
  /// @param conditionID Identifier of the condition.
  /// @return address of validator.
  function getConditionValidator(uint256 conditionID) external view returns(address);

  /// @notice allows sender to reject a condition.  Should raise error if condition was already validated.
  /// @param conditionID Identifier of the condition.
  function rejectCondition(uint256 conditionID) external;
  
  /// @notice allows sender to approve a condition. Should raise error if condition was already validated.
  /// @param conditionID Identifier of the condition.
  function approveCondition(uint256 conditionID) external;

  /// @notice should return the issuer of the condition.
  /// @param conditionID Identifier of the condition.
  /// @return address of the issuer.
  function issuerOf(uint256 conditionID) external view returns (address);

  // Event emmited when a condition is created.
  event ConditionCreated(
    uint256 indexed conditionID,
    address indexed issuer
  );

  // Event emmited when a condition is approved.
  event ConditionApproved(
    uint256 indexed conditionID,
    address indexed validator
  );

  // Event emmited when a condition is revoked.
  event ConditionRevoked(
    uint256 indexed conditionID,
    address indexed validator
  );
}