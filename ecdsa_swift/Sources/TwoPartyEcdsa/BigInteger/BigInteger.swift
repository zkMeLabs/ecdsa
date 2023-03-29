//
//  BigInt.swift
//  BigInt
//
//  Created by Leif Ibsen on 24/12/2018.
//  Copyright © 2018 Leif Ibsen. All rights reserved.
// Copy From:https://github.com/leif-ibsen/BigInt.git

import Foundation

/// Unsigned 8 bit value
public typealias Byte = UInt8
/// Array of unsigned 8 bit values
public typealias Bytes = [UInt8]

/// Unsigned 64 bit value
public typealias Limb = UInt64
/// Array of unsigned 64 bit values
public typealias Limbs = [UInt64]

precedencegroup ExponentiationPrecedence {
    associativity: left
    higherThan: MultiplicationPrecedence
    lowerThan: BitwiseShiftPrecedence
}

infix operator ** : ExponentiationPrecedence

/// A signed integer of unbounded size.
/// A BigInteger value is represented with magnitude and sign.
/// The magnitude is an array of unsigned 64 bit integers (a.k.a. Limbs).
/// The sign is a boolean value, *true* means value < 0, *false* means value >= 0
/// The representation is little-endian, least significant Limb has index 0.
/// The representation is minimal, there is no leading zero Limbs.
/// The exception is that the value 0 is represented as a single 64 bit zero Limb and sign *false*
public struct BigInteger: CustomStringConvertible, Comparable, Equatable, Hashable {

    static let digits: [Character] = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

    
    // MARK: - Constants

    /// BigInteger(0)
    public static let ZERO = BigInteger(0)
    /// BigInteger(1)
    public static let ONE = BigInteger(1)
    /// BigInteger(2)
    public static let TWO = BigInteger(2)
    /// BigInteger(3)
    public static let THREE = BigInteger(3)
    /// BigInteger(4)
    public static let FOUR = BigInteger(4)
    /// BigInteger(5)
    public static let FIVE = BigInteger(5)
    /// BigInteger(6)
    public static let SIX = BigInteger(6)
    /// BigInteger(7)
    public static let SEVEN = BigInteger(7)
    /// BigInteger(8)
    public static let EIGHT = BigInteger(8)
    /// BigInteger(9)
    public static let NINE = BigInteger(9)
    /// BigInteger(10)
    public static let TEN = BigInteger(10)


    // MARK: - Initializers

    /// Constructs a BigInteger from magnitude and sign
    ///
    /// - Parameters:
    ///   - magnitude: magnitude of value
    ///   - isNegative: *true* means negative value, *false* means 0 or positive value, default is *false*
    public init(_ magnitude: Limbs, _ isNegative : Bool = false) {
        self.magnitude = magnitude
        self.magnitude.normalize()
        self.isNegative = isNegative
        if self.isZero {
            self.isNegative = false
        }
    }

    /// Constructs a BigInteger from an Int value
    ///
    /// - Parameter x: Int value
    public init(_ x: Int) {
        if x == Int.min {
            self.init([0x8000000000000000], true)
        } else if x < 0 {
            self.init([Limb(-x)], true)
        } else {
            self.init([Limb(x)], false)
        }
    }
    
    /// Constructs a BigInteger from a decimal value
    ///
    /// - Parameters:
    ///   - d: The decimal value
    /// - Returns: The BigInteger corresponding to *d* truncated to an integer value, *nil* if *d* is infinite or NaN
    public init?(_ d: Double) {
        if d.isNaN || d.isInfinite {
            return nil
        }
        let bits = d.bitPattern
        let exponent = Int(bits >> 52) & 0x7ff - 1075
        let significand = exponent == -1075 ? bits & 0xfffffffffffff << 1 : bits & 0xfffffffffffff | (1 << 52)
        if exponent < 0 {
            self.init([significand].shiftedRight(-exponent), d < 0.0)
        } else {
            self.init([significand].shiftedLeft(exponent), d < 0.0)
        }
    }

    /// Constructs a BigInteger from a String value and radix
    ///
    /// - Parameters:
    ///   - x: String value to be converted
    ///   - radix: Radix of x, from 2 to 36 inclusive, default is 10
    ///   Returns: The BigInteger corresponding to *x*, *nil* if *x* does not designate an integer in the given radix
    ///
    /// Examples:
    ///    * BigInteger("90abcdef", radix = 16)
    ///    * BigInteger("111110010", radix = 2)
    ///    * BigInteger("1cdefghijk44", radix = 26)
    public init?(_ x: String, radix: Int = 10) {
        if radix < 2 || radix > 36 {
            return nil
        }
        var sign = false
        var number = x
        if number.hasPrefix("-") {
            sign = true
            number.remove(at: number.startIndex)
        } else if number.hasPrefix("+") {
            number.remove(at: number.startIndex)
        }
        if number.isEmpty {
            return nil
        }
        var magnitude = [Limb(0)]
        
        // Find the number of digits that fits in a single Limb for the given radix
        // Process that number of digits at a time
        let digits = BigInteger.limbDigits[radix]
        
        // Groups of digits
        let digitGroups = number.count / digits
        
        // Pow = radix ** digits
        let pow = BigInteger.limbRadix[radix]
        
        // Number of digits to process
        var g = number.count - digitGroups * digits
        if g == 0 {
            g = digits
        }
        var i = 0
        var l = Limb(0)
        for c in number {
            if let digit = BigInteger.digits.firstIndex(of: c) {
                let d = digit < 36 ? digit : digit - 26
                if d >= radix {
                    return nil
                }
                l *= Limb(radix)
                l += Limb(d)
            } else {
                return nil
            }
            i += 1
            if i == g {
                magnitude.multiply(pow)
                magnitude.add(l)
                g = digits
                l = 0
                i = 0
            }
        }
        self.init(magnitude, sign)
    }

    /// Constructs a random BigInteger with a specified number of bits
    ///
    /// - Precondition: bitWidth is positive
    /// - Parameter bitWidth: Number of bits
    public init(bitWidth: Int) {
        precondition(bitWidth > 0, "Bitwidth must be positive")
        let (q, r) = bitWidth.quotientAndRemainder(dividingBy: 64)
        var limbs = Limbs(repeating: 0, count: r == 0 ? q : q + 1)
        BigInteger.randomLimbs(&limbs)
        if r > 0 {
            limbs[limbs.count - 1] <<= 64 - r
            limbs[limbs.count - 1] >>= 64 - r
        }
        self.init(limbs)
    }
    
    /// Constructs a BigInteger from a big-endian magnitude byte array representation
    ///
    /// - Precondition: Byte array is not empty
    /// - Parameter x: Magnitude big-endian byte array
    ///
    /// Examples:
    ///    * The byte array [1, 0, 0] represents BigInteger value 65536
    ///    * The byte array [128, 0] represents BigInteger value 32768
    ///    * The byte array [255, 127] represents BigInteger value 65407
    public init(magnitude x: Bytes) {
        precondition(!x.isEmpty, "Empty byte array")
        var bb = x
        if bb[0] > 127 {
            bb.insert(0, at: 0)
        }
        self.init(signed: bb)
    }
    
    /// Constructs a BigInteger from a big-endian 2's complement byte array representation
    ///
    /// - Precondition: Byte array is not empty
    /// - Parameter x: 2's complement big-endian byte array
    ///
    /// Examples:
    ///    * The byte array [1, 0, 0] represents BigInteger value 65536
    ///    * The byte array [128, 0] represents BigInteger value -32768
    ///    * The byte array [255, 127] represents BigInteger value -129
    public init(signed x: Bytes) {
        precondition(!x.isEmpty, "Empty byte array")
        self.isNegative = x[0] > 127
        var bb = x
        if self.isNegative {
            while bb.count > 1 && bb[0] == 255 {
                bb.remove(at: 0)
            }
        } else {
            while bb.count > 1 && bb[0] == 0 {
                bb.remove(at: 0)
            }
        }
        if self.isNegative {
            var carry = true
            var bbi = bb.count
            for _ in 0 ..< bb.count {
                bbi -= 1
                bb[bbi] = ~bb[bbi]
                if carry {
                    if bb[bbi] == 255 {
                        bb[bbi] = 0
                    } else {
                        bb[bbi] += 1
                        carry = false
                    }
                }
            }
            if carry {
                bb.insert(1, at: 0)
            }
        }
        let chunks = bb.count / 8
        let remaining = bb.count - chunks * 8
        self.magnitude = Limbs(repeating: 0, count: chunks + (remaining == 0 ? 0 : 1))
        var bi = 0
        var li = self.magnitude.count
        if remaining > 0 {
            li -= 1
        }
        for _ in 0 ..< remaining {
            self.magnitude[li] <<= 8
            self.magnitude[li] |= Limb(bb[bi])
            bi += 1
        }
        for _ in 0 ..< chunks {
            li -= 1
            for _ in 0 ..< 8 {
                self.magnitude[li] <<= 8
                self.magnitude[li] |= Limb(bb[bi])
                bi += 1
            }
        }
    }

    
    // MARK: Stored properties
    
