package com.example.newproject

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val CHANNEL = "com.example.newproject/salesforce_chat"
        private var methodChannel: MethodChannel? = null
    }
    
    private lateinit var salesforceManager: SalesforceMessagingManager
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Salesforce Messaging Manager with callback for events
        salesforceManager = SalesforceMessagingManager(this) { event ->
            // Send events back to Flutter
            when (event) {
                "minimized" -> methodChannel?.invokeMethod("onChatMinimized", null)
                "closed" -> methodChannel?.invokeMethod("onChatClosed", null)
            }
        }
        
        // Set up method channel for Flutter communication
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
                            // Get manual configuration parameters if provided
                            val serviceApiUrl = call.argument<String>("serviceApiUrl")
                            val orgId = call.argument<String>("orgId")
                            val deploymentName = call.argument<String>("deploymentName")
                            
                            if (serviceApiUrl != null && orgId != null && deploymentName != null) {
                                salesforceManager.openChatManual(
                                    persistConversation,
                                    serviceApiUrl,
                                    orgId,
                                    deploymentName
                                )
                            } else {
                                salesforceManager.openChatManual(persistConversation)
                            }
                        }
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
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("CLOSE_ERROR", e.message, null)
                    }
                }
                "startNewConversation" -> {
                    try {
                        salesforceManager.startNewConversation()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NEW_CONVERSATION_ERROR", e.message, null)
                    }
                }
                "getConversationId" -> {
                    val conversationId = salesforceManager.getCurrentConversationId()
                    result.success(conversationId?.toString())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}


