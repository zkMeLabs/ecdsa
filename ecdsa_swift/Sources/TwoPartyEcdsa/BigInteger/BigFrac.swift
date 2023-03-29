//
//  BigFrac.swift
//  BigInt
//
//  Created by Leif Ibsen on 26/06/2022.
//

/// A signed fraction with numerator and denominator of unbounded size.
/// A BFraction value is represented by a BigInteger numerator and a BigInteger denominator.
/// The representation is normalized, so that numerator and denominator has no common divisors except 1.
/// The denominator is always positive, 0 has the representation 0/1
public struct BFraction: CustomStringConvertible, Comparable, Equatable {
    
    mutating func normalize() {
        let g = self.numerator.gcd(self.denominator)
        if g.magnitude.compare(1) > 0 {
            self.numerator = self.numerator.quotientExact(dividingBy: g)
            self.denominator = self.denominator.quotientExact(dividingBy: g)
        }
        if self.denominator.isNegative {
            self.denominator = -self.denominator
            self.numerator = -self.numerator
        }
    }


    // MARK: - Constants

    /// BFraction(0, 1)
    public static let ZERO = BFraction(BigInteger.ZERO, BigInteger.ONE)
    /// BFraction(1, 1)
    public static let ONE = BFraction(BigInteger.ONE, BigInteger.ONE)

    
    // MARK: Initializers

    /// Constructs a BFraction from numerator and denominator
    ///
    /// - Precondition: Denominator is not zero
    /// - Parameters:
    ///   - n: The numerator
    ///   - d: The denominator
    public init(_ n: BigInteger, _ d: BigInteger) {
        precondition(d.isNotZero)
        self.numerator = n
        self.denominator = d
        self.normalize()
    }

    /// Constructs a BFraction from numerator and denominator
    ///
    /// - Precondition: Denominator is not zero
    /// - Parameters:
    ///   - n: The numerator
    ///   - d: The denominator
    public init(_ n: BigInteger, _ d: Int) {
        self.init(n, BigInteger(d))
    }

    /// Constructs a BFraction from numerator and denominator
    ///
    /// - Precondition: Denominator is not zero
    /// - Parameters:
    ///   - n: The numerator
    ///   - d: The denominator
    public init(_ n: Int, _ d: BigInteger) {
        self.init(BigInteger(n), d)
    }

    /// Constructs a BFraction from numerator and denominator
    ///
    /// - Precondition: Denominator is not zero
    /// - Parameters:
    ///   - n: The numerator
    ///   - d: The denominator
    public init(_ n: Int, _ d: Int) {
        self.init(BigInteger(n), BigInteger(d))
    }

    /// Constructs a BFraction from its decimal value
    ///
    /// - Parameters:
    ///   - d: The decimal value
    /// - Returns: The BFraction corresponding to *d*, *nil* if *d* is infinite or NaN
    public init?(_ d: Double) {
        if d.isNaN || d.isInfinite {
            return nil
        }
        let bits = d.bitPattern
        let sign = bits >> 63 == 0 ? 1 : -1
        let exponent = Int(bits >> 52) & 0x7ff - 1075
        let significand = exponent == -1075 ? Int(bits & 0xfffffffffffff) << 1 : Int(bits & 0xfffffffffffff) | (1 << 52)
        if exponent < 0 {
            self.init(sign * BigInteger(significand), BigInteger.ONE << -exponent)
        } else {
            self.init(sign * BigInteger(significand) * (BigInteger.ONE << exponent), BigInteger.ONE)
        }
    }


    // MARK: Stored properties
    
    /// The numerator - a BigInteger value
    public internal(set) var numerator: BigInteger
    /// The denominator - a positive BigInteger value
    public internal(set) var denominator: BigInteger


    // MARK: Computed properties

    /// The absolute value of *self*
    public var abs: BFraction {
        return BFraction(self.numerator.abs, self.denominator)
    }

    /// String value of *self*
    public var description: String {
        return self.asString()
    }

    /// Is *true* if *self* is an integer, that is, the denominator is 1
    public var isInteger: Bool {
        return self.denominator.isOne
    }

    /// Is *true* if *self* < 0, *false* otherwise
    public var isNegative: Bool {
        return self.numerator.isNegative
    }

    /// Is *true* if *self* > 0, *false* otherwise
    public var isPositive: Bool {
        return self.numerator.isPositive
    }

    /// Is *true* if *self* = 0, *false* otherwise
    public var isZero: Bool {
        return self.numerator.isZero
    }

    /// Is 0 if *self* = 0, 1 if *self* > 0, and -1 if *self* < 0
    public var signum: Int {
        return self.numerator.signum
    }


    // MARK: Conversion functions to String, Decimal String and Double

