import Foundation
import Web3ContractABI
import Web3
import BigInt
import Collections

public func createTransaction(web3:Web3, amount:Double,fromAddress:EthereumAddress,toAddress:EthereumAddress,contractAddress:EthereumAddress?=nil, decimals:Int?=nil) async throws -> EthereumTransaction{
    let balance =  try! await web3.eth.getBalance(address: fromAddress, block: .latest).async()
    let gasPrice =  try! await web3.eth.gasPrice().async()
    let nonce =  try! await web3.eth.getTransactionCount(address: fromAddress, block: .pending).async()
    print("Current balance \(balance.quantity)")
    print("gasPrice \(gasPrice.quantity)");
    print("nonce \(nonce)");
    
    let  transaction: EthereumTransaction
    if(contractAddress != nil ){
        
        let sendAmount = BigUInt("\((pow(Decimal(10), decimals!) * Decimal(amount)))")!
        let contract = web3.eth.Contract(type: GenericERC20Contract.self,address:contractAddress)
        
        let transfer = contract.transfer(to: toAddress, value: sendAmount)
        let gasLimit = try! await transfer.estimateGas(from:fromAddress).async()
        print("gasLimit \(gasLimit)");
        
        transaction = transfer.createTransaction(
            nonce: nonce,
            from: fromAddress,
            value: 0,
            gas: gasLimit,
            gasPrice:gasPrice
        )!
    }else{
        //transfer ETH
        let weiAmount =  BigUInt("\((pow(Decimal(10), 18) * Decimal(amount)))")!
        print("send amount value:\(weiAmount) (WEI)");
        
        let sendAmount = EthereumQuantity(quantity:weiAmount)
        
        transaction =  EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: EthereumQuantity(quantity: BigUInt(21000)),
            to: toAddress,
            value:sendAmount ,
            data: EthereumData([UInt8]())
        )
        
    }
    
    return transaction
}


extension EthereumTransaction{
    func encode(_ chainId:Int) throws -> [UInt8]{
        switch transactionType {
        case .legacy:
            return try legacyEncode(EthereumQuantity.init(quantity: BigUInt("\(chainId)")!))
        case .eip1559:
            return try eip1559Encode(EthereumQuantity.init(quantity: BigUInt("\(chainId)")!))
        }
    }
    
    private func legacyEncode(_ chainId:EthereumQuantity)  throws -> [UInt8]{
        // These values are required for signing
        guard let nonce = nonce, let gasPrice = gasPrice, let gasLimit = gasLimit, let value = value else {
            throw EthereumSignedTransaction.Error.transactionInvalid
        }
        let rlp = RLPItem(
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: gasLimit,
            to: to,
            value: value,
            data: data,
            v: chainId,
            r: 0,
            s: 0
        )
        let rawRlp:Bytes = try RLPEncoder().encode(rlp)
        return rawRlp
        
    }
    private func eip1559Encode(_ chainId:EthereumQuantity) throws -> [UInt8]{
        
        // These values are required for signing
        guard let nonce = nonce, let maxFeePerGas = maxFeePerGas, let maxPriorityFeePerGas = maxPriorityFeePerGas,
              let gasLimit = gasLimit, let value = value else {
            throw EthereumSignedTransaction.Error.transactionInvalid
        }
        
        // If gasPrice is set, make sure it matches the EIP1559 fees. Otherwise the usage results in unexpected behaviour.
        if let gasPrice = gasPrice {
            if gasPrice.quantity != maxFeePerGas.quantity {
                throw EthereumSignedTransaction.Error.gasPriceMismatch(msg: "EIP1559 - gasPrice != maxFeePerGas")
            }
        }
        
        if chainId.quantity == BigUInt(0) {
            throw EthereumSignedTransaction.Error.chainIdNotSet(msg: "EIP1559 transactions need a chainId")
        }
        
        let rlp = RLPItem(
            nonce: nonce,
            gasPrice: gasPrice ?? EthereumQuantity(integerLiteral: 0),
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: gasLimit,
            to: to,
            value: value,
            data: data,
            chainId: chainId,
            accessList: accessList,
            transactionType: transactionType
        )
        let rawRlp = try RLPEncoder().encode(rlp)
        var messageToSign = Bytes()
        messageToSign.append(0x02)
        messageToSign.append(contentsOf: rawRlp)
        return messageToSign
    }
}

