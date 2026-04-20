package com.newyorklife.mynyl.mobile

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

/**
 * Handles Flutter MethodChannel communication for Salesforce In-App Messaging.
 */
class SalesforceMethodChannelHandler(
    private val salesforceManager: SalesforceMessagingManager
) : SalesforceAuthTokenProvider {

    companion object {
        private const val CHANNEL = "com.newyorklife.mynyl.mobile/salesforce_chat"
        private var methodChannel: MethodChannel? = null

        fun sendEventToFlutter(event: String) {
            when (event) {
                "opened" -> methodChannel?.invokeMethod("onChatOpened", null)
                "minimized" -> methodChannel?.invokeMethod("onChatMinimized", null)
                "closed" -> methodChannel?.invokeMethod("onChatClosed", null)
                "session_ended" -> methodChannel?.invokeMethod("onSessionEnded", null)
            }
        }
    }

    private suspend fun fetchToken(method: String): String = withContext(Dispatchers.Main) {
        suspendCancellableCoroutine { continuation ->
            methodChannel?.invokeMethod(method, null, object : MethodChannel.Result {
                override fun success(p0: Any?) {
                    when (p0) {
                        is String -> continuation.resume(p0)
                    }

                }

                override fun error(p0: String, p1: String?, p2: Any?) {
                    TODO("Not yet implemented")
                }

                override fun notImplemented() {
                    TODO("Not yet implemented")
                }

            })

        }
    }

    override suspend fun onGetToken(): String = fetchToken("getToken")

    override suspend fun onRefreshToken(): String = fetchToken("refreshToken")

    fun register(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openChat" -> {
                    try {
                        val useConfigFile = call.argument<Boolean>("useConfigFile") ?: true
                        val persistConversation = call.argument<Boolean>("persistConversation") ?: true

                        if (useConfigFile) {
                            salesforceManager.openChatWithConfigFile(persistConversation)
                        } else {
                            val serviceApiUrl = call.argument<String>("serviceApiUrl")
                            val orgId = call.argument<String>("orgId")
                            val deploymentName = call.argument<String>("deploymentName")
                            val hasPreChatValues = call.argument<Boolean>("hasPreChatValues") ?: false

                            if (serviceApiUrl != null && orgId != null && deploymentName != null) {
                                if (hasPreChatValues) {
                                    val clientId = call.argument<String>("clientId")
                                    val policyNumber = call.argument<String>("policyNumber")
                                    val reason = call.argument<String>("reason")
                                    val timeZoneOffset = call.argument<String>("timeZoneOffset")

                                    if (clientId != null && policyNumber != null && reason != null && timeZoneOffset != null) {
                                        salesforceManager.openChatManualWithPreChatValues(
                                            persistConversation,
                                            serviceApiUrl,
                                            orgId,
                                            deploymentName,
                                            clientId,
                                            policyNumber,
                                            reason,
                                            timeZoneOffset
                                        )
                                    }
                                } else {
                                    salesforceManager.openChatManual(
                                        persistConversation,
                                        serviceApiUrl,
                                        orgId,
                                        deploymentName
                                    )
                                }
                            } else {
                                result.error("INVALID_ARGS", "Manual config requires serviceApiUrl, orgId, and deploymentName", null)
                                return@setMethodCallHandler
                            }
                        }
                        sendEventToFlutter("opened")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CHAT_ERROR", e.message, null)
                    }
                }
                "clearConversation" -> {
                    try {
                        salesforceManager.clearConversation()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEAR_ERROR", e.message, null)
                    }
                }
                "closeConversation" -> {
                    try {
                        val success = salesforceManager.closeConversation()
                        if (success) {
                            sendEventToFlutter("session_ended")
                        }
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("CLOSE_ERROR", e.message, null)
                    }
                }
                "startNewConversation" -> {
                    try {
                        salesforceManager.startNewConversation()
                        sendEventToFlutter("opened")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NEW_CONVERSATION_ERROR", e.message, null)
                    }
                }
                "minimizeChat" -> {
                    // Handled by native chat UI controls; Flutter can listen to callbacks.
                    result.success(true)
                }
                "getConversationId" -> {
                    val conversationId = salesforceManager.getCurrentConversationId()
                    result.success(conversationId?.toString())
                }
                "revokeToken" -> {
                    try {
                        salesforceManager.revokeToken()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("REVOKE_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