    /// The sign, *true* if *self* < 0, *false* otherwise
    public internal(set) var isNegative: Bool

    /// The magnitude limb array
    public internal(set) var magnitude: Limbs

    
    // MARK: Computed properties
    
    /// The absolute value of *self*
    public var abs: BigInteger {
        return BigInteger(self.magnitude)
    }

    /// The number of bits in the binary representation of the magnitude of *self*. 0 if *self* = 0
    public var bitWidth: Int {
        return self.magnitude.bitWidth
    }
    
    /// Base 10 string value of *self*
    public var description: String {
        return self.asString()
    }
    
    /// Is *true* if *self* is even, *false* if *self* is odd
    public var isEven: Bool {
        return self.magnitude[0] & 1 == 0
    }
    
    /// Is *false* if *self* = 0, *true* otherwise
    public var isNotZero: Bool {
        return self.magnitude.count > 1 || self.magnitude[0] > 0
    }
    
    /// Is *true* if *self* is odd, *false* if *self* is even
    public var isOdd: Bool {
        return self.magnitude[0] & 1 == 1
    }
    
    /// Is *true* if *self* = 1, *false* otherwise
    public var isOne: Bool {
        return self.magnitude.count == 1 && self.magnitude[0] == 1 && !self.isNegative
    }
    
    /// Is *true* if *self* > 0, *false* otherwise
    public var isPositive: Bool {
        return !self.isNegative && self.isNotZero
    }

    /// Is *true* if *self* = 0, *false* otherwise
    public var isZero: Bool {
        return self.magnitude.count == 1 && self.magnitude[0] == 0
    }

    /// The number of leading zero bits in the magnitude of *self*. 0 if *self* = 0
    public var leadingZeroBitCount: Int {
        return self.isZero ? 0 : self.magnitude.last!.leadingZeroBitCount
    }
    
    /// The number of 1 bits in the magnitude of *self*
    public var population: Int {
        var p = 0
        for m in self.magnitude {
            p += BigInteger.population(m)
        }
        return p
    }

    /// Is 0 if *self* = 0, 1 if *self* > 0, and -1 if *self* < 0
    public var signum: Int {
        return self.isZero ? 0 : (self.isNegative ? -1 : 1)
    }

    /// The number of trailing zero bits in the magnitude of *self*. 0 if *self* = 0
    public var trailingZeroBitCount: Int {
        return self.magnitude.trailingZeroBitCount()
    }

    /*
     * [HACKER] - chapter 5-1
     */
    static func population(_ m: Limb) -> Int {
        var x = m
        x = x & 0x5555555555555555 + (x >>  1) & 0x5555555555555555
        x = x & 0x3333333333333333 + (x >>  2) & 0x3333333333333333
        x = x & 0x0f0f0f0f0f0f0f0f + (x >>  4) & 0x0f0f0f0f0f0f0f0f
        x += x >>  8
        x += x >> 16
        x += x >> 32
        return Int(x & 0x7f)
    }

    mutating func setSign(_ sign: Bool) {
        self.isNegative = self.isZero ? false : sign
    }

    
    // MARK: Conversion functions to Double, Int, String, and Bytes
    
    static let d264 = Double(sign: .plus, exponent: 64, significand: 1.0) // = 2.0 ^ 64
    
    /// *self* as a Double
    ///
    /// - Returns: *self* as a Double or *Infinity* if *self* is not representable as a Double
    public func asDouble() -> Double {
        var d = 0.0
        for m in self.magnitude.reversed() {
            d *= BigInteger.d264
            d += Double(m)
        }
        return self.isNegative ? -d : d
    }

    /// *self* as an Int
    ///
    /// - Returns: *self* as an Int or *nil* if *self* is not representable as an Int
    public func asInt() -> Int? {
        if self.magnitude.count > 1 {
            return nil
        }
        let mag0 = self.magnitude[0]
        if self.isNegative {
            return mag0 > 0x8000000000000000 ? nil : (mag0 == 0x8000000000000000 ? Int.min : -Int(mag0))
        } else {
            return mag0 < 0x8000000000000000 ? Int(mag0) : nil
        }
    }
    
    static let zeros = "000000000000000000000000000000000000000000000000000000000000000"
    // Number of digits in a 64 bit word for each radix
    static let limbDigits = [0, 0,
                             63, 40, 31, 27, 24, 22, 21, 20, 19, 18, 17, 17, 16, 16, 15, 15, 15,
                             15, 14, 14, 14, 14, 13, 13, 13, 13, 13, 13, 13, 12, 12, 12, 12, 12, 12]
    // limbRadix[i] = i ** limbDigits[i]
    static let limbRadix: Limbs = [0, 0,
                            0x8000000000000000,
                            0xa8b8b452291fe821,
                            0x4000000000000000,
                            0x6765c793fa10079d,
                            0x41c21cb8e1000000,
                            0x3642798750226111,
                            0x8000000000000000,
                            0xa8b8b452291fe821,
                            0x8ac7230489e80000,
                            0x4d28cb56c33fa539,
                            0x1eca170c00000000,
                            0x780c7372621bd74d,
                            0x1e39a5057d810000,
                            0x5b27ac993df97701,
                            0x1000000000000000,
                            0x27b95e997e21d9f1,
                            0x5da0e1e53c5c8000,
                            0xd2ae3299c1c4aedb,
                            0x16bcc41e90000000,
                            0x2d04b7fdd9c0ef49,
                            0x5658597bcaa24000,
                            0xa0e2073737609371,
                            0xc29e98000000000,
                            0x14adf4b7320334b9,
                            0x226ed36478bfa000,
                            0x383d9170b85ff80b,
                            0x5a3c23e39c000000,
                            0x8e65137388122bcd,
                            0xdd41bb36d259e000,
                            0xaee5720ee830681,
                            0x1000000000000000,
                            0x172588ad4f5f0981,
                            0x211e44f7d02c1000,
                            0x2ee56725f06e5c71,
                            0x41c21cb8e1000000]

    /// Byte array representation of magnitude value
    ///
    /// - Returns: Minimal big-endian magnitude byte array representation
    ///
    /// Examples:
    ///    * BigInteger(1).asMagnitudeBytes() = [1]
    ///    * BigInteger(-1).asMagnitudeBytes() = [1]
    public func asMagnitudeBytes() -> Bytes {
        var bb = (self.isNegative ? -self : self).asSignedBytes()
        while bb.count > 1 && bb[0] == 0 {
            bb.remove(at: 0)
        }
        return bb
    }
    
    /// Byte array representation of 2's complement value
    ///
    /// - Returns: Minimal big-endian 2's complement byte array representation
    ///
    /// Examples:
    ///    * BigInteger(1).asSignedBytes() = [1]
    ///    * BigInteger(-1).asSignedBytes() = [255]
    public func asSignedBytes() -> Bytes {
        var xl = self.magnitude
        if self.isNegative {
            var carry = true
            for i in 0 ..< xl.count {
                xl[i] = ~xl[i]
                if carry {
                    if xl[i] == Limb.max {
                        xl[i] = 0
                    } else {
                        xl[i] += 1
                        carry = false
                    }
                }
            }
        }
        var bb = Bytes(repeating: 0, count: xl.count * 8)
        var bbi = bb.count
        for i in 0 ..< xl.count {
            var l = xl[i]
            for _ in 0 ..< 8 {
                bbi -= 1
                bb[bbi] = Byte(l & 0xff)
                l >>= 8
            }
        }
        if self.isNegative {
            if bb[0] < 128 {
                bb.insert(255, at: 0)
            }
            while bb.count > 1 && bb[0] == 255 && bb[1] > 127 {
                bb.remove(at: 0)
            }
        } else {
            if bb[0] > 127 {
                bb.insert(0, at: 0)
            }
            while bb.count > 1 && bb[0] == 0 && bb[1] < 128 {
                bb.remove(at: 0)
            }
        }
        return bb
    }
    
