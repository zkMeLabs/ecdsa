import 'dart:convert';
import 'dart:typed_data';

import 'package:example/mpc_wallet.dart';
import 'package:example/server.dart';
import 'package:http/http.dart';
import 'package:paillier/paillier.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:test/test.dart';
import 'package:two_party_ecdsa/two_party_ecdsa.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  const net = EvmNet.polygonTest;

  final mockServerPrivateKey = BigInt.parse(
      "45719149885192233806045810317315129331085385709175189237177881263558905923184");
  final server = MockLocalServer(MpcAlgorithm.additive, mockServerPrivateKey);
  test("Mpc SignMessage", () async {
    final clientPrivateKey = BigInt.parse(
        "45310857711343548321619327685761206898760210185743148061608685128827704370714");
    final wallet = await MpcWallet.importWallet(
      privateKey: clientPrivateKey,
      rpcUrl: net.rpcUrl,
      chainId: net.chainId,
      server: server,
    );
    print("MPC Wallet address ${wallet.walletAddress}");
    print(
        "MPC Wallet Account Url: ${"${net.scanUrl}/address/${wallet.walletAddress}"}");
    var message = Uint8List.fromList(utf8.encode("hello"));
    await wallet.signMessage(message);
  });
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
    print(
        "MPC Wallet Account Url: ${"${net.scanUrl}/address/${wallet.walletAddress}"}");

    final toAddress = wallet.walletAddress;
    final txId = await wallet.transfer(toAddress: toAddress, amount: 0.0001);
    final txUrl = "${net.scanUrl}/tx/$txId";
    print("================================");
    print("MPC transfer ETH txUrl:\n$txUrl");
    print("================================");
    assert(txId.isNotEmpty);
  });

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
    print(
        "MPC Wallet Account Url: ${"${net.scanUrl}/address/${wallet.walletAddress}"}");

    //goerliTest Token
    const tokenContract = "0xE097d6B3100777DC31B34dC2c58fB524C2e76921";
    const decimals = 6;
    // const tokenContract = "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd";
    // const decimals = 18;
    final toAddress = wallet.walletAddress;
    final txId = await wallet.transfer(
      toAddress: toAddress,
      amount: 0.001,
      contractAddress: tokenContract,
      decimals: decimals,
    );
    final txUrl = "${net.scanUrl}/tx/$txId";
    print("================================");
    print("MPC transfer ERC20 token txUrl:\n$txUrl");
    print("================================");
    assert(txId.isNotEmpty);
  });

  test("ETHWallet Send ETH", () async {
    final clientPrivateKey = BigInt.parse(
        "45310857711343548321619327685761206898760210185743148061608685128827704370714");
    final serverPrivateKey = BigInt.parse(
        "45719149885192233806045810317315129331085385709175189237177881263558905923184");

    var privateKeyInt =
        (clientPrivateKey * serverPrivateKey).mod(ECCurve_secp256k1().n);
    print("ethPrivateKey  $privateKeyInt");
    var ethPrivateKey = EthPrivateKey.fromInt(privateKeyInt);
    print("ethPrivateKey address ${ethPrivateKey.address}");
    print(
        "MPC Wallet Account Url: ${"${net.scanUrl}/address/${ethPrivateKey.address}"}");

    var web3client = Web3Client(net.rpcUrl, Client());
    final txId = await web3client.sendTransaction(
      ethPrivateKey,
      Transaction(
        from: ethPrivateKey.address,
        to: ethPrivateKey.address,
        value: EtherAmount.inWei(BigInt.from(100)),
      ),
      chainId: net.chainId,
    );

    final txUrl = "${net.scanUrl}/tx/$txId";
    print("================================");
    print("MPC transfer ETH txUrl:\n$txUrl");
    print("================================");
    assert(txId.isNotEmpty);
  });
}

enum EvmNet {
  goerliTest,
  bscTest,
  polygonTest,
}

extension on EvmNet {
  String get rpcUrl {
    switch (this) {
      case EvmNet.goerliTest:
        return "https://goerli.infura.io/v3/bef864a7a71a4f6d91f9dc08614306a5";
      case EvmNet.bscTest:
        return "https://data-seed-prebsc-1-s1.binance.org:8545";
      case EvmNet.polygonTest:
        return "https://rpc-mumbai.matic.today";
    }
  }

  String get scanUrl {
    switch (this) {
      case EvmNet.goerliTest:
        return "https://goerli.etherscan.io";
      case EvmNet.bscTest:
        return "https://testnet.bscscan.com";
      case EvmNet.polygonTest:
        return "https://mumbai.polygonscan.com";
    }
  }

  int get chainId {
    switch (this) {
      case EvmNet.goerliTest:
        return 5;
      case EvmNet.bscTest:
        return 97;
      case EvmNet.polygonTest:
        return 80001;
    }
  }
}
