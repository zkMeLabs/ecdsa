# MPC Wallet Demo

### MPC Wallet address generation

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

### MPC Wallet Demo, view test code：example/src/test/kotlin/MpcWalletDemo

* Send ETH

```kotlin
   @Test
fun transferETH() {
    //Client
    val party2PrivateKey =
        BigInteger("45310857711343548321619327685761206898760210185743148061608685128827704370714")
    val rpcUrl = "https://goerli.infura.io/v3/bef864a7a71a4f6d91f9dc08614306a5"
    val chainId = 5L

    val wallet = MpcWallet.importWallet(party2PrivateKey, rpcUrl, chainId)
    println("MPC Wallet address ${wallet.walletAddress}")
    val toAddress = wallet.walletAddress
    val txId = wallet.transfer(toAddress, BigDecimal("0.0001"))
    val txUrl = "https://goerli.etherscan.io/tx/$txId"
    println("================================")
    println("MPC transfer ETH txUrl:\n$txUrl")
    println("================================")
    assert(txId.isNotBlank())
}

```

* Send ERC20 Token

```kotlin
    @Test
fun transferErc20Token() {
    //Client
    val party2PrivateKey =
        BigInteger("45310857711343548321619327685761206898760210185743148061608685128827704370714")
    val rpcUrl = "https://goerli.infura.io/v3/bef864a7a71a4f6d91f9dc08614306a5"
    val chainId = 5L

    val wallet = MpcWallet.importWallet(party2PrivateKey, rpcUrl, chainId)
    println("MPC Wallet address ${wallet.walletAddress}")
    val tokenContract = "0xc32a58faf0bd7bd85c4697445609f7f157957c7b"
    val decimals = 6
    val toAddress = wallet.walletAddress
    val txId = wallet.transfer(toAddress, BigDecimal("0.012"), tokenContract, decimals)
    val txUrl = "https://goerli.etherscan.io/tx/$txId"
    println("================================")
    println("MPC transfer ERC20 token txUrl:\n$txUrl")
    println("================================")
    assert(txId.isNotBlank())
}
```
