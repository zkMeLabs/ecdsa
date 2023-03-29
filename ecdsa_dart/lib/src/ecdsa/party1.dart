import 'dart:typed_data';

import 'package:paillier/paillier.dart';

// ignore: implementation_imports
import 'package:pointycastle/src/utils.dart';
import 'package:two_party_ecdsa/src/ecdsa/algorithm.dart';
import 'package:two_party_ecdsa/src/ecdsa/ec_keypair.dart';

abstract class Party1 {
  const Party1._(this.keyPair, this.masterPubkey);

  factory Party1(
    Secp256k1KeyPair keyPair,
    ECPublicKey otherPubKey,
    MpcAlgorithm algorithm,
  ) {
    Party1 _party1;
    switch (algorithm) {
      case MpcAlgorithm.additive:
        _party1 = _Party1_Additive(keyPair, otherPubKey);
        break;
      case MpcAlgorithm.multiply:
        _party1 = _Party1_Multiply(keyPair, otherPubKey);
        break;
    }
    return _party1;
  }

  final Secp256k1KeyPair keyPair;

  final ECPublicKey masterPubkey;

  MpcAlgorithm get algorithm;

  EncryptedNumber partialSignMessage({
    required Uint8List messageHash,
    required EncryptedNumber cKey,
    required BigInt R,
    required BigInt k2,
  });
}

// ignore: camel_case_types
class _Party1_Multiply extends Party1 {
  const _Party1_Multiply._(Secp256k1KeyPair keyPair, ECPublicKey masterPubkey)
      : super._(keyPair, masterPubkey);

  factory _Party1_Multiply(Secp256k1KeyPair keyPair, ECPublicKey otherPubKey) {
    final secretKey = keyPair.privateKey.d!;
    final masterPubKey = ECPublicKey(otherPubKey.Q! * secretKey, keyPair.publicKey.parameters);
    return _Party1_Multiply._(keyPair, masterPubKey);
  }

  @override
  MpcAlgorithm get algorithm => MpcAlgorithm.multiply;

  @override
  EncryptedNumber partialSignMessage({
    required Uint8List messageHash,
    required EncryptedNumber cKey,
    required BigInt R,
    required BigInt k2,
  }) {
    final ppk = cKey.context.publicKey;
    final x1 = keyPair.privateKey.d!;
    final order = keyPair.publicKey.parameters!.n;
    final z = decodeBigIntWithSign(1, messageHash);
    final pho = BigIntUtil.createRandomInRange(BigInt.zero, order.pow(2));
    final k2Inv = k2.modInverse(order);
    final xx = k2Inv.multiply(z).mod(order);
    final tmp = pho.multiply(order).add(xx);
    final c_1 = ppk.createUnsignedContext().encryptBigInt(tmp);
    final v = k2Inv.multiply(R).multiply(x1).mod(order);
    final c_2 = cKey.multiplyBigInt(v);
    final c_3 = c_2.addEncryptedNumber(c_1);
    return c_3;
  }
}

// ignore: camel_case_types
class _Party1_Additive extends Party1 {
  const _Party1_Additive._(Secp256k1KeyPair keyPair, ECPublicKey masterPubkey)
      : super._(keyPair, masterPubkey);

  factory _Party1_Additive(Secp256k1KeyPair keyPair, ECPublicKey otherPubKey) {
    final masterPubKey = ECPublicKey(
      keyPair.publicKey.Q! + otherPubKey.Q!,
      keyPair.publicKey.parameters,
    );
    return _Party1_Additive._(keyPair, masterPubKey);
  }

  @override
  MpcAlgorithm get algorithm => MpcAlgorithm.additive;

  @override
  EncryptedNumber partialSignMessage({
    required Uint8List messageHash,
    required EncryptedNumber cKey,
    required BigInt R,
    required BigInt k2,
  }) {
    final ppk = cKey.context.publicKey;
    final x1 = keyPair.privateKey.d!;
    final order = keyPair.publicKey.parameters!.n;
    final z = decodeBigIntWithSign(1, messageHash);
    final pho = BigIntUtil.createRandomInRange(BigInt.zero, order.pow(2));
    final k2Inv = k2.modInverse(order);
    final xx = k2Inv.multiply(z).mod(order);
    final tmp = pho.multiply(order).add(xx);
    final context = ppk.createUnsignedContext();
    final c1 = context.encryptBigInt(tmp);
    final c2 = context.encryptBigInt(x1);
    final c3 = cKey.addEncryptedNumber(c2);
    final v = k2Inv.multiply(R).mod(order);
    final c4 = c3.multiplyBigInt(v);
    final c5 = c1.addEncryptedNumber(c4);
    return c5;
  }
}
