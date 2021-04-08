const crypto = require('crypto');
const fs = require('fs');
const C = 1000000;

const Allocations = artifacts.require("Allocations");
const ExactDollarPartition = artifacts.require("ExactDollarPartition");
const ExactDollarPartitionMap = artifacts.require("ExactDollarPartitionMap");
const ExactDollarPartitionMatrix = artifacts.require("ExactDollarPartitionMatrix");
const Phases = artifacts.require("Phases");
const Proposals = artifacts.require("Proposals");
const Scores = artifacts.require("Scores");

const ImpartialSelectionMatrix = artifacts.require("ImpartialSelectionMatrix");
const ImpartialSelectionMap = artifacts.require("ImpartialSelectionMap");

const Token = artifacts.require("Token");

var l, m, n, k, randomness, messages, commitments, assignments, evaluations, s, tokens, imp, token, accounts, gas, score, params, paper;

var folder = "../../results/OPTIMIZED/"
module.exports = async function (callback) {
    fs.mkdir(folder, { recursive: true },(err) =>{if (err) throw err;})
    paper = true
    await initialize();
    if (paper) {
        k = 5;
        n = 8;
        l = 4;
        m = 2;
        offchain = true
        revPerc = 1
        score = 'MATRIX'
        file = folder + "paper_matrix.json"
        await main()
        score = 'MAP'
        file = folder + "paper_map.json"
        await main()
    } else {
        ls = [3, 4, 5]
        ns = [10, 15, 20, 30, 50, 75]
        ks = [5, 15, 25]
        ms = [3, 7, 11, 15]
        scs = ['MAP','MATRIX']
        offchains = [true, false]
        revPercs = [0.75, 1]
        for (i0 = 0; i0 < ls.length; i0++) {
            l = ls[i0]
            for (i1 = 0; i1 < ns.length; i1++) {
                n = ns[i1]
                for (i2 = 0; i2 < ks.length; i2++) {
                    k = ks[i2]
                    for (i3 = 0; i3 < ms.length; i3++) {
                        m = ms[i3]
                        for (i4 = 0; i4 < scs.length; i4++) {
                            score = scs[i4]
                            for (i5 = 0; i5 < offchains.length; i5++) {
                                offchain = offchains[i5]
                                for (i6 = 0; i6 < revPercs.length; i6++) {
                                    revPerc = revPercs[i6]
                                    if (checkConditions()) {
                                        file = folder + `l${l}_n${n}_m${m}_k${k}_scores_${score}_offChain_${offchain}_revPerc_${revPerc}.json`
                                        // if (fs.existsSync(file)) {
                                        //     f = fs.readFileSync(file)
                                        //     json = JSON.parse(f)
                                        //     if (json['params']['Selection Completed']==false){
                                        //         await main()
                                        //     }else{
                                        //         console.log("skipped")
                                        //     }
                                        //     continue
                                        // }
                                        await main()
                                    } else {
                                        continue
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    callback()
}

function checkConditions() {
    return ((n >= 2*k) && (n > (l * 1.5)) && (m<=(n*(l-1)/l)))
}

async function main() {
    try {
        await initializeVariables();
        await createNewContract();
        await submission()
        await partition()
        await assignment()
        await evaluation()
        await commit()
        await reveal()
        try {
            await selection()
            params['Selection Completed'] = true
        } catch (error) {
            console.error(error)
            console.log("\n\n\nSELECTION FAILED!\n\n\n")
            params['Selection Completed'] = false
        }
        gas['total'] = gasConsumption(gas)
        console.log("\nExperiment Parameters", params, "\n")
        console.log("Gas Consumption\n\n", gas)
    } catch (error) {
        console.error(error)
        params['Selection Completed'] = false
    }
    results = { params, gas }
    fs.writeFileSync(file, JSON.stringify(results));
}

async function initialize() {
    accounts = await web3.eth.getAccounts()
    token = await Token.deployed()

    var all = await Allocations.deployed()
    var exact = await ExactDollarPartition.deployed()
    var exact_map = await ExactDollarPartitionMap.deployed()
    var exact_matrix = await ExactDollarPartitionMatrix.deployed()
    var phases = await Phases.deployed()
    var prop = await Proposals.deployed()
    var scores = await Scores.deployed()

    await ImpartialSelectionMap.detectNetwork();
    await ImpartialSelectionMap.link("Allocations", all.address);
    await ImpartialSelectionMap.link("ExactDollarPartition", exact.address);
    await ImpartialSelectionMap.link("ExactDollarPartitionMap", exact_map.address);
    await ImpartialSelectionMap.link("Phases", phases.address);
    await ImpartialSelectionMap.link("Proposals", prop.address);
    await ImpartialSelectionMap.link("Scores", scores.address);

    await ImpartialSelectionMatrix.detectNetwork();
    await ImpartialSelectionMatrix.link("Allocations", all.address);
    await ImpartialSelectionMatrix.link("ExactDollarPartition", exact.address);
    await ImpartialSelectionMatrix.link("ExactDollarPartitionMatrix", exact_matrix.address);
    await ImpartialSelectionMatrix.link("Phases", phases.address);
    await ImpartialSelectionMatrix.link("Proposals", prop.address);
}

async function createNewContract() {
    if (score == 'MAP') {
        imp = await ImpartialSelectionMap.new(token.address, { from: accounts[0] })
    } else if (score == 'MATRIX') {
        imp = await ImpartialSelectionMatrix.new(token.address, { from: accounts[0] })
    }
    finalize = await imp.finalizeCreation();
    deploy = await web3.eth.getTransactionReceipt(imp.transactionHash)
    gas['deployment'] = deploy.cumulativeGasUsed
    gas['finalization'] = finalize.receipt.gasUsed
    console.log("\n\nSmart contract created at " + imp.address + "\n")
}

async function initializeVariables() {
    randomness = new Uint32Array(n);
    messages = [];
    commitments = [];
    assignments = [];
    evaluations = [];
    s = []
    tokens = [];
    gas = {};
    params = {};
    params['l'] = l;
    params['n'] = n
    params['m'] = m
    params['k'] = k
    params['scores'] = score
    params['offChain'] = offchain
    params['revPerc'] = revPerc
    params['IW'] = 256
    params['SW'] = 256
    params['accumulator'] = false
    params['split'] = false
}

async function submission() {
    console.log("Submission Phase\n")
    crypto.randomFill(randomness, (err, buf) => {
        if (err) throw err;
    });
    gas['submission'] = {}
    for (i = 0; i < n; i++) {
        messages[i] = String.fromCharCode(97 + i);
        result = await imp.submitWork(web3.utils.asciiToHex(messages[i]), { from: accounts[i % 10] })
        submitted(result.receipt.rawLogs)
        gas['submission'][i] = result.receipt.gasUsed
    }
    let endSub = await imp.endSubmissionPhase({ from: accounts[0] })
    gas['endSubmission'] = endSub.receipt.gasUsed
}

async function partition() {
    var part;
    var ass;
    if (paper) {
        part = await imp.providePartition([[0, 1], [2, 3], [4, 5], [6, 7]], { from: accounts[0] })
        ass = await imp.provideAssignments([[3, 7], [2, 4], [0, 6], [1, 5], [3, 6], [1, 7], [0, 5], [2, 4]], { from: accounts[0] })
    } else {
        if (offchain) {
            p = generatePartition()
            a = generateAssignment(p)
            part = await imp.providePartition(p, { from: accounts[0] })
            ass = await imp.provideAssignments(a, { from: accounts[0] })
        } else {
            part = await imp.createPartition(l, { from: accounts[0] })
            ass = await imp.generateAssignments(m, { from: accounts[0] })
        }
    }
    let endAss = await imp.endAssignmentPhase({ from: accounts[0] })
    gas['partitioning'] = part.receipt.gasUsed
    gas['assignment'] = ass.receipt.gasUsed
    gas['endAssignment'] = endAss.receipt.gasUsed
    p = await imp.getPartition.call()
    logMatrix(p, "Partition Created");

}

async function assignment() {
    console.log("\n\nAssignment Phase\n");
    var i
    for (i = 0; i < n; i++) {
        let result = await imp.getAssignmentByToken.call(tokens[i])
        assignments[i] = result
        console.log("\tAssignment to ID " + i + " (Token #" + tokens[i] + "): [ " + assignments[i] + " ]");
    }
}

async function evaluation() {
    console.log("\n\nEvaluation Phase\n");
    for (i = 0; i < n; i++) {
        var reviews = assignments[i];
        evaluations[i] = [];
        s[i] = "";
        if (paper) {
            evaluations = [[0, 100], [80, 30], [83, 42], [77, 50], [65, 65], [56, 98], [29, 62], [75, 29]]
        } else {
            for (j = 0; j < reviews.length; j++) {
                evaluations[i][j] = 50 + Math.floor(Math.random() * 50);
            }
        }
        for (x = 0; x < evaluations[i].length; x++) {
            var v = evaluations[i][x];
            s[i] += "\t\t" + assignments[i][x] + " -> " + v + "\n";
        }
        console.log("\tEvaluations by ID " + i + ":\n " + s[i]);
    }
}

async function commit() {
    console.log("\nCommitment Phase")
    var i = 0;
    for (i = 0; i < n; i++) {
        commitments[i] = web3.utils.soliditySha3(
            { type: 'uint', value: randomness[i] },
            { type: 'uint[]', value: assignments[i] },
            { type: 'uint[]', value: evaluations[i] }
        )
    }
    gas['tokenApproval'] = {}
    gas['commitment'] = {}
    for (i = 0; i < n; i++) {
        let result = await token.approve(imp.address, tokens[i], { from: accounts[i % 10] })
        gas['tokenApproval'][i] = result.receipt.gasUsed
        let com = await imp.commitEvaluations(commitments[i], tokens[i], { from: accounts[i % 10] })
        gas['commitment'][i] = com.receipt.gasUsed
        comLog = web3.eth.abi.decodeLog([{
            type: 'uint256',
            name: 'tokenId'
        }, {
            type: 'bytes32',
            name: 'commitment'
        }], com.receipt.rawLogs[2].data, com.receipt.rawLogs[2].topics);
        console.log("\n\tCommitted:\n\t\tID: " + i + "\n\t\tToken: " + comLog.tokenId + "\n\t\tCommitment: " + comLog.commitment);
    }
    let endCom = await imp.endCommitmentPhase({ from: accounts[0] })
    gas['endCommitment'] = endCom.receipt.gasUsed
}

async function reveal() {
    console.log("\n\nReveal Phase")
    gas['reveal'] = {}
    for (i = 0; i < n*revPerc; i++) {
        let result = await imp.revealEvaluations(tokens[i], randomness[i], evaluations[i], { from: accounts[i % 10] })
        gas['reveal'][i] = result.receipt.gasUsed
        revLog = web3.eth.abi.decodeLog(['bytes32', 'uint256', 'uint256[]', 'uint256[]', 'uint256'],
            result.receipt.rawLogs[0].data, result.receipt.rawLogs[0].topics);
        console.log("\n\tRevealed:" +
            "\n\t\tID: " + i +
            "\n\t\tCommitment: " + revLog[0] +
            "\n\t\tRandomness: " + revLog[1] +
            "\n\t\tAssignments: " + revLog[2] +
            "\n\t\tEvaluations: " + revLog[3] +
            "\n\t\tToken: " + revLog[4]);
    }
    let endRev = await imp.endRevealPhase({ from: accounts[0] })
    gas['endReveal'] = endRev.receipt.gasUsed
}

async function selection() {
    console.log("\n\nSelection Phase (Exact Dollar Partition)\n")
    var random = Math.floor(Math.random() * C)
    var sel = await imp.impartialSelection(k, random, { from: accounts[0] });
    var scores = await imp.getScores.call()
    let allocations = await imp.getAllocations.call()
    logResults(scores, allocations, sel)
    gas['selection'] = sel.receipt.gasUsed
    let endSel = await imp.endSelectionPhase({ from: accounts[0] })
    gas['endSelection'] = endSel.receipt.gasUsed
    console.log("\nCOMPLETED!")
}

function submitted(logs) {
    tokenLog = web3.eth.abi.decodeLog([{
        type: 'address',
        name: 'to'
    }, {
        type: 'uint256',
        name: 'tokenId'
    }], logs[2].data, logs[2].topics);
    subLog = web3.eth.abi.decodeLog([{
        type: 'bytes32',
        name: 'hashedWork'
    }, {
        type: 'uint256',
        name: 'ID'
    }], logs[0].data, logs[0].topics);
    tokens.push(tokenLog.tokenId);
    console.log("\tProposal Submitted: " +
        "\n\t\tWork: " + subLog.hashedWork +
        "\n\t\tSubmitter: " + tokenLog.to +
        "\n\t\tSubmission ID: " + subLog.ID +
        "\n\t\tToken: " + tokenLog.tokenId + "\n")
}

function logResults(scoreMatrix, allocations, sel) {
    logs = sel.receipt.rawLogs;
    for (i = 0; i < scoreMatrix.length; i++) {
        scoreMatrix[i] = scoreMatrix[i].map(function (item) { return item / C });
    }
    logMatrix(scoreMatrix, "Score Matrix")
    quotasLog = web3.eth.abi.decodeLog(['uint256[]'], logs[0].data, logs[0].topics);
    console.log("\nQuotas : [ " + quotasLog[0].map(function (item) { return item / C }) + " ]")
    logAllocations(allocations)
    allLog = web3.eth.abi.decodeLog(['uint256[]'], logs[1].data, logs[1].topics);
    console.log("\nSelected Allocation : [ " + allLog[0] + " ]")
    logWinners(logs[2])
}

function logAllocations(result) {
    console.log("\nAllocations :")
    for (i = 0; i < l; i++) {
        console.log("\t[ " + result[0][i] + " ] with probability " + result[1][i] / C)
    }
}

function logWinners(result) {
    winLog = web3.eth.abi.decodeLog(['(uint128,uint128)[]'], result.data, result.topics);
    console.log("\nSelected Winners : ")
    for (i = 0; i < k; i++) {
        console.log("\tID " + winLog[0][i][0] + " with score " + winLog[0][i][1] / C)

    }
}

function logMatrix(result, message) {
    if (result.length == 0){return}
    var i;
    console.log(`\n${message}\n`);
    for (i = 0; i < result.length; i++) {
        var list = result[i];
        var s = "\t" + i + " : [ " + list[0];
        for (j = 1; j < list.length; j++) {
            s += ", " + list[j];
        }
        s += " ]";
        console.log(s);
    }
}

function gasConsumption(dict) {
    var tot = 0
    for (elem in dict) {
        if (typeof dict[elem] === 'object') {
            tot += gasConsumption(dict[elem])
        } else {
            tot += dict[elem]
        }
    }
    return tot;
}

function generatePartition() {
    var p = [];
    var agents = [...Array(n).keys()];
    for (var i = 0; i < l; i++) {
        var tmp = [];
        for (var j = i; j < n; j += l) {
            tmp.push(agents[j]);
        }
        p[i] = tmp;
    }
    return p;
}

function generateAssignment(part) {
    var assignmentsMap = [];

    for (var i = 0; i < l; i++) {
        if (!(m <= (n - part[i].length))) {
            throw "Duplicate review required";
        }
    }

    for (var i = 0; i < l; i++) {
        var len = m * part[i].length;
        var clusterAssignment = new Array(len);
        var j = 0;
        for (var k = 0; k < len; k++) {
            if (i == j) {
                j = (j + 1) % l;
            }
            clusterAssignment[k] = j;
            j = (j + 1) % l;
        }

        for (j = 0; j < part[i].length; j++) {
            var clusters = new Array(m);
            for (var k = j * m; k < (j + 1) * m; k++) {
                clusters[k % m] = clusterAssignment[k];
            }
            assignmentsMap[part[i][j]] = clusters;
        }
    }
    var assignment = [];
    var indices = new Array(l).fill(0);
    var index;
    for (var i = 0; i < n; i++) {
        var reviewerAssignment = new Array(m);
        for (var j = 0; j < m; j++) {
            index = assignmentsMap[i][j];
            reviewerAssignment[j] = part[index][indices[index]];
            indices[index] = (indices[index] + 1) % part[index].length;
        }
        assignment.push(reviewerAssignment);
    }
    return assignment;
}