    /// *self* as a String with a given radix
    ///
    /// - Precondition: Radix between 2 and 36 inclusive
    /// - Parameters:
    ///   - radix: Radix from 2 to 36 inclusive
    ///   - uppercase: *true* to use uppercase letters, *false* to use lowercase letters, default is *false*
    /// - Returns: *self* as a String in the given radix
    public func asString(radix: Int = 10, uppercase: Bool = false) -> String {
        precondition(radix >= 2 && radix <= 36, "Wrong radix \(radix)")
        if self.isZero {
            return "0"
        }
        let d = BigInteger.limbRadix[radix]
        var digitGroups = [String]()
        var tmp = self.magnitude
        while !tmp.equalTo(0) {
            let (q, r) = tmp.divMod(d)
            digitGroups.append(String(r, radix: radix, uppercase: uppercase))
            tmp = q
        }
        var result = self.isNegative ? "-" : ""
        result += digitGroups.last!
        for i in (0 ..< digitGroups.count - 1).reversed() {
            let leadingZeros = BigInteger.limbDigits[radix] - digitGroups[i].count
            result += BigInteger.zeros.prefix(leadingZeros)
            result += digitGroups[i]
        }
        return result
    }

    static func toSignedLimbsPair(_ x: BigInteger, _ y: BigInteger) -> (bx: Limbs, by: Limbs) {
        var bx = x.magnitude
        var by = y.magnitude
        if x.isNegative {
            invert(&bx)
            if bx.last! & 0x8000000000000000 == 0 {
                bx.append(0xffffffffffffffff)
            }
        } else {
            if bx.last! & 0x8000000000000000 != 0 {
                bx.append(0)
            }
        }
        if y.isNegative {
            invert(&by)
            if by.last! & 0x8000000000000000 == 0 {
                by.append(0xffffffffffffffff)
            }
        } else {
            if by.last! & 0x8000000000000000 != 0 {
                by.append(0)
            }
        }
        let x0: Limb = bx.last! & 0x8000000000000000 == 0 ? 0 : 0xffffffffffffffff
        let y0: Limb = by.last! & 0x8000000000000000 == 0 ? 0 : 0xffffffffffffffff
        while bx.count < by.count {
            bx.append(x0)
        }
        while by.count < bx.count {
            by.append(y0)
        }
        return (bx, by)
    }

    static func fromSignedLimbs(_ x: inout Limbs) -> BigInteger {
        if x.last! & 0x8000000000000000 != 0 {
            invert(&x)
            return BigInteger(x, true)
        }
        return BigInteger(x)
    }

    static func invert(_ x: inout Limbs) {
        // flip the bits
        for i in 0 ..< x.count {
            x[i] ^= 0xffffffffffffffff
        }
        // and add 1
        var i = 0
        var carry = true
        while carry && i < x.count {
            x[i] = x[i] &+ 1
            carry = x[i] == 0
            i += 1
        }
        if carry {
            x.append(1)
        }
    }

    
    // MARK: Bit operation functions

    /// Bitwise **and** operator - behaves as if two's complement representation were used,</br>
    /// although this is not actually the case
    ///
    /// - Parameters:
    ///   - x: First value
    ///   - y: Second value
    /// - Returns: BigInteger(signed: bx & by) where
    ///   - bx = x.asSignedBytes()
    ///   - by = y.asSignedBytes()
    public static func &(x: BigInteger, y: BigInteger) -> BigInteger {
        var (bx, by) = toSignedLimbsPair(x, y)
        for i in 0 ..< bx.count {
            bx[i] = bx[i] & by[i]
        }
        return fromSignedLimbs(&bx)
    }

    /// x = x & y
    ///
    /// - Parameters:
    ///   - x: Left hand parameter
    ///   - y: Right hand parameter
    public static func &=(x: inout BigInteger, y: BigInteger) {
        x = x & y
    }
    
    /// Bitwise **or** operator - behaves as if two's complement representation were used,</br>
    /// although this is not actually the case
    ///
    /// - Parameters:
    ///   - x: First value
    ///   - y: Second value
    /// - Returns: BigInteger(signed: bx | by) where
    ///   - bx = x.asSignedBytes()
    ///   - by = y.asSignedBytes()
    public static func |(x: BigInteger, y: BigInteger) -> BigInteger {
        var (bx, by) = toSignedLimbsPair(x, y)
        for i in 0 ..< bx.count {
            bx[i] = bx[i] | by[i]
        }
        return fromSignedLimbs(&bx)
    }

    /// x = x | y
    ///
    /// - Parameters:
    ///   - x: Left hand parameter
    ///   - y: Right hand parameter
    public static func |=(x: inout BigInteger, y: BigInteger) {
        x = x | y
    }
    
    /// Bitwise **xor** operator - behaves as if two's complement representation were used,</br>
    /// although this is not actually the case
    ///
    /// - Parameters:
    ///   - x: First value
    ///   - y: Second value
    /// - Returns: BigInteger(signed: bx ^ by) where
    ///   - bx = x.asSignedBytes()
    ///   - by = y.asSignedBytes()
    public static func ^(x: BigInteger, y: BigInteger) -> BigInteger {
        var (bx, by) = toSignedLimbsPair(x, y)
        for i in 0 ..< bx.count {
            bx[i] = bx[i] ^ by[i]
        }
        return fromSignedLimbs(&bx)
    }

    /// x = x ^ y
    ///
    /// - Parameters:
    ///   - x: Left hand parameter
    ///   - y: Right hand parameter
    public static func ^=(x: inout BigInteger, y: BigInteger) {
        x = x ^ y
    }
    
    /// Bitwise **not** operator - behaves as if two's complement arithmetic were used,</br>
    /// although this is not actually the case
    ///
    /// - Parameter x: BigInteger value
    /// - Returns: -x - 1
    public static prefix func ~(x: BigInteger) -> BigInteger {
        return -x - 1
    }
    
    /// Clear a specified bit - a no-op if bit number < 0
    ///
    /// - Parameter n: Bit number
    public mutating func clearBit(_ n: Int) {
        self.magnitude.clearBitAt(n)
    }
    
    /// Invert a specified bit - a no-op if bit number < 0
    ///
    /// - Parameter n: Bit number
    public mutating func flipBit(_ n: Int) {
        self.magnitude.flipBitAt(n)
    }
    
    /// Set a specified bit - a no-op if bit number < 0
    ///
    /// - Parameter n: Bit number
    public mutating func setBit(_ n: Int) {
        self.magnitude.setBitAt(n)
    }
    
    /// Test a specified bit - *false* if bit number < 0
    ///
    /// - Parameter n: Bit number
    /// - Returns: *true* if bit is set, *false* otherwise
    public func testBit(_ n: Int) -> Bool {
        return self.magnitude.testBitAt(n)
    }

    
    // MARK: Addition functions
    
    /// Prefix plus
    ///
    /// - Parameter x: BigInteger value
    /// - Returns: x
    public prefix static func +(x: BigInteger) -> BigInteger {
        return x
    }
    
    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: x + y
    public static func +(x: BigInteger, y: BigInteger) -> BigInteger {
        var sum = x
        sum += y
        return sum
    }
    
    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: x + y
    public static func +(x: Int, y: BigInteger) -> BigInteger {
        var sum = y
        sum += x
        return sum
    }

    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: x + y
    public static func +(x: BigInteger, y: Int) -> BigInteger {
        var sum = x
        sum += y
        return sum
    }

    /// x = x + y
    ///
    /// - Parameters:
    ///   - x: Left hand addend
    ///   - y: Right hand addend
    public static func +=(x: inout BigInteger, y: BigInteger) {
        if x.isNegative == y.isNegative {
            x.magnitude.add(y.magnitude)
        } else {
            let cmp = x.magnitude.difference(y.magnitude)
            if cmp < 0 {
                x.isNegative = !x.isNegative
            } else if cmp == 0 {
                x.isNegative = false
            }
        }
    }

    /// x = x + y
    ///
    /// - Parameters:
    ///   - x: Left hand addend
    ///   - y: Right hand addend
    public static func +=(x: inout BigInteger, y: Int) {
        
        // Better performance than simply
        // x += BigInteger(y)
        
        if y > 0 {
            if x.isNegative {
                if x.magnitude.difference(Limb(y)) <= 0 {
                    x.setSign(false)
                }
            } else {
                x.magnitude.add(Limb(y))
            }
        } else if y < 0 {
            let yy = y == Int.min ? 0x8000000000000000 : Limb(-y)
            if x.isNegative {
                x.magnitude.add(yy)
            } else {
                if x.magnitude.difference(yy) < 0 {
                    x.setSign(true)
                }
            }
        }
    }

    
    // MARK: Negation functions
    
