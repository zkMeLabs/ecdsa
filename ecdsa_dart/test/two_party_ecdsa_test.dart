import 'dart:convert';
import 'dart:typed_data';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';
import 'package:two_party_ecdsa/two_party_ecdsa.dart';

void main() {
  test("Additive test_two_party_sign", () {
    var keyPair1 = Secp256k1KeyPair.generate();
    var keyPair2 = Secp256k1KeyPair.generate();
    // print('party1 privateKey:${keyPair1.privateKey.d}');
    // print('party2 privateKey:${keyPair2.privateKey.d}');
    var party1 = Party1(keyPair1, keyPair2.publicKey, MpcAlgorithm.additive);
    final masterPubKey = party1.masterPubkey;
    print('masterPubKey :${masterPubKey.Q}');

    final party2 = Party2(keyPair2, masterPubKey, party1.algorithm);

    final message = Uint8List.fromList(utf8.encode("hello"));
    final partialSigMessage = party2.genPartialSigMessage(message);

    final c5 = party1.partialSignMessage(
      messageHash: partialSigMessage.messageHash,
      cKey: partialSigMessage.paillier.cKey,
      R: partialSigMessage.R,
      k2: partialSigMessage.k2,
    );
    final msgSignature = party2.computeSignature(
      PartialSig(
        encrypted: c5,
        messageHash: partialSigMessage.messageHash,
        k1: partialSigMessage.k1,
        R: partialSigMessage.R,
      ),
      partialSigMessage.paillier.psk,
    );

    final validSignature = masterPubKey.isValidSignature(
      messageHash: partialSigMessage.messageHash,
      msgSignature: msgSignature,
    );

    print("validSignature:$validSignature");
    expect(validSignature, true);
  });
  test("multiply test_two_party_sign", () {
    var keyPair1 = Secp256k1KeyPair.generate();
    var keyPair2 = Secp256k1KeyPair.generate();
    // print('party1 privateKey:${keyPair1.privateKey.d}');
    // print('party2 privateKey:${keyPair2.privateKey.d}');
    var party1 = Party1(keyPair1, keyPair2.publicKey, MpcAlgorithm.multiply);
    final masterPubKey = party1.masterPubkey;
    print('masterPubKey :${masterPubKey.Q}');

    final party2 = Party2(keyPair2, masterPubKey, party1.algorithm);

    final message = Uint8List.fromList(utf8.encode("hello"));
    final partialSigMessage = party2.genPartialSigMessage(message);

    final c3 = party1.partialSignMessage(
      messageHash: partialSigMessage.messageHash,
      cKey: partialSigMessage.paillier.cKey,
      R: partialSigMessage.R,
      k2: partialSigMessage.k2,
    );
    final msgSignature = party2.computeSignature(
      PartialSig(
        encrypted: c3,
        messageHash: partialSigMessage.messageHash,
        k1: partialSigMessage.k1,
        R: partialSigMessage.R,
      ),
      partialSigMessage.paillier.psk,
    );

    final validSignature = masterPubKey.isValidSignature(
      messageHash: partialSigMessage.messageHash,
      msgSignature: msgSignature,
    );

    print("validSignature:$validSignature");
    expect(validSignature, true);
  });
}
