// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library L_ArrayStorage {
    struct S_ArrayStorage {
        uint256 key;
        mapping(uint256 => uint256) key_value;
        mapping(uint256 => uint256) value_key;
    }

    function addvalue(S_ArrayStorage storage _self, uint256 _value) internal {
        _self.key += 1;
        _self.key_value[_self.key] = _value;
        _self.value_key[_value] = _self.key;
    }

    function removevalue(S_ArrayStorage storage _self, uint256 _value) internal {
        _self.key_value[_self.value_key[_value]] = _self.key_value[_self.key];
        _self.key -= 1;
    }

    function removekey(S_ArrayStorage storage _self, uint256 _key) internal {
        _self.key_value[_key] = _self.key_value[_self.key];
        _self.key -= 1;
    }
}
