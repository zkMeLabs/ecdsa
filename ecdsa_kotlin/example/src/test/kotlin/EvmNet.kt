enum class Net(val rpcUrl: String, val scanUrl: String, val chainId: Long) {
    goerliTest(
        "https://goerli.infura.io/v3/bef864a7a71a4f6d91f9dc08614306a5",
        "https://goerli.etherscan.io",
        5,
    ),
    bscTest(
        "https://data-seed-prebsc-1-s1.binance.org:8545",
        "https://testnet.bscscan.com",
        97,
    ),
    polygonTest(
        "https://rpc-mumbai.matic.today",
        "https://mumbai.polygonscan.com",
        80001,
    ),
}
