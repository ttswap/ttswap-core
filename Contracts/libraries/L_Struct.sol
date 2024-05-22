// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {T_BalanceUINT256} from "./L_BalanceUINT256.sol";

struct S_GoodKey {
    address erc20address;
    address owner;
}

struct S_ProofKey {
    address owner;
    uint256 currentgood;
    uint256 valuegood;
}

struct S_Ralate {
    address gater;
    address refer;
}
