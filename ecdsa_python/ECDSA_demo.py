# This is a two-sided ECDSA example
# Curves (P-256 P-384 P-521 Ed25519 Ed448) integrated in Crypto.PublicKey.ECC library are available
# Since the Crypto.PublicKey.ECC library is not yet integrated with the [ethereum secp256k1 curve], 
#       this example first uses other curves instead
# Note：Order of secp256k1：0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
#       Limited range：0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F

# Note: Numerical additions are denoted as `+` and numerical multiplications are denoted as `*`
#    The points on the elliptic curve plus are denoted as `⨁`,the multiplier points are denoted as `⊗`
#    The ciphertext addition on the homomorphism is noted as `⊞` (the addition can be plaintext, 
#    which can be a ciphertext encrypted with the same homomorphic public key),
#    and the multiplication is noted as `⊠` (the multiplication can only be plaintext)
from Crypto.PublicKey import ECC
from Crypto.Random import random
from Crypto.Hash import keccak # Hash algorithm in ethereum: keccak256
from Crypto.Util.number import bytes_to_long
from Crypto.Util.number import long_to_bytes
from gmpy2 import invert # Import the function to find the inverse element over a finite field
from phe import paillier # Import Partially Homomorphic Encryption using the Paillier library
_COMMITMENT_RANDOM_BITS = 256

# Avaliable curves：P-256 P-384 P-521 Ed25519 Ed448
ec = 'P-256'
# p - order of the curve
p = int(ECC._curves[ec].order)
# P - original point on the curve
P = ECC.EccPoint(x=ECC._curves[ec].Gx, y=ECC._curves[ec].Gy, curve=ec)

# --- ↓↓↓ Signing public key, signing private key negotiation process start ↓↓↓ --- 
# x: int - signature private key
#    Since it is a two-party distribution, P1 P2 each holds half of the signed private key x: x_1 x_2. 
#    Here x = x_1 * x_2
# Note：Not the same as the private key x = x_1 + x_2 for EC-ElGamal threshold encryption
# h: ECC.EccPoint - signature public key
#    h = x ⊗ P = (x_1 * x_2) ⊗ P = x_2 ⊗ h_1 = x_1 ⊗ h_2
# Note：Not the same as the public key h = (x_1 + x_2) ⊗ P = h_1⨁ h_2 for EC-ElGamal threshold encryption

