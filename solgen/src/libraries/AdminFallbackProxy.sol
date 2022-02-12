// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";


/// @dev similar to TransparentUpgradeableProxy but allows the admin to fallback to
/// a separate logic contract
contract AdminFallbackProxy is TransparentUpgradeableProxy {
    using Address for address;

    // we hardcode the result of bytes32(uint256(keccak256("proxy.admin.fallback.logic")) - 1)
    // since hashes aren't evaluated during compile time
    bytes32 internal constant _ADMIN_LOGIC_SLOT = 0x0ec14cccd309f3d73c97ec9ccd142d751d5c2a665ea2437991839ee618e56b45;

    function _getAdminFallbackLogic() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_LOGIC_SLOT).value;
    }

    constructor(
        address userLogic,
        bytes memory userData,
        address adminLogic,
        bytes memory adminData,
        address adminAddr
    ) payable TransparentUpgradeableProxy(userLogic, adminAddr, userData) {
        assert(_ADMIN_LOGIC_SLOT == bytes32(uint256(keccak256("proxy.admin.fallback.logic")) - 1));
        _upgradeAdminFallbackToAndCall(adminLogic, adminData, false);
    }

    /**
     * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation()
        internal
        view
        override
        returns (address)
    {
        require(msg.data.length >= 4, "NO_FUNC_SIG");
        address _admin = _getAdmin();
        // if there is an owner and it is the sender, delegate to admin logic
        address target = _admin != address(0) && _admin == msg.sender
            ? _getAdminFallbackLogic()
            : _implementation();
        require(target.isContract(), "TARGET_NOT_CONTRACT");
        return target;
    }

    /// @dev this allows the admin to access the fallback function, but we direct them
    /// to a different logic contract implementation. If the same function signature
    /// is available in both the proxy and logic, the proxy will logic will execute.
    function _beforeFallback() internal override {
        // we override the superclass _beforeFallback to remove 
        // the `require(msg.sender != _getAdmin())` check
    }

    event AdminFallbackUpgraded(address indexed implementation);

    function _upgradeAdminFallbackTo(address newImplementation) internal {
        StorageSlot.getAddressSlot(_ADMIN_LOGIC_SLOT).value = newImplementation;
        emit AdminFallbackUpgraded(newImplementation);
    }

    function _upgradeAdminFallbackToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeAdminFallbackTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    function upgradeAdminFallbackTo(address newImplementation) external ifAdmin {
        _upgradeAdminFallbackToAndCall(newImplementation, bytes(""), false);
    }

    function _upgradeAdminFallbackToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
        _upgradeAdminFallbackToAndCall(newImplementation, data, true);
    }
}
