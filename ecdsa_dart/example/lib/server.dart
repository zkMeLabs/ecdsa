import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:paillier/paillier.dart';

// ignore: implementation_imports
import 'package:pointycastle/export.dart';
import 'package:two_party_ecdsa/two_party_ecdsa.dart';
import 'package:web3dart/web3dart.dart';

///Party1
abstract class Server {
  const Server();

  MpcAlgorithm get algorithm;

  Future<ECPublicKey> createWallet(ECPublicKey clientPubKey);

  Future<EncryptedNumber> partialSignMessage({
    required ECPublicKey clientPubKey,
    required Uint8List messageHash,
    required EncryptedNumber cKey,
    required BigInt R,
    required BigInt k2,
  });
}


class MockLocalServer extends Server {
  const MockLocalServer(this._algorithm, this.serverPrivateKey);

  ///todo: create a new PrivateKey for [createWallet]
  final BigInt serverPrivateKey;
  final MpcAlgorithm _algorithm;

  @override
  MpcAlgorithm get algorithm => _algorithm;

  ///Key:Client PubKey Address
  ///Value: Server Party
  static final _walletMap = <String, Party1>{};

  @override
  Future<ECPublicKey> createWallet(ECPublicKey clientPubKey) async {
    final ecKeyPair = Secp256k1KeyPair.importPrivateKey(serverPrivateKey);
    final party = Party1(ecKeyPair, clientPubKey, algorithm);
    _walletMap.putIfAbsent(clientPubKey.Q!.toAddress().hex, () => party);
    return party.masterPubkey;
  }

  @override
  Future<EncryptedNumber> partialSignMessage({
    required ECPublicKey clientPubKey,
    required Uint8List messageHash,
    required EncryptedNumber cKey,
    required BigInt R,
    required BigInt k2,
  }) async {
    final party1 = _walletMap[clientPubKey.Q!.toAddress().toString()]!;
    return party1.partialSignMessage(messageHash: messageHash, cKey: cKey, R: R, k2: k2);
  }
}

class RemoteServer extends Server {
  const RemoteServer(this.baseUrl, this._algorithm);

  final MpcAlgorithm _algorithm;
  final String baseUrl;

  @override
  MpcAlgorithm get algorithm => _algorithm;

  @override
  Future<ECPublicKey> createWallet(ECPublicKey clientPubKey) async {
    final clientPubKeyHex = bytesToHex(clientPubKey.Q!.getEncoded(false), include0x: true);
    final data =
        (await postRequestData("/thresholdSign/getPublicKey", {'publicKey': clientPubKeyHex}))
            .toString();
    final walletPubKeyPoint = Secp256k1KeyPair.ecCurve.curve.decodePoint(hexToBytes(data));
    return ECPublicKey(walletPubKeyPoint, Secp256k1KeyPair.ecCurve);
  }

  @override
  Future<EncryptedNumber> partialSignMessage({
    required ECPublicKey clientPubKey,
    required Uint8List messageHash,
    required EncryptedNumber cKey,
    required BigInt R,
    required BigInt k2,
  }) async {
    final clientPubKeyHex = bytesToHex(clientPubKey.Q!.getEncoded(false), include0x: true);

    var reqBody = {
      "message": Int8List.fromList(messageHash),
      "cipherText": cKey.calculateCiphertext().toString(),
      "exponent": cKey.exponent,
      "k2": k2.toString(),
      "modulus": cKey.context.publicKey.modulus.toString(),
      "r": R.toString(),
      "publicKey": clientPubKeyHex
    };
    final data = (await postRequestData("/thresholdSign/sign", reqBody)) as Map;

    final modulus = BigInt.parse(data['modulus'].toString());
    final cipherText = BigInt.parse(data['cipherText'].toString());
    final exponent = data['exponent'] as int;
    final c3 = EncryptedNumber(
      PaillierPublicKey(modulus).createUnsignedContext(),
      cipherText,
      exponent,
      true,
    );
    return c3;
  }

  Future<dynamic> postRequestData(String path, Map body) async {
    var uri = Uri.parse('$baseUrl$path');
    print("=" * 50);
    print("postRequestData: $uri");
    print("Request: body: $body");
    final resp = await http.post(
      uri,
      body: jsonEncode(body),
    );
    var statusCode = resp.statusCode;
    print("Response: statusCode: $statusCode");
    final respBodyString = resp.body;
    final respBody = jsonDecode(respBodyString);
    print("Response: body: $respBody");

    return respBody['data'];
  }
}
