# MPC Wallet Demo(Swift)

### MPC wallet address generation

<ol>
<li>Generate KeyPair for Party1(Server), Party2(Client)</li>
<li>Party2 public key is sent to Party1, Party1 KeyPair private key * Party2 public key is calculated to get the wallet address</li>
<li>Note: Party2 KeyPair private key * Party1 public key calculates the wallet address and the above</li>
</ol>

### MPC Wallet Signature

<ol>
<li>Client local randomly generate psk, ppk, ppk encrypt local private key to get cKey, generate random number k1, k2</li>
<li>Client sends MessageHash, R, ppk, cKey, k2 to Server</li>
<li>Server returns c3 after signature</li>
<li>Client decrypt c3 with psk, sign to get S, V</li>
<li>Client pushes the final signature R, S, V assembly data of the transaction to the chain</li>
</ol>

### MPC Wallet Demo, view test code：Tests/MpcWalletTests/example/MpcWalletTests.swift

* Send ETH

```swift
func testSendEth() async throws  {
    let net = EvmNet.bscTest    
    let clientPrivateKey = BigInteger("45310857711343548321619327685761206898760210185743148061608685128827704370714")!
    let wallet = await MpcWallet.importWallet(clientPrivateKey,net.rpcUrl, net.chainId, MockLocalServer())
    print("MPC Wallet address \(wallet.walletAddress.hex(eip55: false))");
    print("MPC Wallet Account Url: \("\(net.scanUrl)/address/\(wallet.walletAddress.hex(eip55: false))")");
    
    let toAddress = wallet.walletAddress
    let txId = try! await wallet.transfer(toAddress: toAddress, amount: 0.12)
    
    print("txId:\(txId)")
    
    let txUrl = "\(net.scanUrl)/tx/\(txId)";
    print("================================");
    print("MPC transfer ETH txUrl:\n\(txUrl)");
    print("================================");
    
    XCTAssertEqual(txId.isEmpty,false);
}

```

* Send ERC20 Token

```swift
func  testSendErc20Token() async throws  {
    let net = EvmNet.bscTest
    
    let clientPrivateKey = BigInteger("45310857711343548321619327685761206898760210185743148061608685128827704370714")!
    let wallet = await MpcWallet.importWallet(clientPrivateKey,net.rpcUrl, net.chainId, MockLocalServer())
    print("MPC Wallet address \(wallet.walletAddress.hex(eip55: false))");
    print("MPC Wallet Account Url: \("\(net.scanUrl)/address/\(wallet.walletAddress.hex(eip55: false))")");
    
    let toAddress = wallet.walletAddress
    let erc20 = try! EthereumAddress(hex: "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd", eip55: false)
    let decimals = 18
    
    let txId = try! await wallet.transfer(toAddress: toAddress, amount: 0.12,contractAddress: erc20,decimals: decimals)
    
    print("txId:\(txId)")
    
    let txUrl = "\(net.scanUrl)/tx/\(txId)";
    print("================================");
    print("MPC transfer Erc20 Token txUrl:\n\(txUrl)");
    print("================================");
    
    XCTAssertEqual(txId.isEmpty,false);
}
```