    /// Negates *self*
    public mutating func negate() {
        if self.isNotZero {
            self.isNegative = !self.isNegative
        }
    }
    
    /// Negation
    ///
    /// - Parameter x: Operand
    /// - Returns: -x
    public static prefix func -(x: BigInteger) -> BigInteger {
        var y = x
        y.negate()
        return y
    }
    
    
    // MARK: Subtraction functions

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: x - y
    public static func -(x: BigInteger, y: BigInteger) -> BigInteger {
        var diff = x
        diff -= y
        return diff
    }
    
    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: x - y
    public static func -(x: Int, y: BigInteger) -> BigInteger {
        var diff = y
        diff -= x
        return -diff
    }

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: x - y
    public static func -(x: BigInteger, y: Int) -> BigInteger {
        var diff = x
        diff -= y
        return diff
    }

    /// x = x - y
    ///
    /// - Parameters:
    ///   - x: Left hand minuend
    ///   - y: Right hand subtrahend
    public static func -=(x: inout BigInteger, y: BigInteger) {
        if x.isNegative == y.isNegative {
            let cmp = x.magnitude.difference(y.magnitude)
            if cmp < 0 {
                x.isNegative = !x.isNegative
            } else if cmp == 0 {
                x.isNegative = false
            }
        } else {
            x.magnitude.add(y.magnitude)
        }
    }

    /// x = x - y
    ///
    /// - Parameters:
    ///   - x: Left hand minuend
    ///   - y: Right hand subtrahend
    public static func -=(x: inout BigInteger, y: Int) {
        
        // Better performance than simply
        // x -= BigInteger(y)
        
        if y > 0 {
            if x.isNegative {
                x.magnitude.add(Limb(y))
            } else {
                if x.magnitude.difference(Limb(y)) < 0 {
                    x.setSign(true)
                }
            }
        } else if y < 0 {
            let yy = y == Int.min ? 0x8000000000000000 : Limb(-y)
            if x.isPositive {
                x.magnitude.add(yy)
            } else {
                if x.magnitude.difference(yy) <= 0 {
                    x.setSign(false)
                }
            }
        }
    }


