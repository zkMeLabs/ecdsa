import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../crypto/formatting.dart';
import '../crypto/secp256k1.dart' as secp256k1;

export 'package:pointycastle/export.dart' show ECPrivateKey, ECPublicKey;

class Secp256k1KeyPair {
  static final ecCurve = ECCurve_secp256k1();

  Secp256k1KeyPair(this.privateKey, this.publicKey);

  final ECPrivateKey privateKey;
  final ECPublicKey publicKey;

  factory Secp256k1KeyPair.generate() {
    final params = ParametersWithRandom(ECKeyGeneratorParameters(ecCurve), getSecureRandom());
    final keyGenerator = ECKeyGenerator();
    keyGenerator.init(params);
    final keypair = keyGenerator.generateKeyPair();
    final ecPrivateKey = keypair.privateKey as ECPrivateKey;
    final ecPublicKey = keypair.publicKey as ECPublicKey;
    return Secp256k1KeyPair(ecPrivateKey, ecPublicKey);
  }

  factory Secp256k1KeyPair.importPrivateKey(BigInt privateKey) {
    final ecPrivateKey = ECPrivateKey(privateKey, ecCurve);
    final q = ecCurve.G * ecPrivateKey.d;
    final ecPublicKey = ECPublicKey(q, ecCurve);
    return Secp256k1KeyPair(ecPrivateKey, ecPublicKey);
  }
}

extension ECPublicKeyValidSignature on ECPublicKey {
  bool isValidSignature({
    required Uint8List messageHash,
    required MsgSignature msgSignature,
  }) {
    final pubkeyBytes = Q!.getEncoded(false).buffer.asUint8List(1);
    final validSignature = secp256k1.isValidSignature(
        messageHash: messageHash, msgSignature: msgSignature, publicKey: pubkeyBytes);
    return validSignature;
  }

  int? ecRecoverRecId(ECSignature ecSignature, Uint8List messageHash) {
    // Now we have to work backwards to figure out the recId needed to recover the signature.
    int? recId;
    final bytes = Q!.getEncoded(false);
    final pubKeyBigInt = bytesToUnsignedInt(bytes.sublist(1));
    final ecCurve = Secp256k1KeyPair.ecCurve;
    for (var i = 0; i < 4; i++) {
      final BigInt? k = recoverFromSignature(i, ecSignature, messageHash, ecCurve);
      if (k != null && k == pubKeyBigInt) {
        recId = i;
        break;
      }
    }
    return recId;
  }
}

SecureRandom getSecureRandom() {
  final secureRandom = FortunaRandom();
  final random = Random.secure();
  final seeds = Iterable.generate(32, (_) => random.nextInt(255)).toList();
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
  return secureRandom;
}

/// Signatures used to sign Ethereum transactions and messages.
class MsgSignature {
  MsgSignature({required this.r, required this.s, required this.v});

  final BigInt r;
  final BigInt s;
  final int v;
}

ECPoint _decompressKey(BigInt xBN, bool yBit, ECCurve c) {
  List<int> x9IntegerToBytes(BigInt s, int qLength) {
    //https://github.com/bcgit/bc-java/blob/master/core/src/main/java/org/bouncycastle/asn1/x9/X9IntegerConverter.java#L45
    final bytes = intToBytes(s);

    if (qLength < bytes.length) {
      return bytes.sublist(0, bytes.length - qLength);
    } else if (qLength > bytes.length) {
      final tmp = List<int>.filled(qLength, 0);

      final offset = qLength - bytes.length;
      for (var i = 0; i < bytes.length; i++) {
        tmp[i + offset] = bytes[i];
      }

      return tmp;
    }

    return bytes;
  }

  final compEnc = x9IntegerToBytes(xBN, 1 + ((c.fieldSize + 7) ~/ 8));
  compEnc[0] = yBit ? 0x03 : 0x02;
  return c.decodePoint(compEnc)!;
}

BigInt? recoverFromSignature(
  int recId,
  ECSignature sig,
  Uint8List msg,
  ECDomainParameters params,
) {
  final n = params.n;
  final i = BigInt.from(recId ~/ 2);
  final x = sig.r + (i * n);

  //Parameter q of curve
  final prime = BigInt.parse(
    'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
    radix: 16,
  );
  if (x.compareTo(prime) >= 0) return null;

  final R = _decompressKey(x, (recId & 1) == 1, params.curve);
  if (!(R * n)!.isInfinity) return null;

  final e = bytesToUnsignedInt(msg);

  final eInv = (BigInt.zero - e) % n;
  final rInv = sig.r.modInverse(n);
  final srInv = (rInv * sig.s) % n;
  final eInvrInv = (rInv * eInv) % n;

  final q = (params.G * eInvrInv)! + (R * srInv);

  final bytes = q!.getEncoded(false);
  return bytesToUnsignedInt(bytes.sublist(1));
}
