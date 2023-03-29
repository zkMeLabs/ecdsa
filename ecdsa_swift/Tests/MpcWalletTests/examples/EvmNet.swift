enum EvmNet{
    case goerliTest,  bscTest
    var rpcUrl:String{
        switch self{
        case .goerliTest: return "https://goerli.infura.io/v3/bef864a7a71a4f6d91f9dc08614306a5"
        case .bscTest: return "https://data-seed-prebsc-1-s1.binance.org:8545"
        }
    }
    var chainId:Int{
        switch self{
        case .goerliTest: return 5
        case .bscTest: return 97
        }
    }
    var scanUrl:String{
        switch self{
        case .goerliTest: return "https://goerli.etherscan.io"
        case .bscTest: return "https://testnet.bscscan.com"
        }
    }
}