    /// *self* as a String</br>
    /// Examples: BFraction(-97, 100).asString() is "-97 / 100"</br>
    ///
    /// - Returns: *self* as a String
    public func asString() -> String {
        return self.numerator.asString() + " / " + self.denominator.asString()
    }

    /// *self* as a Decimal String with a given number of digits</br>
    /// Examples: BFraction(-97, 100).asDecimalString(digits: 3) is "-0.970"</br>
    /// BFraction(-97, 100).asDecimalString(digits: 0) is "0"
    ///
    /// - Precondition: digits >= 0
    /// - Parameters:
    ///   - digits: Number of digits after the decimal point
    /// - Returns: *self* as a decimal String
    public func asDecimalString(digits: Int) -> String {
        precondition(digits >= 0)
        var (q, r) = self.abs.numerator.quotientAndRemainder(dividingBy: self.denominator)
        var s = self.isNegative && (q > 0 || digits > 0) ? "-" : ""
        s += q.asString()
        if digits > 0 {
            s += "."
            for _ in 0 ..< digits {
                r *= BigInteger.TEN
                let q1 = r.quotientAndRemainder(dividingBy: self.denominator).quotient
                r -= q1 * self.denominator
                s += q1.asString()
            }
        }
        return s
    }

    /// *self* as a Double
    ///
    /// - Returns: *self* as a Double or *Infinity* if *self* is not representable as a Double
    public func asDouble() -> Double {
        var (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
        var d = q.asDouble()
        if !d.isInfinite {
            var pow10 = 1.0
            for _ in 0 ..< 18 {
                r *= 10
                pow10 *= 10.0
                (q, r) = r.quotientAndRemainder(dividingBy: self.denominator)
                d += q.asDouble() / pow10
            }
        }
        return d
    }


    // MARK: Addition functions
    
    /// Prefix plus
    ///
    /// - Parameter x: BFraction value
    /// - Returns: x
    public prefix static func +(x: BFraction) -> BFraction {
        return x
    }
    
    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: x + y
    public static func +(x: BFraction, y: BFraction) -> BFraction {
        if x.denominator == y.denominator {
            return BFraction(x.numerator + y.numerator, x.denominator)
        } else {
            return BFraction(x.numerator * y.denominator + y.numerator * x.denominator, x.denominator * y.denominator)
        }
    }

    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: x + y
    public static func +(x: BFraction, y: BigInteger) -> BFraction {
        return x + BFraction(y, BigInteger.ONE)
    }

    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: x + y
    public static func +(x: BigInteger, y: BFraction) -> BFraction {
        return BFraction(x, BigInteger.ONE) + y
    }
    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: x + y
    public static func +(x: BFraction, y: Int) -> BFraction {
        return x + BFraction(y, BigInteger.ONE)
    }

    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: x + y
    public static func +(x: Int, y: BFraction) -> BFraction {
        return BFraction(x, BigInteger.ONE) + y
    }

    /// x = x + y
    ///
    /// - Parameters:
    ///   - x: Left hand addend
    ///   - y: Right hand addend
    public static func +=(x: inout BFraction, y: BFraction) {
        x = x + y
    }
    
    /// x = x + y
    ///
    /// - Parameters:
    ///   - x: Left hand addend
    ///   - y: Right hand addend
    public static func +=(x: inout BFraction, y: BigInteger) {
        x = x + y
    }
    
    /// x = x + y
    ///
    /// - Parameters:
    ///   - x: Left hand addend
    ///   - y: Right hand addend
    public static func +=(x: inout BFraction, y: Int) {
        x = x + y
    }


    // MARK: Subtraction functions
    
    /// Negation
    ///
    /// - Parameter x: Operand
    /// - Returns: -x
    public prefix static func -(x: BFraction) -> BFraction {
        return BFraction(-x.numerator, x.denominator)
    }
    
    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: x - y
    public static func -(x: BFraction, y: BFraction) -> BFraction {
        if x.denominator == y.denominator {
            return BFraction(x.numerator - y.numerator, x.denominator)
        } else {
            return BFraction(x.numerator * y.denominator - y.numerator * x.denominator, x.denominator * y.denominator)
        }
    }
    
    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: x - y
    public static func -(x: BFraction, y: BigInteger) -> BFraction {
        return x - BFraction(y, BigInteger.ONE)
    }

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: x - y
    public static func -(x: BigInteger, y: BFraction) -> BFraction {
        return BFraction(x, BigInteger.ONE) - y
    }

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: x - y
    public static func -(x: BFraction, y: Int) -> BFraction {
        return x - BFraction(y, BigInteger.ONE)
    }

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: x - y
    public static func -(x: Int, y: BFraction) -> BFraction {
        return BFraction(x, BigInteger.ONE) - y
    }

    /// x = x - y
    ///
    /// - Parameters:
    ///   - x: Left hand minuend
    ///   - y: Right hand subtrahend
    public static func -=(x: inout BFraction, y: BFraction) {
        x = x - y
    }

    /// x = x - y
    ///
    /// - Parameters:
    ///   - x: Left hand minuend
    ///   - y: Right hand subtrahend
    public static func -=(x: inout BFraction, y: BigInteger) {
        x = x - y
    }

    /// x = x - y
    ///
    /// - Parameters:
    ///   - x: Left hand minuend
    ///   - y: Right hand subtrahend
    public static func -=(x: inout BFraction, y: Int) {
        x = x - y
    }


    // MARK: Multiplication functions
    
    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: x * y
    public static func *(x: BFraction, y: BFraction) -> BFraction {
        return BFraction(x.numerator * y.numerator, x.denominator * y.denominator)
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: x * y
    public static func *(x: BFraction, y: BigInteger) -> BFraction {
        return BFraction(x.numerator * y, x.denominator)
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: x * y
    public static func *(x: BigInteger, y: BFraction) -> BFraction {
        return BFraction(x * y.numerator, y.denominator)
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: x * y
    public static func *(x: BFraction, y: Int) -> BFraction {
        return BFraction(x.numerator * y, x.denominator)
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: x * y
    public static func *(x: Int, y: BFraction) -> BFraction {
        return BFraction(x * y.numerator, y.denominator)
    }

    /// x = x * y
    ///
    /// - Parameters:
    ///   - x: Left hand multiplier
    ///   - y: Right hand multiplicand
    public static func *=(x: inout BFraction, y: BFraction) {
        x = x * y
    }

    /// x = x * y
    ///
    /// - Parameters:
    ///   - x: Left hand multiplier
    ///   - y: Right hand multiplicand
    public static func *=(x: inout BFraction, y: BigInteger) {
        x = x * y
    }

    /// x = x * y
    ///
    /// - Parameters:
    ///   - x: Left hand multiplier
    ///   - y: Right hand multiplicand
    public static func *=(x: inout BFraction, y: Int) {
        x = x * y
    }


    // MARK: Division functions

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x / y
    public static func /(x: BFraction, y: BFraction) -> BFraction {
        return BFraction(x.numerator * y.denominator, x.denominator * y.numerator)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x / y
    public static func /(x: BFraction, y: BigInteger) -> BFraction {
        return BFraction(x.numerator, x.denominator * y)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x / y
    public static func /(x: BigInteger, y: BFraction) -> BFraction {
        return BFraction(x * y.denominator, y.numerator)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x / y
    public static func /(x: BFraction, y: Int) -> BFraction {
        return BFraction(x.numerator, x.denominator * y)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: x / y
    public static func /(x: Int, y: BFraction) -> BFraction {
        return BFraction(x * y.denominator, y.numerator)
    }

    /// x = x / y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Left hand dividend
    ///   - y: Right hand divisor
    public static func /=(x: inout BFraction, y: BFraction) {
        x = x / y
    }
    
    /// x = x / y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Left hand dividend
    ///   - y: Right hand divisor
    public static func /=(x: inout BFraction, y: BigInteger) {
        x = x / y
    }
    
    /// x = x / y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Left hand dividend
    ///   - y: Right hand divisor
    public static func /=(x: inout BFraction, y: Int) {
        x = x / y
    }

    /// Invert *self*
    ///
    /// - Precondition: *self* is not zero
    /// - Returns: 1 / *self*
    public func invert() -> BFraction  {
        return BFraction(self.denominator, self.numerator)
    }

    
    // MARK: Exponentiation functions

    /// Exponentiation
    ///
    /// - Parameters:
    ///   - a: Operand
    ///   - x: Exponent
    /// - Returns: a^x
    public static func **(a: BFraction, x: Int) -> BFraction {
        if x > 0 {
            return BFraction(a.numerator ** x, a.denominator ** x)
        } else if x < 0 {
            if x == Int.min {
                return BFraction(a.denominator * (a.denominator ** Int.max), a.numerator * (a.numerator ** Int.max))
            } else {
                return BFraction(a.denominator ** -x, a.numerator ** -x)
            }
        } else {
            return BFraction.ONE
        }
    }

    
    // MARK: Rounding functions
    
    /// Round
    ///
    /// Returns: *self* rounded to the nearest integer
    public func round() -> BigInteger {
        let (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
        if r.isNegative {
            return -r * 2 >= self.denominator ? q - 1 : q
        } else {
            return r * 2 >= self.denominator ? q + 1 : q
        }
    }

    /// Truncate
    ///
    /// Returns: *self* rounded to an integer towards 0
    public func truncate() -> BigInteger {
        return self.isPositive ? self.floor() : self.ceil()
    }

    /// Ceil
    ///
    /// Returns: *self* rounded to an integer towards +Infinity
    public func ceil() -> BigInteger {
        let (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
        return r.isPositive ? q + 1 : q
    }

    /// Floor
    ///
    /// Returns: *self* rounded to an integer towards -Infinity
    public func floor() -> BigInteger {
        let (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
        return r.isNegative ? q - 1 : q
    }


    // MARK: Comparison functions
    
    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x = y, *false* otherwise
    public static func ==(x: BFraction, y: BFraction) -> Bool {
        return x.numerator == y.numerator && x.denominator == y.denominator
    }

    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x = y, *false* otherwise
    public static func ==(x: BFraction, y: BigInteger) -> Bool {
        return x.numerator == y && x.denominator.isOne
    }

    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x = y, *false* otherwise
    public static func ==(x: BigInteger, y: BFraction) -> Bool {
        return x == y.numerator && y.denominator.isOne
    }

    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x = y, *false* otherwise
    public static func ==(x: BFraction, y: Int) -> Bool {
        return x.numerator == y && x.denominator.isOne
    }

    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x = y, *false* otherwise
    public static func ==(x: Int, y: BFraction) -> Bool {
        return x == y.numerator && y.denominator.isOne
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x != y, *false* otherwise
    public static func !=(x: BFraction, y: BFraction) -> Bool {
        return x.numerator != y.numerator || x.denominator != y.denominator
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x != y, *false* otherwise
    public static func !=(x: BFraction, y: BigInteger) -> Bool {
        return x != BFraction(y, BigInteger.ONE)
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x != y, *false* otherwise
    public static func !=(x: BigInteger, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) != y
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x != y, *false* otherwise
    public static func !=(x: BFraction, y: Int) -> Bool {
        return x != BFraction(y, BigInteger.ONE)
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x != y, *false* otherwise
    public static func !=(x: Int, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) != y
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x < y, *false* otherwise
    public static func <(x: BFraction, y: BFraction) -> Bool {
        return x.numerator * y.denominator < y.numerator * x.denominator
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x < y, *false* otherwise
    public static func <(x: BFraction, y: BigInteger) -> Bool {
        return x < BFraction(y, BigInteger.ONE)
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x < y, *false* otherwise
    public static func <(x: BigInteger, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) < y
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x < y, *false* otherwise
    public static func <(x: BFraction, y: Int) -> Bool {
        return x < BFraction(y, BigInteger.ONE)
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x < y, *false* otherwise
    public static func <(x: Int, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) < y
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x > y, *false* otherwise
    public static func >(x: BFraction, y: BFraction) -> Bool {
        return x.numerator * y.denominator > y.numerator * x.denominator
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x > y, *false* otherwise
    public static func >(x: BFraction, y: BigInteger) -> Bool {
        return x > BFraction(y, BigInteger.ONE)
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x > y, *false* otherwise
    public static func >(x: BigInteger, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) > y
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x > y, *false* otherwise
    public static func >(x: BFraction, y: Int) -> Bool {
        return x > BFraction(y, BigInteger.ONE)
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x > y, *false* otherwise
    public static func >(x: Int, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) > y
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x <= y, *false* otherwise
    public static func <=(x: BFraction, y: BFraction) -> Bool {
        return !(x > y)
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x <= y, *false* otherwise
    public static func <=(x: BFraction, y: BigInteger) -> Bool {
        return x <= BFraction(y, BigInteger.ONE)
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x <= y, *false* otherwise
    public static func <=(x: BigInteger, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) <= y
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x <= y, *false* otherwise
    public static func <=(x: BFraction, y: Int) -> Bool {
        return x <= BFraction(y, BigInteger.ONE)
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x <= y, *false* otherwise
    public static func <=(x: Int, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) <= y
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x >= y, *false* otherwise
    public static func >=(x: BFraction, y: BFraction) -> Bool {
        return !(x < y)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x >= y, *false* otherwise
    public static func >=(x: BFraction, y: BigInteger) -> Bool {
        return x >= BFraction(y, BigInteger.ONE)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x >= y, *false* otherwise
    public static func >=(x: BigInteger, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) >= y
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x >= y, *false* otherwise
    public static func >=(x: BFraction, y: Int) -> Bool {
        return x >= BFraction(y, BigInteger.ONE)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: *true* if x >= y, *false* otherwise
    public static func >=(x: Int, y: BFraction) -> Bool {
        return BFraction(x, BigInteger.ONE) >= y
    }

}
