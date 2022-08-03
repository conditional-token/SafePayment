// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

// ValidableEvent is an interface to represent a validatable event.
// An event can represent anything. It must have an unique ID which identifies it.
// The contract that implements should have it's own policy of event validation. 
// The event might have a approvalRate and any logic can be associated with it, since approve and reject functions both accept a rate.
interface ValidableEvent {

  /// @notice Get the status of an event. Status is represented by two boleans, isApproved and isFinal.
  /// @param eventID Identifier of the event.
  /// @return isApproved bool representing if event was approved.
  /// @return isFinal bool representing if event was validated and isApproved is a final approval status.
  function getEventStatus(uint256 eventID) external view returns(bool isApproved, bool isFinal);

  /// @notice Get the approval and reject rates of the event.
  /// @param eventID Identifier of the event.
  /// @return approvalRate uint256 representing the rate of approval.
  /// @return rejectRate uint256 representing the rate of rejection.
  function getEventRates(uint256 eventID) external view returns(uint256 approvalRate, uint256 rejectRate);

  /// @notice Returns possible addresses that can validate the event with eventID.
  /// @param eventID Identifier of the event.
  /// @return address of validator.
  function getEventValidators(uint256 eventID) external view returns(address[] memory);

  /// @notice Returns a boolean if the address is a possible event validator. 
  /// @param eventID Identifier of the event.
  /// @param validator Address of the possible validator.
  /// @return bool representing if validator can approve or reject the event with eventID.
  function isEventValidator(uint256 eventID, address validator) external view returns(bool);

  /// @notice allows sender to reject an event. Should raise error if event was already validated.
  /// @param eventID Identifier of the event.
  /// @param rejectRate A rate that can be used by contracts to measure approval when needed.
  function rejectEvent(uint256 eventID, uint256 rejectRate) external;
  
  /// @notice allows sender to approve an event. Should raise error if event was already validated.
  /// @param eventID Identifier of the event.
  /// @param approvalRate A rate that can be used by contracts to measure approval when needed.
  function approveEvent(uint256 eventID, uint256 approvalRate) external;

  /// @notice should return the issuer of the event.
  /// @param eventID Identifier of the event.
  /// @return address of the issuer.
  function issuerOf(uint256 eventID) external view returns (address);

  // Event emmited when an event is created.
  event EventCreated(
    uint256 indexed eventID,
    address indexed issuer,
    address[] parties,
    address[] validators
  );

  // Event emmited when an event is approved.
  event EventApproved(
    uint256 indexed eventID,
    address indexed validator,
    uint256 approvalRate
  );

  // Event emmited when an event is revoked.
  event EventRejected(
    uint256 indexed eventID,
    address indexed validator,
    uint256 rejectionRate
  );
}