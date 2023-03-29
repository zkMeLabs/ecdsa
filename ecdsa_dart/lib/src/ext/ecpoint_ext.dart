import 'package:pointycastle/export.dart' show ECPoint;
import 'package:web3dart/credentials.dart';

extension EcPointExt on ECPoint {
  ECPoint multiply(BigInt k) => this * k as ECPoint;

  /// Address:  0x..........
  EthereumAddress toAddress() =>
      EthereumAddress.fromPublicKey(getEncoded(false).buffer.asUint8List(1));
}