# Since x_1 needs to be encrypted by ppk later to generate the proof, it has to satisfy q//3 < x_1 < 2q//3
# x_1: int - P1 prviate key share
x_1:int = random.randint(p//3, (2*p)//3)
# h_1: ECC.EccPoint - P1 public key share
h_1:ECC.EccPoint = x_1 * P

# x_2: int - P2 private key share
x_2:int = random.randint(0, p)
# h_2: ECC.EccPoint - P2 public key share
h_2:ECC.EccPoint = x_2 * P

# --- ↓↓↓ commitment start ↓↓↓ ---
# --- Calculate commitment: bytes ---
def compute_commitment(commitment_random: bytes, h_i: ECC.EccPoint):
        hash_fct = keccak.new(digest_bits=256)
        hash_fct.update(commitment_random)
        hash_fct.update(long_to_bytes(int(h_i.x)))
        hash_fct.update(long_to_bytes(int(h_i.y)))
        return hash_fct.digest()
    
commitment_about_h_1_r: bytes = long_to_bytes(random.getrandbits(_COMMITMENT_RANDOM_BITS))
commitment_about_h_1:bytes = compute_commitment(commitment_about_h_1_r, h_1)

commitment_about_h_2_r: bytes = long_to_bytes(random.getrandbits(_COMMITMENT_RANDOM_BITS))
commitment_about_h_2: bytes = compute_commitment(commitment_about_h_2_r, h_2)

print('The commitment of h_1 sent by P1 to P2 is：', commitment_about_h_1)
print('The commitment of h_1 sent by P2 to P1 is：', commitment_about_h_2)

# --- Users add their own commitment and each other's commitment --- 
commitment = {}
commitment[1] = commitment_about_h_1
commitment[2] = commitment_about_h_2
if len(commitment) == 2:
	print('Both sides have collected enough 2 commits')

# --- The user exposes the parameters of the commitment, that is, the original image: h_i, commitment_random ---
print('The x,y coordinates of P1 sending his public key share to P2 are{}, the random number in commitment is{}：'.format(h_1.xy, commitment_about_h_1_r))
print('The x,y coordinates of P2 sending his public key share to P1 are{}, the random number in commitment is{}：'.format(h_2.xy, commitment_about_h_2_r))

#Check if the original image from the other side is correct
assert compute_commitment(commitment_about_h_1_r, h_1) == commitment[1]
assert compute_commitment(commitment_about_h_2_r, h_2) == commitment[2]
# --- ↑↑↑ commitment end ↑↑↑ ---

# Both parties calculate the signature public key
h_computed_by_1 = h_2 * x_1
print('P1 locally computes the x,y coordinates of the signed public key as:', h_computed_by_1.xy)
h_computed_by_2 = h_1 * x_2
print('P2 locally computes the x,y coordinates of the signed public key as:', h_computed_by_2.xy)
assert h_computed_by_1.xy == h_computed_by_2.xy
print('Are the signed public keys h calculated by both parties the same?,',h_computed_by_1.xy == h_computed_by_2.xy)
h = h_computed_by_1
# --- ↑↑↑ Signing public key, signing private key negotiation process end ↑↑↑ --- 


# Note：Omits the part about zk for public key negotiation
# P1 generates ZKproof with respect to the discrete logarithm of own holdings h_1 (i.e. own holdings x_1 and h_1 = x_1 ⊗ P)
# P2 generates ZKproof with respect to the discrete logarithm of own holding h_2 (i.e., own holding x_2 and h_2 = x_2 ⊗ P)
# P1 generates the homomorphic key pair (ppk,psk), where ppk is to be sent to P2
ppk, psk = paillier.generate_paillier_keypair(n_length=2048)
print('P1 sends a homomorphic public key to P2 is：', ppk)
# P1 encrypts his private key share with homomorphic public key ppk and sends it to P2
# Note: The part about the homomorphic public key zk is omitted. It is suggested to let the platform as P1
# P1 generates ZKproof with respect to the discrete logarithm of own holding x_1 (i.e., own holding x_1 and h_1 = x_1 ⊗ P)
c_key = ppk.encrypt(x_1)
print('P1 sends the ciphertext of ppk encryption x_1 to P2：', c_key)
#ppk.g, ppk.n
#print(c_key.ciphertext())


# ---↓↓↓ The first step of signing process (R:int) ↓↓↓--- 

# Generate a random number k, multiply the points and calculate the point Q: ECC.EccPoint
# Ensure that the x-coordinate of Q mod p is not 0
# The result of modulo division is denoted as R


k_1:int = 0
k_2:int = 0
R:int = 0
# Until the parties negotiate a situation where R is not 0
while R==0:
    # k: int is the number of multipliers to generate Q. Since this is a two-party distribution, P1 and P2 each hold half of the signature private key k: k_1 k_2. Here k = k_1 * k_2
    # Q:ECC.EccPoint for a negotiated point, Q = k ⊗ P = (k_1 * k_2) ⊗ P = k_2 ⊗ Q_1 = k_1 ⊗ Q_2
    # P1 generates the random number k_1, multiplies the point operation and calculates the point Q_1:ECC.EccPoint
    k_1 = random.randint(0, p)
    Q_1 = k_1 * P
    # P2 generates a random number k_2 and multiplies it to calculate the point Q_2:ECC.EccPoint
    k_2 = random.randint(0, p)
    Q_2 = k_2 * P
    # ---↓↓↓ P1 P2 calculates the commitment: bytes on k ↓↓↓--- 
        
    commitment_about_Q_1_r: bytes = long_to_bytes(random.getrandbits(_COMMITMENT_RANDOM_BITS))
    commitment_about_Q_1:bytes = compute_commitment(commitment_about_Q_1_r, Q_1)

    commitment_about_Q_2_r: bytes = long_to_bytes(random.getrandbits(_COMMITMENT_RANDOM_BITS))
    commitment_about_Q_2: bytes = compute_commitment(commitment_about_Q_2_r, Q_2)

    print('The commitment of user 1 regarding Q_1 is：', commitment_about_Q_1)
    print('The commitment of user 2 regarding Q_2 is：', commitment_about_Q_2)

    # --- Users add their own commit_Q and each other's commit_Q ---
    commitment_Q = {}
    commitment_Q[1] = commitment_about_Q_1
    commitment_Q[2] = commitment_about_Q_2
    if len(commitment_Q) == 2:
        print('Enough commits have been collected for 2 commit_Q')

    # --- The user exposes the parameters about commitment_Q, that is, the original image ---
    # _h_i, _commitment_random,
    print('The x,y coordinates of Q_share of user 1 are{}, the random number in commitment_Q_1 is{}：'.format(Q_1.xy, commitment_about_Q_1_r))
    print('The x,y coordinates of Q_share of user 2 are{}, the random number in commitment_Q_2 is{}：'.format(Q_2.xy, commitment_about_Q_2_r))

    #Check if the original image from the other side is correct
    assert compute_commitment(commitment_about_Q_1_r, Q_1) == commitment_Q[1]
    assert compute_commitment(commitment_about_Q_2_r, Q_2) == commitment_Q[2]
    #---↑↑↑ commitment end ↑↑↑--- 

    # P1 Check the horizontal coordinates of Q to ensure that Q.x mod p ! = 0
    Q_P1 = k_1 * Q_2
    R_1 = Q_P1.x % p
    # P2 Check the horizontal coordinates of Q to ensure that Q.x mod p ! = 0
    Q_P2 = k_2 * Q_1
    R_2 = Q_P2.x % p
    # Make sure that the two parties calculate the same R
    if R_1 == R_2 and R_1 % p != 0:   
        print('P1 P2 verify that R is legitimate')
        R = int(R_1)
# ---↑↑↑ The first step of signing process (R:int) end ↑↑↑---

# ---↓↓↓ The second step of signing process (S:int) ↓↓↓---
# Calculate message digest with keccak
def _keccak(m_bytes: bytes) -> bytes:
    keccak_hash = keccak.new(digest_bits=256)
    hash_bytes = keccak_hash.update(m_bytes).digest()
    return hash_bytes

# P_2 has the message message, the homomorphic public key ppk, and the ciphertext c_key obtained by ppk-encrypted x1
# and R，x2，k2
# P_2 calculates the message digest. The integer value z:int of the message digest needs to be within EC order
message = 'Some secret message to be encrypted!'
encoded_message = bytes(message, 'utf-8')
hash_bytes = _keccak(encoded_message)
z:int = bytes_to_long(hash_bytes)
assert z < p

# P2 randomly selects a value ρ between [0,p**2]
pho:int = random.randint(0, p**2)

# P2 calculates the inverse of k_2 on p
k_2_inv:int = invert(k_2,p)

# Calculate tmp = ρ*p + ((inv(k_2) * z) %p)
tmp:int = int(pho*p + (k_2_inv*z %p))
# Calculate c_1:EncryptedNumber, it is the result of tmp encrypted under Paillier
c_1 = ppk.encrypt(tmp)
# Calculate v = (inv(k_2) * R * x2) %p
v = (k_2_inv * R * x_2) % p
# Calculate c_2:encryption number = v ⊠ c_key
c_2 = int(v) * c_key 
# Calculate c_3:encryption number = c_1 ⊞ c_2
c_3 = c_1 + c_2 

# P2 sends c_3 to P1
print('P2 sends ciphertext c_3 to P1：', c_3)


# P1 decrypts c_3 with the homomorphic public key ssk to obtain S' (denoted as S_)
S_:int = psk.decrypt(c_3)
# P1 calculates the inverse of k_1
k_1_inv = invert(k_1,p)
# Compute S'' = inverse of k_1 * S' mod p
S__ = k_1_inv * S_ % p
# S is the smaller of (S'', p-S'')
S = min(S__, p-S__)
# P1 needs to send S to P2 and let P2 also verify (R,S)
print('P1 sends S to P2：',S)
# ---↑↑↑ The second step of signing process (S:int) end ↑↑↑---

# ---↓↓↓ Verifying signatures ↓↓↓--- 
# P1 P2 need to verify (R,S) legitimacy: known public key h, message message, and signature (R,S), curve order p, curve base point P
assert R < p 
assert S < p 
# Calculating the inverse of S, which will be used in a moment
S_inv:int = invert(S,p)

message = 'Some secret message to be encrypted!'
encoded_message = bytes(message, 'utf-8')
hash_bytes = _keccak(encoded_message)
z:int = bytes_to_long(hash_bytes)
assert z < p
# P1 P2 calculation
u1:int = z*S_inv % p
u2:int = R*S_inv % p
# P1 P2 calculation Q' = (u1⊗P) ⨁ (u2⊗P)
Q_:ECC.EccPoint = u1*P + u2*h

# If Q' and Q are the same point, the signature check is successful. Here we only need to compare whether the horizontal coordinates of the two points are the same.
print('The verification of the signature:', (Q_.x) % p == R)
print('The signature tuple is：({},{})'.format(R,S))



