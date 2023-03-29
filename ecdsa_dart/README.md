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

### MPC Wallet Demo, view test code：test/wallet_test.dart

* Send ETH

```dart
test("Mpc Wallet Send ETH", () async {
    final clientPrivateKey = BigInt.parse(
        "45310857711343548321619327685761206898760210185743148061608685128827704370714");
    final wallet = await MpcWallet.importWallet(
    privateKey: clientPrivateKey,
    rpcUrl: net.rpcUrl,
    chainId: net.chainId,
    server: server,
    );
    print("MPC Wallet address ${wallet.walletAddress}");
    final toAddress = wallet.walletAddress;
    final txId = await wallet.transfer(toAddress: toAddress, amount: 0.0001);
    final txUrl = "${net.scanUrl}/tx/$txId";
    print("================================");
    print("MPC transfer ETH txUrl:\n$txUrl");
    print("================================");
    assert(txId.isNotEmpty);
});

```

* Send ERC20 Token

```dart
test("Mpc Wallet Send ERC20 Token", () async {
    final clientPrivateKey = BigInt.parse(
            "45310857711343548321619327685761206898760210185743148061608685128827704370714");
    final wallet = await MpcWallet.importWallet(
        privateKey: clientPrivateKey,
        rpcUrl: net.rpcUrl,
    chainId: net.chainId,
    server: server,
    );
    print("MPC Wallet address ${wallet.walletAddress}");
    const tokenContract = "0xc32a58faf0bd7bd85c4697445609f7f157957c7b";
    const decimals = 6;
    final toAddress = wallet.walletAddress;
    final txId = await wallet.transfer(
        toAddress: toAddress,
        amount: 0.0001,
    contractAddress: tokenContract,
    decimals: decimals,
    );
    final txUrl = "${net.scanUrl}/tx/$txId";
    print("================================");
    print("MPC transfer ERC20 token txUrl:\n$txUrl");
    print("================================");
    assert(txId.isNotEmpty);
});
```
