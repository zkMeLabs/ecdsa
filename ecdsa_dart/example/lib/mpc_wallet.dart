import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:two_party_ecdsa/two_party_ecdsa.dart';
import 'package:web3dart/web3dart.dart';

import 'server.dart';
import 'transaction.dart';

/// Party2
class MpcWallet {
  MpcWallet._({
    required this.party2,
    required this.rpcUrl,
    required this.chainId,
    required this.server,
  });

  static Future<MpcWallet> generateWallet({
    required String rpcUrl,
    required int chainId,
    required Server server,
  }) async {
    final keyPair2 = Secp256k1KeyPair.generate();
    final walletPubKey = await server.createWallet(keyPair2.publicKey);
    final party2 = Party2(keyPair2, walletPubKey, server.algorithm);
    return MpcWallet._(party2: party2, rpcUrl: rpcUrl, chainId: chainId, server: server);
  }

  static Future<MpcWallet> importWallet({
    required BigInt privateKey,
    required String rpcUrl,
    required int chainId,
    required Server server,
  }) async {
    final keyPair2 = Secp256k1KeyPair.importPrivateKey(privateKey);
    final walletPubKey = await server.createWallet(keyPair2.publicKey);
    final party2 = Party2(keyPair2, walletPubKey, server.algorithm);
    return MpcWallet._(party2: party2, rpcUrl: rpcUrl, chainId: chainId, server: server);
  }

  final Party2 party2;
  final String rpcUrl;
  final int chainId;
  final Server server;

  /// MPC Wallet Address
  EthereumAddress get walletAddress => _walletPubKey.Q!.toAddress();

  ECPublicKey get _walletPubKey => party2.masterPubkey;

  Future<String> transfer({
    required EthereumAddress toAddress,
    required num amount,
    String? contractAddress,
    int? decimals,
  }) async {
    final web3client = Web3Client(rpcUrl, http.Client());
    final transaction = await createTransaction(
      web3Client: web3client,
      amount: amount,
      fromAddress: walletAddress,
      toAddress: toAddress,
      contractAddress: contractAddress,
      decimals: decimals,
    );
    if (null == transaction) return '';
    final signedTransaction =
        await transaction.sign(chainId: chainId, onSign: (encoded) async => signMessage(encoded));
    final txId = await web3client.sendRawTransaction(signedTransaction);
    return txId;
  }

  Future<MsgSignature> signMessage(Uint8List message, [bool needToHash = true]) async {
    final partialSigMessage = party2.genPartialSigMessage(message, needToHash);
    final messageHash = partialSigMessage.messageHash;
    final R = partialSigMessage.R;
    //Request Server Partial Sign
    final c3 = await server.partialSignMessage(
      clientPubKey: party2.keyPair.publicKey,
      messageHash: messageHash,
      cKey: partialSigMessage.paillier.cKey,
      R: R,
      k2: partialSigMessage.k2,
    );

    //Client compute Sign
    final msgSignature = party2.computeSignature(
      PartialSig(
        encrypted: c3,
        messageHash: messageHash,
        R: R,
        k1: partialSigMessage.k1,
      ),
      partialSigMessage.paillier.psk,
    );
    var validSignature = _walletPubKey.isValidSignature(
      messageHash: messageHash,
      msgSignature: msgSignature,
    );
    print("validSignature:$validSignature");
    return msgSignature;
  }
}
