import 'dart:async';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:two_party_ecdsa/two_party_ecdsa.dart';

// ignore: implementation_imports
import 'package:web3dart/src/utils/length_tracking_byte_sink.dart';

// ignore: implementation_imports
import 'package:web3dart/src/utils/rlp.dart' as rlp;
import 'package:web3dart/web3dart.dart';

import 'abi.dart';

Future<Transaction?> createTransaction({
  required Web3Client web3Client,
  required num amount,
  required EthereumAddress fromAddress,
  required EthereumAddress toAddress,
  String? contractAddress,
  int? decimals,
}) async {
  final balance = await web3Client.getBalance(fromAddress);
  var gasPrice = await web3Client.getGasPrice();
  // gasPrice = EtherAmount.inWei(BigInt.from(1157319528));
  var nonce = await web3Client.getTransactionCount(fromAddress, atBlock: const BlockNum.pending());
  print("Current balance ${balance.getInWei} , ${balance.getValueInUnit(EtherUnit.ether)} ETH");
  print("gasPrice $gasPrice");
  // nonce = 69;

  print("nonce $nonce");
  if (contractAddress?.trim().isNotEmpty ?? false) {
    // //transfer ERC20 token
    final sendAmount =
        EtherAmount.inWei((Decimal.parse("$amount") * Decimal.ten.pow(decimals!)).toBigInt());
    print("send amount $amount ERC20, value:$sendAmount ");
    var tokenTransfer = ABI.tokenTransfer(
      from: fromAddress,
      to: toAddress,
      tokensAmount: amount,
      decimals: decimals,
      tokenAddress: contractAddress!.trim(),
    );

    final gasLimit = await web3Client.estimateGas(
      sender: tokenTransfer.from,
      to: tokenTransfer.to,
      value: tokenTransfer.value ?? EtherAmount.zero(),
      data: tokenTransfer.data,
      gasPrice: gasPrice,
    );

    return tokenTransfer.copyWith(
      nonce: nonce,
      gasPrice: gasPrice,
      maxGas: gasLimit.toInt(),
      value: EtherAmount.zero(),
    );
  } else {
    //transfer ETH
    final sendAmount =
        EtherAmount.inWei((Decimal.parse("$amount") * Decimal.ten.pow(18)).toBigInt());
    print("send amount $amount Eth, value:$sendAmount (WEI)");
    return Transaction(
      nonce: nonce,
      gasPrice: gasPrice,
      maxGas: 21000,
      to: toAddress,
      value: sendAmount,
      data: Uint8List(0),
    );
  }
}

typedef OnSign = Future<MsgSignature> Function(Uint8List encodedTx);

extension TransactionExt on Transaction {
  Future<Uint8List> sign({
    required OnSign onSign,
    int? chainId = 1,
  }) async {
    final encodedTx = _encode(chainId: chainId);
    var signature = await onSign.call(encodedTx);

    // https://github.com/ethereumjs/ethereumjs-util/blob/8ffe697fafb33cefc7b7ec01c11e3a7da787fe0e/src/signature.ts#L26
    // be aware that signature.v already is recovery + 27
    int chainIdV;
    if (isEIP1559) {
      chainIdV = signature.v - 27;
    } else {
      chainIdV = chainId != null ? (signature.v - 27 + (chainId * 2 + 35)) : signature.v;
    }

    signature = MsgSignature(r: signature.r, s: signature.s, v: chainIdV);
    Uint8List signed;

    if (isEIP1559 && chainId != null) {
      signed = uint8ListFromList(
        rlp.encode(_encodeEIP1559ToRlp(this, signature, BigInt.from(chainId))),
      );
    } else {
      signed = uint8ListFromList(rlp.encode(_encodeToRlp(this, signature)));
    }

    if (isEIP1559) {
      signed = prependTransactionType(0x02, signed);
    }
    return signed;
  }

  Uint8List _encode({int? chainId}) {
    if (isEIP1559 && chainId != null) {
      final encodedTx = LengthTrackingByteSink();
      encodedTx.addByte(0x02);
      encodedTx.add(rlp.encode(_encodeEIP1559ToRlp(this, null, BigInt.from(chainId))));
      encodedTx.close();
      final encoded = encodedTx.asBytes();
      return encoded;
    } else {
      final innerSignature =
          chainId == null ? null : MsgSignature(r: BigInt.zero, s: BigInt.zero, v: chainId);

      final encoded = uint8ListFromList(rlp.encode(_encodeToRlp(this, innerSignature)));
      return encoded;
    }
  }

  List<dynamic> _encodeEIP1559ToRlp(
    Transaction transaction,
    MsgSignature? signature,
    BigInt chainId,
  ) {
    final list = [
      chainId,
      transaction.nonce,
      transaction.maxPriorityFeePerGas!.getInWei,
      transaction.maxFeePerGas!.getInWei,
      transaction.maxGas,
    ];

    if (transaction.to != null) {
      list.add(transaction.to!.addressBytes);
    } else {
      list.add('');
    }

    list
      ..add(transaction.value?.getInWei)
      ..add(transaction.data);

    list.add([]); // access list

    if (signature != null) {
      list
        ..add(signature.v)
        ..add(signature.r)
        ..add(signature.s);
    }

    return list;
  }

  List<dynamic> _encodeToRlp(Transaction transaction, MsgSignature? signature) {
    final list = [
      transaction.nonce,
      transaction.gasPrice?.getInWei,
      transaction.maxGas,
    ];

    if (transaction.to != null) {
      list.add(transaction.to!.addressBytes);
    } else {
      list.add('');
    }

    list
      ..add(transaction.value?.getInWei)
      ..add(transaction.data);

    if (signature != null) {
      list
        ..add(signature.v)
        ..add(signature.r)
        ..add(signature.s);
    }

    return list;
  }
}
