import 'dart:typed_data';

import 'package:paillier/paillier.dart';
import 'package:pointycastle/export.dart';

import '../../two_party_ecdsa.dart';

abstract class Party2 {
  const Party2._(this.keyPair, this.masterPubkey);

  factory Party2(Secp256k1KeyPair keyPair, ECPublicKey masterPubkey, MpcAlgorithm algorithm) {
    Party2 party2;
    switch (algorithm) {
      case MpcAlgorithm.additive:
        party2 = _Party2Additive(keyPair, masterPubkey);
        break;
      case MpcAlgorithm.multiply:
        party2 = _Party2Multiply(keyPair, masterPubkey);
        break;
    }
    return party2;
  }

  final Secp256k1KeyPair keyPair;

  final ECPublicKey masterPubkey;

  MpcAlgorithm get algorithm;

  PartialSigMessage genPartialSigMessage(Uint8List message, [bool needToHash = true]) {
    final messageHash = needToHash ? keccak256(message) : message;
    //Client psk ppk cKey
    final paillier = _generatePaillierShareKey();
    final order = keyPair.publicKey.parameters!.n;

    var R = BigInt.zero;
    var k1 = BigInt.zero;
    var k2 = BigInt.zero;
    while (true) {
      final key1 = Secp256k1KeyPair.generate();
      final key2 = Secp256k1KeyPair.generate();
      final pub1 = key1.publicKey;
      final pub2 = key2.publicKey;
      final s1 = key1.privateKey;
      final s2 = key2.privateKey;
      k1 = s1.d!;
      k2 = s2.d!;
      final q1 = pub1.Q!;
      final q2 = pub2.Q!;
      final qP1 = q2.multiply(k1);
      final r1 = qP1.x!.toBigInteger()!.mod(order);
      final qP2 = q1.multiply(k2);
      final r2 = qP2.x!.toBigInteger()!.mod(order);
      if (r1.compareTo(r2) == 0) {
        R = r1;
      }
      if (R.compareTo(BigInt.zero) != 0) {
        break;
      }
    }

    return PartialSigMessage(
      messageHash: messageHash,
      paillier: paillier,
      R: R,
      k1: k1,
      k2: k2,
    );
  }

  /// p2 GeneratesA Homomorphic KeyPair(ppk,psk)
  PaillierKeyPair _generatePaillierShareKey() {
    final paillierPrivateKey = PaillierPrivateKey.create(2048);
    final ppk = paillierPrivateKey.publicKey;
    final x2 = keyPair.privateKey.d!;
    final cKey = ppk.createUnsignedContext().encryptBigInt(x2).getSafeEncryptedNumber();
    return PaillierKeyPair(paillierPrivateKey, cKey);
  }

  /// compute Sign.
  ///
  /// @return SignatureData(R、S、V)
  MsgSignature computeSignature(
    PartialSig partialSig,
    PaillierPrivateKey psk,
  );
}

class _Party2Multiply extends Party2 {
  const _Party2Multiply(Secp256k1KeyPair keyPair, ECPublicKey masterPubkey)
      : super._(keyPair, masterPubkey);

  @override
  MpcAlgorithm get algorithm => MpcAlgorithm.multiply;

  @override
  MsgSignature computeSignature(
    PartialSig partialSig,
    PaillierPrivateKey psk,
  ) {
    final c3 = partialSig.encrypted;
    final order = keyPair.publicKey.parameters!.n;
    final k1Inv = partialSig.k1.modInverse(order);
    final _s = psk.decrypt(c3).decodeBigInt();
    final __s = k1Inv.multiply(_s).mod(order);
    final ss = order.subtract(__s);

    final BigInt S;
    if (__s < ss) {
      S = __s;
    } else {
      S = ss;
    }

    final sig = ECSignature(partialSig.R, S).normalize(Secp256k1KeyPair.ecCurve);
    return sig.toMsgSignature(masterPubkey, partialSig.messageHash);
  }
}

class _Party2Additive extends Party2 {
  const _Party2Additive(Secp256k1KeyPair keyPair, ECPublicKey masterPubkey)
      : super._(keyPair, masterPubkey);

  @override
  MpcAlgorithm get algorithm => MpcAlgorithm.additive;

  @override
  MsgSignature computeSignature(
    PartialSig partialSig,
    PaillierPrivateKey psk,
  ) {
    final c5 = partialSig.encrypted;
    final order = keyPair.publicKey.parameters!.n;
    final k1Inv = partialSig.k1.modInverse(order);
    final _s = psk.decrypt(c5).decodeBigInt();
    final __s = k1Inv.multiply(_s).mod(order);
    final ss = order.subtract(__s);

    final BigInt S;
    if (__s < ss) {
      S = __s;
    } else {
      S = ss;
    }
    final sig = ECSignature(partialSig.R, S).normalize(Secp256k1KeyPair.ecCurve);
    return sig.toMsgSignature(masterPubkey, partialSig.messageHash);
  }
}

extension on ECSignature {
  MsgSignature toMsgSignature(ECPublicKey pubKey, Uint8List messageHash) {
    final recId = pubKey.ecRecoverRecId(this, messageHash);
    if (null == recId) {
      throw Exception("Could not construct a recoverable key. Are your credentials valid?");
    }
    final v = recId + 27;
    return MsgSignature(r: r, s: s, v: v);
  }
}

class PaillierKeyPair {
  const PaillierKeyPair(this.psk, this.cKey);

  final PaillierPrivateKey psk;
  final EncryptedNumber cKey;
}

class PartialSigMessage {
  PartialSigMessage({
    required this.paillier,
    required this.messageHash,
    required this.k1,
    required this.k2,
    required this.R,
  });

  final PaillierKeyPair paillier;
  final Uint8List messageHash;
  final BigInt k1;
  final BigInt k2;
  final BigInt R;
}

class PartialSig {
  PartialSig({
    required this.encrypted,
    required this.messageHash,
    required this.k1,
    required this.R,
  });

  final EncryptedNumber encrypted;
  final Uint8List messageHash;
  final BigInt k1;
  final BigInt R;
}
