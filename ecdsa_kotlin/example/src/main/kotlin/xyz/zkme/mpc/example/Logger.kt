package xyz.zkme.mpc.example


val mpcLogger = MpcLogger()

class MpcLogger {
    private val logger by lazy { java.util.logging.Logger.getLogger("twoPartyEcdsa") }
    var debug = false

    fun info(msg: String) {
        if (debug) {
            logger.log(java.util.logging.Level.INFO, msg)
        }
    }

}