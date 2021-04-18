# Impartial Peer Selection on Ethereum
Code developed as part of the *"Design, implementation and optimization of an impartial peer selection mechanism on Ethereum"* thesis work by Giovanni Rescinito.

Part of this work is based on Exact Dollar Partition, described in the following papers:

>[Strategyproof Peer Selection. Haris Aziz, Omer Lev, Nicholas Mattei, Jeffery S. Rosenschein, and Toby Walsh. arXiv:1604.03632](http://arxiv.org/abs/1604.03632)
>
>
>[Strategyproof Peer Selection: Mechanisms, Analyses, and Experiments. Haris Aziz, Omer Lev, Nicholas Mattei, Jeffery S. Rosenschein, and Toby Walsh. 30th AAAI Conference on Artificial Intelligence (AAAI 2016), Feb. 2016](http://www.nickmattei.net/docs/prize.pdf)

and whose code can be found at
[https://github.com/nmattei/peerselection](https://github.com/nmattei/peerselection)

## Repository Organization
- **node_modules**: support contracts provided by [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)
- **results**: json files with experimental results, a folder for each implementation proposed
- **source**: contracts developed as part of the system, a folder for each implementation proposed
- *results.xlsx*: contains tables containing the results produced and plots obtained from them
- *results_reader.py*: code used to generate the results.xlsx file from the json results

## Installation and Usage
[Truffle Suite](https://www.trufflesuite.com/) is required to test the contracts
```
npm install -g truffle
npm install -g ganache-cli
```
After moving to the folder containing a generic implementation **?**
```
cd ./source/?
```
a test blockchain can be started using
```
ganache-cli -p 7545 -i 5777
```
Then the contracts can be deployed to the blockchain using
```
truffle migrate --reset
```
and the tests can be executed by running
```
truffle exec test.js
```

**To test a specific combination of parameters it is required to set ```paper=false``` in the *test.js* file and to update the values contained in the variables indicated by comments**

## License
Following code is provided under **MIT License**
