import CryptoSwift

public func keccak256MessageHash(_ message:[UInt8]) -> [UInt8]{
    let messageHash = SHA3(variant: .keccak256).calculate(for: message)
    return messageHash
}
