// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAO {
    enum Side {Approve, Reject}
    enum Status {Undecided, Approved, Reject}
    struct Proposal {
        address author;
        bytes32 hash; // hash of the proposal
        uint createdAt; // Block number when the proposal was created
        uint votesApprove;
        uint votesReject;
        Status status;
        uint limitPeriod;
    }

    mapping(bytes32 => Proposal) public proposals;
    mapping(address => mapping(bytes32 => Side)) public votes;
                              // voteHash => vote
    mapping(address => uint) public shares;
    IERC20 public token;
    uint constant CREATE_PROPOSAL_MIN_SHARE = 1000 * 10 ** 18;
    uint public votingPeriod;
    uint public totalShares;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function deposit(uint _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        token.transferFrom(msg.sender, address(this), _amount);
        shares[msg.sender] += _amount;
        totalShares += _amount;
    }

    function withdraw(uint _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(shares[msg.sender] >= _amount, "Not enough shares");
        token.transfer(msg.sender, _amount);
        shares[msg.sender] -= _amount;
        totalShares -= _amount;
    }

    function createProposal(bytes32 _proposalHash, uint limitPeriod) external {
        require(shares[msg.sender] >= CREATE_PROPOSAL_MIN_SHARE, 
        "Not enough shares to create a proposal");
        require(proposals[_proposalHash].hash == bytes32(0), 
// 0 is the default for a hash that is empty, it means that this proposal is new 
        "Proposal already exists");
        require(limitPeriod > 3 days, "Limit period must be greater than 3 days");
        Proposal memory proposal = Proposal(
            msg.sender,
            _proposalHash,
            block.timestamp, 
            0, 
            0, 
            Status.Undecided,
            limitPeriod);
    }

    modifier checkLimitPeriod(bytes32 _proposalHash) {
        require(block.timestamp - proposals[_proposalHash].createdAt < proposals[_proposalHash].limitPeriod, 
        "Time limit for voting has passed");
        _;
    }

    function voteProposal(bytes32 _proposalHash, Side _vote)
     external 
     checkLimitPeriod(_proposalHash) {
        require(votes[msg.sender][_proposalHash] != _vote, "Already voted");
        require(proposals[_proposalHash].status == Status.Undecided, 
        "Proposal must be undecided");
        votes[msg.sender][_proposalHash] = _vote;
        if (_vote == Side.Approve) {
            proposals[_proposalHash].votesApprove += shares[msg.sender];
        } else if (_vote == Side.Reject) {
            proposals[_proposalHash].votesReject += shares[msg.sender];
        }

        if (proposals[_proposalHash].votesApprove * 100 / totalShares > 50) {
            proposals[_proposalHash].status = Status.Approved;
        } else if (proposals[_proposalHash].votesReject * 100 / totalShares >= 50) {
            proposals[_proposalHash].status = Status.Reject;
        }
    }
}