    // MARK: Multiplication functions
    
    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: x * y
    public static func *(x: BigInteger, y: BigInteger) -> BigInteger {
        var prod = x
        prod *= y
        return prod
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: x * y
    public static func *(x: Int, y: BigInteger) -> BigInteger {
        var prod = y
        prod *= x
        return prod
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: x * y
    public static func *(x: BigInteger, y: Int) -> BigInteger {
        var prod = x
        prod *= y
        return prod
    }

    /// x = x * y
    ///
    /// - Parameters:
    ///   - x: Left hand multiplier
    ///   - y: Right hand multiplicand
    public static func *=(x: inout BigInteger, y: BigInteger) {
        x.magnitude.multiply(y.magnitude)
        x.setSign(x.isNegative != y.isNegative)
    }

    /// x = x * y
    ///
    /// - Parameters:
    ///   - x: Left hand multiplier
    ///   - y: Right hand multiplicand
    public static func *=(x: inout BigInteger, y: Int) {
        if y > 0 {
            x.magnitude.multiply(Limb(y))
        } else if y < 0 {
            if y == Int.min {
                x.magnitude.shiftLeft(63)
            } else {
                x.magnitude.multiply(Limb(-y))
            }
            x.setSign(!x.isNegative)
        } else {
            x = BigInteger.ZERO
        }
    }
    
    
    // MARK: Division functions
    
    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameter x: Divisor - a BigInteger value
    /// - Returns: Quotient and remainder of *self* / x
    public func quotientAndRemainder(dividingBy x: BigInteger) -> (quotient: BigInteger, remainder: BigInteger) {
        var quotient = BigInteger.ZERO
        var remainder = BigInteger.ZERO
        if x.magnitude.count > Limbs.BZ_DIV_LIMIT && self.magnitude.count > x.magnitude.count + Limbs.BZ_DIV_LIMIT {
            (quotient.magnitude, remainder.magnitude) = self.magnitude.bzDivMod(x.magnitude)
        } else {
            (quotient.magnitude, remainder.magnitude) = self.magnitude.divMod(x.magnitude)
        }
        quotient.setSign(self.isNegative != x.isNegative)
        remainder.setSign(self.isNegative)
        return (quotient, remainder)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Divisor - a BigInteger value
    ///   - quotient: Set to the quotient of *self* / x
    ///   - remainder: Set to the remainder of *self* / x
    public func quotientAndRemainder(dividingBy x: BigInteger, _ quotient: inout BigInteger, _ remainder: inout BigInteger) {
        (quotient, remainder) = self.quotientAndRemainder(dividingBy: x)
    }
    
    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameter x: Divisor - an Int value
    /// - Returns: Quotient and remainder of *self* / x
    public func quotientAndRemainder(dividingBy x: Int) -> (quotient: BigInteger, remainder: Int) {
        var divisor: Limb
        if x < 0 {
            divisor = x == Int.min ? 0x8000000000000000 : Limb(-x)
        } else {
            divisor = Limb(x)
        }
        var quotient = BigInteger.ZERO
        var r: Limb
        (quotient.magnitude, r) = self.magnitude.divMod(divisor)
        quotient.setSign(self.isNegative && x > 0 || self.isPositive && x < 0)
        let remainder = self.isNegative ? -Int(r) : Int(r)
        return (quotient, remainder)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Divisor - an Int value
    ///   - quotient: Set to the quotient of *self* / x
    ///   - remainder: Set to the remainder of *self* / x
    public func quotientAndRemainder(dividingBy x: Int, _ quotient: inout BigInteger, _ remainder: inout Int) {
        (quotient, remainder) = self.quotientAndRemainder(dividingBy: x)
    }
    
    /// Exact division - that is, the remainder of the division is known to be 0
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameter x: Divisor - a BigInteger value
    /// - Returns: Quotient of *self* / x - undefined if the remainder is in fact not 0
    public func quotientExact(dividingBy x: BigInteger) -> BigInteger {
        return BigInteger(self.magnitude.divExact(x.magnitude), self.isNegative != x.isNegative)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x / y
    public static func /(x: BigInteger, y: BigInteger) -> BigInteger {
        return x.quotientAndRemainder(dividingBy: y).quotient
    }
    
    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x / y
    public static func /(x: Int, y: BigInteger) -> BigInteger {
        return BigInteger(x) / y
    }
    
    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x / y
    public static func /(x: BigInteger, y: Int) -> BigInteger {
        return x.quotientAndRemainder(dividingBy: y).quotient
    }
    
    /// x = x / y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Left hand dividend
    ///   - y: Right hand divisor
    public static func /=(x: inout BigInteger, y: BigInteger) {
        x = x / y
    }
    
    /// x = x / y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Left hand dividend
    ///   - y: Right hand divisor
    public static func /=(x: inout BigInteger, y: Int) {
        x = x / y
    }


    // MARK: Remainder and modulus functions
    
    /// Remainder
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x % y
    public static func %(x: BigInteger, y: BigInteger) -> BigInteger {
        return x.quotientAndRemainder(dividingBy: y).remainder
    }
    
    /// Remainder
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x % y
    public static func %(x: Int, y: BigInteger) -> BigInteger {
        return BigInteger(x) % y
    }

    /// Remainder
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x % y
    public static func %(x: BigInteger, y: Int) -> BigInteger {
        return x % BigInteger(y)
    }

    /// x = x % y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    public static func %=(x: inout BigInteger, y: BigInteger) {
        x = x % y
    }

    /// x = x % y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    public static func %=(x: inout BigInteger, y: Int) {
        x = x % y
    }
    
    /// Modulus - BigInteger parameter
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameter x: Divisor
    /// - Returns: *self* *mod* x, a non-negative value
    public func mod(_ x: BigInteger) -> BigInteger {
        let r = self % x
        if x.isNegative {
            return r.isNegative ? r - x : r
        } else {
            return r.isNegative ? r + x : r
        }
    }
    
    /// Modulus - Int parameter
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameter x: Divisor
    /// - Returns: *self* *mod* x, a non-negative value
    public func mod(_ x: Int) -> Int {
        if x == Int.min {
            let r = Int(self.magnitude[0] & 0x7fffffffffffffff)
            return self.isNegative && r > 0 ? -(Int.min + r) : r
        }
        let absx = Limb(Swift.abs(x))
        let (_, r) = self.magnitude.divMod(absx)
        return Int(self.isNegative && r > 0 ? absx - r : r)
    }

    /*
     * [CRANDALL] - algorithm 2.1.4
     *
     * Return self modinverse m
     */
    /// Inverse modulus - BigInteger parameter
    ///
    /// - Precondition: *self* and modulus are coprime, modulus is positive
    /// - Parameter m: Modulus
    /// - Returns: If *self* and m are coprime, x such that (*self* * x) mod m = 1
    public func modInverse(_ m: BigInteger) -> BigInteger {
        precondition(m.isPositive, "Modulus must be positive")
        var a = BigInteger.ONE
        var g = self.mod(m)
        var u = BigInteger.ZERO
        var w = m
        while w.isPositive {
            let (q, r) = g.quotientAndRemainder(dividingBy: w)
            (a, g, u, w) = (u, w, a - q * u, r)
        }
        precondition(g.isOne, "Modulus and self are not coprime")
        return a.isNegative ? a + m : a
    }

    /// Inverse modulus - Int parameter
    ///
    /// - Precondition: *self* and modulus are coprime, modulus is positive
    /// - Parameter m: Modulus
    /// - Returns: If *self* and m are coprime, x such that (*self* * x) mod m = 1
    public func modInverse(_ m: Int) -> Int {
        precondition(m > 0, "Modulus must be positive")
        var a = 1
        var g = self.mod(m)
        var u = 0
        var w = m
        while w > 0 {
            let (q, r) = g.quotientAndRemainder(dividingBy: w)
            (a, g, u, w) = (u, w, a - q * u, r)
        }
        precondition(g == 1, "Modulus and self are not coprime")
        return a < 0 ? a + m : a
    }


    // MARK: Exponentiation functions

    /// Exponentiation
    ///
    /// - Precondition: Exponent is non-negative
    /// - Parameters:
    ///   - a: Operand
    ///   - x: Non-negative exponent
    /// - Returns: a^x
    public static func **(a: BigInteger, x: Int) -> BigInteger {
        precondition(x >= 0, "Exponent must be non-negative")
        return x == 2 ? (a.magnitude.count > 16 ? BigInteger(a.magnitude.squared()) : a * a) : BigInteger(a.magnitude.raisedTo(x), a.isNegative && (x & 1 == 1))
    }

    /*
     * Return (self ** x) mod m
     *
     * Use Barrett reduction algorithm for x.bitWidth < 2048, else use Montgomery reduction algorithm
     */
    /// Modular exponentiation
    ///
    /// - Precondition: Modulus is positive
    /// - Parameters:
    ///   - x: The exponent
    ///   - m: The modulus, a positive number
    /// - Returns: (*self*^x) mod m for positive x, ((*self*^-x) mod m) modInverse m for negative x
    public func expMod(_ x: BigInteger, _ m: BigInteger) -> BigInteger {
        precondition(m.isPositive, "Modulus must be positive")
        if m.isOne {
            return BigInteger.ZERO
        }
        let exponent = x.isNegative ? -x : x
        var result: BigInteger
        if exponent.magnitude.count <= 32 {
            result = BarrettModulus(self, m).expMod(exponent)
        } else if m.isOdd {
            result = MontgomeryModulus(self, m).expMod(exponent)
        } else {
            
            // Split the modulus into an odd part and a power of 2 part
            
            let trailing = m.trailingZeroBitCount
            let oddModulus = m >> trailing
            let pow2Modulus = BigInteger.ONE << trailing
            let a1 = MontgomeryModulus(self, oddModulus).expMod(exponent)
            let a2 = Pow2Modulus(self, pow2Modulus).expMod(exponent)
            let y1 = pow2Modulus.modInverse(oddModulus)
            let y2 = oddModulus.modInverse(pow2Modulus)
            result = (a1 * pow2Modulus * y1 + a2 * oddModulus * y2).mod(m)
        }
        if x.isNegative {
            result = result.modInverse(m)
        }
        if self.isNegative {
            return x.isEven || result.isZero ? result : m - result
        } else {
            return result
        }
    }


    // MARK: Comparison functions
    
    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x = y, *false* otherwise
    public static func ==(x: BigInteger, y: BigInteger) -> Bool {
        return x.magnitude == y.magnitude && x.isNegative == y.isNegative
    }
    
    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x = y, *false* otherwise
    public static func ==(x: BigInteger, y: Int) -> Bool {
        return x == BigInteger(y)
    }
    
    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x = y, *false* otherwise
    public static func ==(x: Int, y: BigInteger) -> Bool {
        return BigInteger(x) == y
    }
    
    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x != y, *false* otherwise
    public static func !=(x: BigInteger, y: BigInteger) -> Bool {
        return x.magnitude != y.magnitude || x.isNegative != y.isNegative
    }
    
    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x != y, *false* otherwise
    public static func !=(x: BigInteger, y: Int) -> Bool {
        return x != BigInteger(y)
   }
    
    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x != y, *false* otherwise
    public static func !=(x: Int, y: BigInteger) -> Bool {
        return BigInteger(x) != y
    }
    
    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x < y, *false* otherwise
    public static func <(x: BigInteger, y: BigInteger) -> Bool {
        if x.isNegative {
            if y.isNegative {
                return y.magnitude.compare(x.magnitude) < 0
            } else {
                return true
            }
        } else {
            if y.isNegative {
                return false
            } else {
                return x.magnitude.compare(y.magnitude) < 0
            }
        }
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x < y, *false* otherwise
    public static func <(x: BigInteger, y: Int) -> Bool {
        if x.isNegative {
            if y < 0 {
                return y == Int.min ? x < BigInteger(y) : x.magnitude.compare(Limb(-y)) > 0
            } else {
                return true
            }
        } else {
            if y < 0 {
                return false
            } else {
                return x.magnitude.compare(Limb(y)) < 0
            }
        }
    }
    
    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x < y, *false* otherwise
    public static func <(x: Int, y: BigInteger) -> Bool {
        if y.isNegative {
            if x < 0 {
                return x == Int.min ? BigInteger(x) < y : y.magnitude.compare(Limb(-x)) <= 0
            } else {
                return false
            }
        } else {
            if x < 0 {
                return true
            } else {
                return y.magnitude.compare(Limb(x)) > 0
            }
        }
    }
    
    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x > y, *false* otherwise
    public static func >(x: BigInteger, y: BigInteger) -> Bool {
        return y < x
    }
    
    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x > y, *false* otherwise
    public static func >(x: Int, y: BigInteger) -> Bool {
        return y < x
    }
    
    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x > y, *false* otherwise
    public static func >(x: BigInteger, y: Int) -> Bool {
        return y < x
    }
    
    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x <= y, *false* otherwise
    public static func <=(x: BigInteger, y: BigInteger) -> Bool {
        return !(y < x)
    }
    
    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x <= y, *false* otherwise
    public static func <=(x: Int, y: BigInteger) -> Bool {
        return !(y < x)
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x <= y, *false* otherwise
    public static func <=(x: BigInteger, y: Int) -> Bool {
        return !(y < x)
    }
    
    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x >= y, *false* otherwise
    public static func >=(x: BigInteger, y: BigInteger) -> Bool {
        return !(x < y)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x >= y, *false* otherwise
    public static func >=(x: Int, y: BigInteger) -> Bool {
        return !(x < y)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x >= y, *false* otherwise
    public static func >=(x: BigInteger, y: Int) -> Bool {
        return !(x < y)
    }


    // MARK: Shift functions

    /// Logical left shift
    ///
    /// - Parameters:
    ///   - x: Operand
    ///   - n: Shift count
    /// - Returns:
    ///   - BigInteger(x.magnitude << n, x.isNegative) if n > 0
    ///   - BigInteger(x.magnitude >> -n, x.isNegative) if n < 0
    ///   - x if n = 0
    public static func <<(x: BigInteger, n: Int) -> BigInteger {
        if n < 0 {
            return n == Int.min ? (x >> Int.max) >> 1 : x >> -n
        }
        return BigInteger(n == 1 ? x.magnitude.shifted1Left() : x.magnitude.shiftedLeft(n), x.isNegative)
    }
    
    /// x = x << n
    ///
    /// - Parameters:
    ///   - x: Operand
    ///   - n: Shift count
    public static func <<=(x: inout BigInteger, n: Int) {
        if n < 0 {
            if n == Int.min {
                x.magnitude.shiftRight(Int.max)
                x.magnitude.shift1Right()
            } else {
                x.magnitude.shiftRight(-n)
            }
        } else if n == 1 {
            x.magnitude.shift1Left()
        } else {
            x.magnitude.shiftLeft(n)
        }
    }
    
    /// Logical right shift
    ///
    /// - Parameters:
    ///   - x: Operand
    ///   - n: Shift count
    /// - Returns:
    ///   - BigInteger(x.magnitude >> n, x.isNegative) if n > 0
    ///   - BigInteger(x.magnitude << -n, x.isNegative) if n < 0
    ///   - x if n = 0
    public static func >>(x: BigInteger, n: Int) -> BigInteger {
        if n < 0 {
            return n == Int.min ? (x << Int.max) << 1 : x << -n
        }
        return BigInteger(n == 1 ? x.magnitude.shifted1Right() : x.magnitude.shiftedRight(n), x.isNegative)
    }
    
    /// x = x >> n
    ///
    /// - Parameters:
    ///   - x: Operand
    ///   - n: Shift count
    public static func >>=(x: inout BigInteger, n: Int) {
        if n < 0 {
            if n == Int.min {
                x.magnitude.shiftLeft(Int.max)
                x.magnitude.shift1Left()
            } else {
                x.magnitude.shiftLeft(-n)
            }
        } else if n == 1 {
            x.magnitude.shift1Right()
        } else {
            x.magnitude.shiftRight(n)
        }
        if x.isZero {
            x.isNegative = false
        }
    }

    
    // MARK: Prime number functions
    
    static internal func randomBytes(_ bytes: inout Bytes) {
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            fatalError("randomBytes failed")
        }
    }
        
    static internal func randomLimbs(_ limbs: inout Limbs) {
        guard SecRandomCopyBytes(kSecRandomDefault, 8 * limbs.count, &limbs) == errSecSuccess else {
            fatalError("randomLimbs failed")
        }
    }
        
    // Small prime product
    static let SPP = BigInteger("152125131763605")! // = 3 * 5 * 7 * 11 * 13 * 17 * 19 * 23 * 29 * 31 * 37 * 41

    static func smallPrime(_ bitLength: Int) -> BigInteger {
        let multiple8 = bitLength & 0x7 == 0
        let length = multiple8 ? (bitLength + 7) >> 3 + 1 : (bitLength + 7) >> 3
        var bytes = Bytes(repeating: 0, count: length)
        let highBit = Byte(1 << ((bitLength + 7) & 0x7))  // High bit of high int
        let highMask = Byte((Int(highBit) << 1) - 1)  // Bits to keep in high int
            
        while true {
            BigInteger.randomBytes(&bytes)
            if multiple8 {
                bytes[0] = 0
                bytes[1] = (bytes[1] & highMask) | highBit
            } else {
                bytes[0] = (bytes[0] & highMask) | highBit
            }
            let x = BigInteger(signed: bytes)
            if bitLength > 6 {
                let r = x % SPP
                if r % 3 == 0 || r % 5 == 0 || r % 7 == 0 || r % 11 == 0 || r % 13 == 0 || r % 17 == 0 ||
                    r % 19 == 0 || r % 23 == 0 || r % 29 == 0 || r % 31 == 0 || r % 37 == 0 || r % 41 == 0 {
                        continue
                }
            }
            if x.isProbablyPrime() {
                return x
            }
        }
    }
    
    static func largePrime(_ bitLength: Int, _ p: Int) -> BigInteger {
        var x = BigInteger(bitWidth: bitLength)
        x.setBit(bitLength - 1)
        x.clearBit(0)
        var bs = BitSieve(x, p)
        var candidate = bs.retrieve()
        while candidate == nil || candidate!.bitWidth != bitLength {
            x += BigInteger(2 * bs.length)
            if x.bitWidth != bitLength {
                x = BigInteger(bitWidth: bitLength)
                x.setBit(bitLength - 1)
            }
            x.clearBit(0)
            bs = BitSieve(x, p)
            candidate = bs.retrieve()
        }
        return candidate!
    }

    /// Checks whether *self* is prime using the Miller-Rabin algorithm
    ///
    /// - Parameter p: If *true* is returned, *self* is prime with probability > 1-1/2^p
    /// - Returns: *true* if *self* is probably prime, *false* if *self* is definitely not prime
    public func isProbablyPrime(_ p: Int = 30) -> Bool {
        if self < 2 {
            return false
        }
        var rounds: Int
        if self.bitWidth < 100 {
            rounds = 50
        } else if self.bitWidth < 256 {
            rounds = 27
        } else if bitWidth < 512 {
            rounds = 15
        } else if bitWidth < 768 {
            rounds = 8
        } else if bitWidth < 1024 {
            rounds = 4
        } else {
            rounds = 2
        }
        rounds = Swift.min((p + 1) / 2, rounds)
        let s1 = self - 1
        for _ in 0 ..< rounds {
            if !self.pass(s1.randomLessThan() + 1) {
                return false
            }
        }
        return true
    }
    
    func pass(_ a: BigInteger) -> Bool {
        let s_1 = self - 1
        let k = s_1.trailingZeroBitCount
        let m = s_1 >> k
        var x = a.expMod(m, self)
        if x == 1 {
            return true
        }
        if k > 0 {
            for _ in 0 ..< k - 1 {
                if x == s_1 {
                    return true
                }
                x = (x * x) % self
            }
        }
        return x == s_1
    }

    /// The next probable prime greater than *self*
    ///
    /// - Parameter p: The returned number is prime with probability > 1-1/2^p, default value is 30
    /// - Returns: The smallest probable prime greater than *self*, returns 2 if *self* is negative
    public func nextPrime(_ p: Int = 30) -> BigInteger {
        if self < BigInteger.TWO {
            return BigInteger.TWO
        }
        var result = self + BigInteger.ONE
        if result.bitWidth < 100 {
            if result.isEven {
                result += BigInteger.ONE
            }
            while true {
                if result.bitWidth > 6 {
                    let r = result % BigInteger.SPP
                    if r % 3 == 0 || r % 5 == 0 || r % 7 == 0 || r % 11 == 0 || r % 13 == 0 || r % 17 == 0 ||
                        r % 19 == 0 || r % 23 == 0 || r % 29 == 0 || r % 31 == 0 || r % 37 == 0 || r % 41 == 0 {
                        result += BigInteger.TWO
                        continue
                    }
                }
                if result.bitWidth < 4 || result.isProbablyPrime(p) {
                    return result
                }
                result += BigInteger.TWO
            }
        }
        if result.isOdd {
            result -= BigInteger.ONE
        }
        while true {
            let sieve = BitSieve(result, p)
            let candidate = sieve.retrieve()
            if candidate != nil {
                return candidate!
            }
            result += 2 * sieve.length
        }
    }

    /// A probable prime number with a given bitwidth
    ///
    /// - Precondition: bitWidth > 1
    /// - Parameters:
    ///   - bitWidth: The bitWidth - must be > 1
    ///   - p: The returned number is prime with probability > 1-1/2^p, default value is 30
    /// - Returns: A prime number with the specified bitwidth and probability
    public static func probablePrime(_ bitWidth: Int, _ p: Int = 30) -> BigInteger {
        precondition(bitWidth > 1, "Bitwidth must be > 1")
        return bitWidth < 100 ? smallPrime(bitWidth) : largePrime(bitWidth, p)
    }

    /// Product of primes up to n
    ///
    /// - Precondition: n >= 0
    /// - Parameters:
    ///   - n: number to compute primorial for
    /// - Returns: The product of primes less than or equal to n
    public static func primorial(_ n: Int) -> BigInteger {
        precondition(n >= 0, "negative primorial")
        var p = BigInteger.ONE
        if n > 0 {
            var sieve = [Bool](repeating: true, count: n + 1)
            sieve[0] = false
            sieve[1] = false
            var ndx = 2
            while ndx < sieve.count {
                if sieve[ndx] {
                    for i in stride(from: ndx + ndx, to: sieve.count, by: ndx) {
                        sieve[i] = false
                    }
                }
                ndx += 1
            }
            for i in 0 ... n {
                if sieve[i] {
                    p *= i
                }
            }
        }
        return p
    }


    // MARK: Root extraction functions

    /*
     * [CRANDALL] - exercise 4.11
     */
    /// n'th root
    ///
    /// - Precondition:
    ///   - *self* is non-negative or *n* is odd
    ///   - n is positive
    /// - Parameter n: The root
    /// - Returns: The integer part of the n'th root of *self*
    public func root(_ n: Int) -> BigInteger {
        precondition(!self.isNegative || n & 1 == 1, "\(n)'th root of negative number")
        precondition(n > 0, "non-positive root")
        if self.isZero {
            return BigInteger.ZERO
        }
        let abs = self.abs
        let bn = BigInteger(n)
        let bn1 = bn - 1
        var x = BigInteger.ONE << (abs.bitWidth / n + 1)
        while true {
            let xx = x ** (n - 1)
            let y = (abs / xx + x * bn1) / bn
            if y >= x {
                return self.isNegative ? -x : x
            }
            x = y
        }
    }

    /// n'th root and remainder
    ///
    /// - Precondition:
    ///   - *self* is non-negative or *n* is odd
    ///   - n is positive
    /// - Parameter n: The root
    /// - Returns: root = the integer part of the n'th root of *self*, rem = *self* - root^n
    public func rootRemainder(_ n: Int) -> (root: BigInteger, rem: BigInteger) {
        let x = self.root(n)
        return (root: x, rem: self - x ** n)
    }

    /// Check whether *self* is a perfect root, that is, for some integer x and n > 1 *self* = x^n
    ///
    /// - Returns: *true* iff *self* is a perfect root
    public func isPerfectRoot() -> Bool {
        if self.abs < BigInteger.TWO {
            return true
        }

        // A number divisible by a prime but not by its square is not a perfect root

        let smallPrimes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
        for i in 0 ..< smallPrimes.count {
            let p = smallPrimes[i]
            if self.mod(p) == 0 && self.mod(p * p) > 0 {
                return false
            }
        }
        if self.isPerfectSquare() {
            return true
        }
        if self.rootRemainder(3).rem.isZero {
            return true
        }
        if self.rootRemainder(5).rem.isZero {
            return true
        }
        let wheel = [ 4, 2, 4, 2, 4, 6, 2, 6 ]
        var wheelIndex = 0
        var n = 7
        while n < self.bitWidth {
            if self.rootRemainder(n).rem.isZero {
                return true
            }
            n += wheel[wheelIndex]
            wheelIndex = (wheelIndex + 1) % wheel.count
        }
        return false
    }

    /*
     * [CRANDALL] - algorithm 9.2.11
     */
    func basicSqrt() -> BigInteger {
        if self.isZero {
            return BigInteger.ZERO
        }
        var x = BigInteger.ONE << (self.bitWidth / 2 + 1)
        while true {
            let y = (self / x + x) >> 1
            if y >= x {
                return x
            }
            x = y
        }
    }

    /// Square root of a non-negative number
    ///
    /// - Precondition: *self* is non-negative
    /// - Returns: The integer part of the square root of *self*
    public func sqrt() -> BigInteger {
        return self.sqrtRemainder().root
    }

    /*
     * [BRENT] - algorithm 1.12
     */
    /// Square root and remainder of a non-negative number
    ///
    /// - Precondition: *self* is non-negative
    /// - Returns: root = the integer part of the square root of *self*, rem = *self* - root^2
    public func sqrtRemainder() -> (root: BigInteger, rem: BigInteger) {
        precondition(!self.isNegative, "Square root of negative number")
        let l = (self.magnitude.count - 1) >> 2
        if l == 0 {
            let sq = self.basicSqrt()
            return (sq, self - sq ** 2)
        }
        let shifts = l * 64
        let a0 = BigInteger(Limbs(self.magnitude[0 ..< l]))
        let a1 = BigInteger(Limbs(self.magnitude[l ..< 2 * l]))
        let a2 = BigInteger(Limbs(self.magnitude[2 * l ..< 3 * l]))
        let a3 = BigInteger(Limbs(self.magnitude[3 * l ..< self.magnitude.count]))
        let (s1, r1) = (a3 << shifts + a2).sqrtRemainder()
        let (q, u) = (r1 << shifts + a1).quotientAndRemainder(dividingBy: s1 << 1)
        var s = s1 << shifts + q
        var r = u << shifts + a0 - q ** 2
        if r.isNegative {
            r += 2 * s - 1
            s -= 1
        }
        return (s, r)
    }

    static let maybeSquare: [Bool] = [
        true, true, false, false, true, false, false, false, false, true, false, false, false, false, false, false,
        true, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, true, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false,
        true, true, false, false, true, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, true, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, true, false, false, false, false, true, false, false, false, false, false, false,
        true, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, true, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, true, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, true, false, false, false, false, true, false, false, false, false, false, false,
        false, true, false, false, false, false, false, false, false, true, false, false, false, false, false, false]
    
    /// Check whether *self* is a perfect square, that is, for some integer x *self* = x^2
    ///
    /// - Returns: *true* iff *self* is a perfect square
    public func isPerfectSquare() -> Bool {
        if self.isNegative {
            return false
        } else {
            return BigInteger.maybeSquare[Int(self.magnitude[0] & 0xff)] ? self.sqrtRemainder().rem.isZero : false
        }
    }

    /*
     * [CRANDALL] - algorithm 2.3.8
     */
    /// Square root modulo a prime number
    ///
    /// - Parameter p: An odd prime number
    /// - Returns: x, such that x^2 mod p = *self*, or *nil* if no such x exists
    public func sqrtMod(_ p: BigInteger) -> BigInteger? {
        if self.jacobiSymbol(p) != 1 {
            return nil
        }
        let A = self % p
        switch p.mod(8) {
        case 3, 7:
            return A.expMod((p + 1) >> 2, p)
        
        case 5:
            var x = A.expMod((p + 3) >> 3, p)
            if (x * x) % p != A % p {
                x = x * BigInteger.TWO.expMod((p - 1) >> 2, p) % p
            }
            return x

        case 1:
            let p_1 = p - 1
            var d = BigInteger.ZERO
            let p_3 = p - 3
            while true {
                d = p_3.randomLessThan() + 2
                if d.jacobiSymbol(p) == -1 {
                    break
                }
            }
            var s = 0
            var t = p_1
            while t.isEven {
                s += 1
                t >>= 1
            }
            let A1 = A.expMod(t, p)
            let D = d.expMod(t, p)
            var m = BigInteger.ZERO
            var exp = BigInteger.ONE << (s - 1)
            for i in 0 ..< s {
                if ((D.expMod(m * exp, p) * A1.expMod(exp, p))).mod(p) == p_1 {
                    m.setBit(i)
                }
                exp >>= 1
            }
            return (A.expMod((t + 1) >> 1, p) * D.expMod(m >> 1, p)) % p

        default:
            return nil
        }
    }


    // MARK: Miscellaneous functions
    
    /// Compute binomial coefficient *n* over *k*
    ///
    /// - Precondition: n >= k and k >= 0
    /// - Parameters:
    ///   - n: First binomial parameter
    ///   - k: Second binomial parameter
    /// - Returns: Binomial coefficient *n* over *k*
    public static func binomial(_ n: Int, _ k: Int) -> BigInteger {
        precondition(n >= k && k >= 0)
        if k == 0 || k == n {
            return BigInteger.ONE
        }
        let k1 = min(k, n - k)
        let n_k1 = Limb(n - k1)
        var c: Limbs = [1]
        for i in 1 ... k1 {
            c.multiply(n_k1 + Limb(i))
            c = c.divMod(Limb(i)).quotient
        }
        return BigInteger(c)
    }

    /// Factorial function
    ///
    /// - Precondition: n >= 0
    /// - Parameter n: Number to compute factorial for
    /// - Returns: n!
    public static func factorial(_ n: Int) -> BigInteger {
        precondition(n >= 0)
        return Factorial(n).result
    }

    /// n'th Fibonacci number
    ///
    /// - Precondition: n >= 0
    /// - Parameter n: The fibonacci index
    /// - Returns: The n'th fibonacci number
    public static func fibonacci(_ n: Int) -> BigInteger {
        return fibonacci2(n).0
    }

    /*
     * Algorithm from Project Nayuki - https://www.nayuki.io/page/fast-fibonacci-algorithms
     * F(2n) = F(n) * (2 * F(n + 1) - F(n))
     * F(2n + 1) = F(n + 1)^2 + F(n)^2
     */
    /// Fibonacci pair, n'th and n'th + 1 Fibonacci number
    ///
    /// Precondition: n >= 0
    /// - Parameter n: The fibonacci index
    /// - Returns: The n'th and n'th + 1 fibonacci number
    public static func fibonacci2(_ n: Int) -> (BigInteger, BigInteger) {
        precondition(n >= 0)
        var a: Limbs = [0]
        var b: Limbs = [1]
        var bit = 1 << (63 - n.leadingZeroBitCount)
        var m = 0
        while bit > 0 {
            var d: Limbs = b.shifted1Left()
            _ = d.subtract(a, 0)
            d.multiply(a)
            var e: Limbs = a
            e.multiply(a)
            var b2 = b
            b2.multiply(b)
            e.add(b2)
            a = d
            b = e
            m <<= 1
            if n & bit != 0 {
                var c: Limbs = a
                c.add(b)
                a = b
                b = c
                m += 1
            }
            bit >>= 1
        }
        return (BigInteger(a), BigInteger(b))
    }

    /*
     * Lehmer's gcd algorithm
     * [KNUTH] - chapter 4.5.2, algorithm L
     */
    // Leave one bit for the sign and one for a possible overflow
    static let B62 = BigInteger.ONE << 62

    /// Greatest common divisor
    ///
    /// - Parameter x: Operand
    /// - Returns: Greatest common divisor of *self* and x
    public func gcd(_ x: BigInteger) -> BigInteger {
        var u: BigInteger
        var v: BigInteger
        let selfabs = self.abs
        let xabs = x.abs
        if selfabs < xabs {
            u = xabs
            v = selfabs
        } else {
            u = selfabs
            v = xabs
        }
        while v >= BigInteger.B62 {
            let size = u.bitWidth - 62
            var x = (u >> size).asInt()!
            var y = (v >> size).asInt()!
            var A = 1
            var B = 0
            var C = 0
            var D = 1
            while true {
                let yC = y + C
                let yD = y + D
                if yC == 0 || yD == 0 {
                    break
                }
                let q = (x + A) / yC
                if q != (x + B) / yD {
                    break
                }
                (A, B, x, C, D, y) = (C, D, y, A - q * C, B - q * D, x - q * y)
            }
            if B == 0 {
                (u, v) = (v, u.mod(v))
            } else {
                (u, v) = (A * u + B * v, C * u + D * v)
            }
        }
        return BigInteger(u.magnitude.gcd(v.magnitude))
     }

    /*
     * [CRANDALL] - algorithm 2.1.4
     */
    /// Extended greatest common divisor
    ///
    /// - Parameter x: Operand
    /// - Returns: Greatest common divisor *g* of *self* and *x*, and *a* and *b* such that *a* * *self* + *b* * *x* = *g*
    public func gcdExtended(_ x: BigInteger) -> (g: BigInteger, a: BigInteger, b: BigInteger) {
        var a = BigInteger.ONE
        var b = BigInteger.ZERO
        var g = self
        var u = BigInteger.ZERO
        var v = BigInteger.ONE
        var w = x
        while w.isNotZero {
            let q = g / w
            (a, b, g, u, v, w) = (u, v, w, a - q * u, b - q * v, g - q * w)
        }
        return g.isNegative ? (-g, -a, -b) : (g, a, b)
    }

    /*
     * [CRANDALL] - algorithm 2.3.5
     */
    /// Jacobi symbol - BigInteger parameter. If m is an odd prime, this is also the Legendre symbol
    ///
    /// - Precondition: m is positive and odd
    /// - Parameters:
    ///   - m: A positive, odd integer
    /// - Returns: The Jacobi symbol of *self* and m: -1, 0, or 1
    public func jacobiSymbol(_ m: BigInteger) -> Int {
        precondition(m.isPositive && m.isOdd)
        var m1 = m
        var a = self.mod(m1)
        var t = 1
        while a.isNotZero {
            while a.isEven {
                a >>= 1
                let x = m1.magnitude[0] & 7
                if x == 3 || x == 5 {
                    t = -t
                }
            }
            let x = a
            a = m1
            m1 = x
            if a.magnitude[0] & 3 == 3 && m1.magnitude[0] & 3 == 3 {
                t = -t
            }
            a = a.mod(m1)
        }
        return m1.isOne ? t : 0
    }

    /// Jacobi symbol - Int parameter. If m is an odd prime, this is also the Legendre symbol
    ///
    /// - Precondition: m is positive and odd
    /// - Parameters:
    ///   - m: A positive, odd integer
    /// - Returns: The Jacobi symbol of *self* and m: -1, 0, or 1
    public func jacobiSymbol(_ m: Int) -> Int {
        precondition(m > 0 && m & 1 == 1)
        var m1 = m
        var a = self.mod(m1)
        var t = 1
        while a != 0 {
            while a & 1 == 0 {
                a >>= 1
                let x = m1 & 7
                if x == 3 || x == 5 {
                    t = -t
                }
            }
            let x = a
            a = m1
            m1 = x
            if a & 3 == 3 && m1 & 3 == 3 {
                t = -t
            }
            a %= m1
        }
        return m1 == 1 ? t : 0
    }

    /// Kronecker symbol - BigInteger parameter. If m is positive and odd, this is also the Jacobi symbol
    ///
    /// - Parameters:
    ///   - m: An integer value
    /// - Returns: The Kronecker symbol of *self* and m: -1, 0, or 1
    public func kroneckerSymbol(_ m: BigInteger) -> Int {
        if m.isPositive {
            if m.isOdd {
                return self.jacobiSymbol(m)
            } else {
                if self.isEven {
                    return 0
                } else {
                    let r = self.magnitude[0] & 7
                    return r == 1 || r == 7 ? self.kroneckerSymbol(m >> 1) : -self.kroneckerSymbol(m >> 1)
                }
            }
        } else if m.isNegative {
            return self.isNegative ? -self.kroneckerSymbol(-m) : self.kroneckerSymbol(-m)
        } else {
            return self.abs.isOne ? 1 : 0
        }
    }

    /// Kronecker symbol - Int parameter. If m is positive and odd, this is also the Jacobi symbol
    ///
    /// - Parameters:
    ///   - m: An integer value
    /// - Returns: The Kronecker symbol of *self* and m: -1, 0, or 1
    public func kroneckerSymbol(_ m: Int) -> Int {
        if m > 0 {
            if m & 1 == 1 {
                return self.jacobiSymbol(m)
            } else {
                if self.isEven {
                    return 0
                } else {
                    let r = self.magnitude[0] & 7
                    return r == 1 || r == 7 ? self.kroneckerSymbol(m >> 1) : -self.kroneckerSymbol(m >> 1)
                }
            }
        } else if m < 0 {
            return self.isNegative ? -self.kroneckerSymbol(-m) : self.kroneckerSymbol(-m)
        } else {
            return self.abs.isOne ? 1 : 0
        }
    }

    /// Least common multiple
    ///
    /// - Parameter x: Operand
    /// - Returns: Least common multiple of *self* and *x* - a non-negative number
    public func lcm(_ x: BigInteger) -> BigInteger {
        return self.isZero || x.isZero ? BigInteger.ZERO : (self * x).abs.quotientExact(dividingBy: self.gcd(x))
    }

    /// n'th Lucas number
    ///
    /// - Precondition: n >= 0
    /// - Parameter n: The lucas index
    /// - Returns: The n'th lucas number
    public static func lucas(_ n: Int) -> BigInteger {
        let f2 = fibonacci2(n)
        return 2 * f2.1 - f2.0
    }

    /// Lucas pair, n'th and n'th + 1 Lucas number
    ///
    /// Precondition: n >= 0
    /// - Parameter n: The lucas index
    /// - Returns: The n'th and n'th + 1 lucas number
    public static func lucas2(_ n: Int) -> (BigInteger, BigInteger) {
        let f2 = fibonacci2(n)
        return (2 * f2.1 - f2.0, f2.1 + 2 * f2.0)
    }

    /// Random value
    ///
    /// - Precondition: *self* is positive
    /// - Returns: A random value < absolute value of *self*
    public func randomLessThan() -> BigInteger {
        precondition(self.isPositive, "Must be positive")
        var x: BigInteger
        repeat {
            x = BigInteger(bitWidth: self.bitWidth)
        } while x >= self
        return x
    }

}