extension RLPItem {
    /**
     * Create an RLPItem representing a transaction. The RLPItem must be an array of 9 items in the proper order.
     *
     * - parameter nonce: The nonce of this transaction.
     * - parameter gasPrice: The gas price for this transaction in wei.
     * - parameter maxFeePerGas: Max fee per gas as described in EIP1559. Only required for EIP1559 transactions.
     * - parameter maxPriorityFeePerGas: Max Priority Fee per Gas as defined in EIP1559. Only required for EIP1559 transactions.
     * - parameter gasLimit: The gas limit for this transaction.
     * - parameter to: The address of the receiver.
     * - parameter value: The value to be sent by this transaction in wei.
     * - parameter data: Input data for this transaction.
     * - parameter v: EC signature parameter v, or a EIP155 chain id for an unsigned transaction.
     * - parameter r: EC signature parameter r.
     * - parameter s: EC recovery ID.
     * - parameter chainId: The RLPItem only needs chainId for non-legacy txs as EIP155 encodes chainId in `v` for legacy txs.
     * - parameter accessList: accessList as defined in EIP2930. Needs to have the correct format to be considered a valid tx.
     * - parameter transactionType: Type of this transaction. Defaults to `.legacy`.
     */
    init(
        nonce: EthereumQuantity,
        gasPrice: EthereumQuantity,
        maxFeePerGas: EthereumQuantity? = nil,
        maxPriorityFeePerGas: EthereumQuantity? = nil,
        gasLimit: EthereumQuantity,
        to: EthereumAddress?,
        value: EthereumQuantity,
        data: EthereumData,
        v: EthereumQuantity? = nil,
        r: EthereumQuantity? = nil,
        s: EthereumQuantity? = nil,
        chainId: EthereumQuantity? = nil,
        accessList: OrderedDictionary<EthereumAddress, [EthereumData]> = [:],
        transactionType: EthereumTransaction.TransactionType = .legacy
    ) {
        switch transactionType {
        case .legacy:
            self = .array(
                .bigUInt(nonce.quantity),
                .bigUInt(gasPrice.quantity),
                .bigUInt(gasLimit.quantity),
                .bytes(to?.rawAddress ?? Bytes()),
                .bigUInt(value.quantity),
                .bytes(data.bytes),
                .bigUInt(v?.quantity ?? BigUInt(0)),
                .bigUInt(r?.quantity ?? BigUInt(0)),
                .bigUInt(s?.quantity ?? BigUInt(0))
            )
        case .eip1559:
            var accessListRLP: [RLPItem] = []
            for (key, value) in accessList {
                accessListRLP.append(.array([
                    .bytes(key.rawAddress),
                    .array(value.map({ return .bytes($0.bytes) }))
                ]))
            }
            
            var rlpToEncode: [RLPItem] = [
                .bigUInt(chainId?.quantity ?? EthereumQuantity(integerLiteral: 0).quantity),
                .bigUInt(nonce.quantity),
                .bigUInt(maxPriorityFeePerGas?.quantity ?? EthereumQuantity(integerLiteral: 0).quantity),
                .bigUInt(maxFeePerGas?.quantity ?? EthereumQuantity(integerLiteral: 0).quantity),
                .bigUInt(gasLimit.quantity),
                .bytes(to?.rawAddress ?? Bytes()),
                .bigUInt(value.quantity),
                .bytes(data.bytes),
                .array(accessListRLP),
            ]
            if let v = v, let r = r, let s = s {
                rlpToEncode.append(contentsOf: [
                    .bigUInt(v.quantity),
                    .bigUInt(r.quantity),
                    .bigUInt(s.quantity)
                ])
            }
            
            self = .array(
                rlpToEncode
            )
        }
    }
}

