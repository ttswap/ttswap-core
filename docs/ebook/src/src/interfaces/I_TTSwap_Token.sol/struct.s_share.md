# s_share
Struct for share information

Contains information about a share, including the amount of left to unlock, the metric, and the chips


```solidity
struct s_share {
uint128 leftamount; // unlock amount
uint120 metric; //last unlock's metric
uint8 chips; // define the share's chips, and every time unlock one chips
}
```

