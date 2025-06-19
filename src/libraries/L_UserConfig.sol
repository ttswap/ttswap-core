// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @title Market Configuration Library
/// @notice Library for managing and calculating various fee configurations for a market
library L_UserConfigLibrary {
    function isDAOAdmin(uint256 config) internal pure returns(bool a){
        return (config&uint256(2**255))>0;
    }

    function setDAOAdmin(uint256 config,bool a)internal pure  returns(uint256 e){
        return (config&(~(uint256(2**255))))|(a?0:uint256(2**255));
    }

    function isTokenAdmin(uint256 config) internal pure returns(bool a){
        return (config&uint256(2**254))>0;
    }

    function setTokenAdmin(uint256 config,bool a)internal pure  returns(uint256 e){
        return config&~(uint256(2**254))|(a?0:uint256(2**254));
    }

    function isTokenManager(uint256 config) internal pure returns(bool a){
        return (config&uint256(2**253))>0;
    }

    function setTokenManager(uint256 config,bool a)internal pure  returns(uint256 e){
        return config&~(uint256(2**253))|(a?0:uint256(2**253));
    }

    function isMarketAdmin(uint256 config)internal pure returns(bool a){
        return (config&uint256(2**252))>0;
    }

    function setMarketAdmin(uint256 config,bool a)internal pure  returns(uint256 e){
        return config&~(uint256(2**252))|(a?0:uint256(2**252));
    }

    function isMarketManager(uint256 config)internal pure returns(bool a){
        return (config&uint256(2**251))>0;
    }

    function setMarketManger(uint256 config,bool a)internal pure  returns(uint256 e){
        return config&~(uint256(2**251))|(a?0:uint256(2**251));
    }

    function isCallMintTTS(uint256 config)internal pure returns(bool a){
        return (config&uint256(2**250))>0;
    }

    function setCallMintTTS(uint256 config,bool a)internal pure returns(uint256 e){
        return config&~(uint256(2**250))|(a?0:uint256(2**250));
    }

    function isTrue(uint256 config,uint8 b)internal pure returns(bool a){
        return (config&uint256(2**b))==0;
    }

    function setTrue(uint256 config,uint8 a,bool b)internal pure returns(uint256 e){
        if(a<=240 && a>170 ) return config&~(uint256(2**a))|(b?0:uint256(2**a));
    }

    function isBan(uint256 config)internal pure returns(bool a){
        return (config&uint256(2**160))==0;
    }

    function setBan(uint256 config,bool a)internal pure returns(uint256 e){
        return config&~(uint256(2**160))|(a?0:uint256(2**161));
    }

    function refer(uint256 config)internal pure returns(address a){
        return address(uint160(config));
    }

    function setRefer(uint256 config,address a)internal pure returns(uint256 e){
        return (config&~(uint256(2**160)-1))|uint256(uint160(a));
    }

}
