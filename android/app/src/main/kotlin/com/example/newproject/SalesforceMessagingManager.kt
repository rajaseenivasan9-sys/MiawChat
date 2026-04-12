package com.example.newproject

import android.content.Context
import androidx.fragment.app.FragmentActivity
import com.salesforce.android.smi.core.*
import com.salesforce.android.smi.ui.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.net.URL
import java.util.UUID

/**
 * Manager class for Salesforce In-App Messaging SDK
 * Handles configuration and opening of chat conversations
 */
class SalesforceMessagingManager(
    private val context: Context,
    private val eventCallback: ((String) -> Unit)? = null
) {

    private var coreClient: CoreClient? = null
    private var conversationId: UUID? = null
    
    // Coroutine scope for async operations
    private val supervisorJob = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.Main + supervisorJob)

    companion object {
        private const val CONFIG_FILE_NAME = "salesforce_config.json"
        
        // For manual configuration
        private const val SERVICE_API_URL = "https://YOUR_SERVICE_API_URL.salesforce-scrt.com"
        private const val ORG_ID = "YOUR_ORG_ID"
        private const val DEPLOYMENT_NAME = "YOUR_DEPLOYMENT_NAME"
        
        // Preference key for storing conversation ID
        private const val PREF_CONVERSATION_ID = "salesforce_conversation_id"
        private const val PREFS_NAME = "salesforce_messaging_prefs"

        // Static event callback for fragments
        private var staticEventCallback: ((String) -> Unit)? = null

        fun setStaticEventCallback(callback: ((String) -> Unit)?) {
            staticEventCallback = callback
        }

        fun sendEventToFlutter(event: String) {
            staticEventCallback?.invoke(event)
        }
    }

    /**
     * Opens the Salesforce chat conversation using config file
     */
    fun openChatWithConfigFile(usePersistedConversation: Boolean = true) {
        try {
            val coreConfig = CoreConfiguration.fromFile(context, CONFIG_FILE_NAME)
            val conversationID = if (usePersistedConversation) getOrCreateConversationId() else UUID.randomUUID()
            this.conversationId = conversationID

            val config = UIConfiguration(coreConfig, conversationID).apply {
                // TODO: Hide the SDK's title bar to avoid the back button, title, and menu
                // Check SDK API for correct method
            }
            coreClient = CoreClient.Factory.create(context, coreConfig)

            openChatAsModal(config)
        } catch (e: Exception) {
            e.printStackTrace()
            throw e
        }
    }

    /**
     * Opens the Salesforce chat conversation using manual configuration
     */
    fun openChatManual(
        usePersistedConversation: Boolean = true,
        serviceApiUrl: String = SERVICE_API_URL,
        orgId: String = ORG_ID,
        deploymentName: String = DEPLOYMENT_NAME
    ) {
        try {
            val url = URL(serviceApiUrl)
            val coreConfig = CoreConfiguration(url, orgId, deploymentName)
            val conversationID = if (usePersistedConversation) getOrCreateConversationId() else UUID.randomUUID()
            this.conversationId = conversationID

            val config = UIConfiguration(coreConfig, conversationID).apply {
                // TODO: Hide the SDK's title bar to avoid the back button, title, and menu
                // Check SDK API for correct method
            }
            coreClient = CoreClient.Factory.create(context, coreConfig)

            openChatAsModal(config)
        } catch (e: Exception) {
            e.printStackTrace()
            throw e
        }
    }

    /**
     * Opens the Salesforce chat. 
     * We now rely on the Theme Override in AndroidManifest.xml to make it a Bottom Sheet.
     */
    private fun openChatAsModal(config: UIConfiguration) {
        try {
            setStaticEventCallback(eventCallback)

            if (context is FragmentActivity) {
                val fragment = ChatBottomSheetDialogFragment.newInstance(config)
                val fragmentManager = context.supportFragmentManager
                fragment.show(fragmentManager, "SalesforceChatBottomSheet")
            } else {
                throw IllegalStateException("Salesforce chat requires an activity context for bottom sheet display.")
            }
        } catch (e: Exception) {
            e.printStackTrace()
            throw e
        }
    }

    fun closeConversation(): Boolean {
        return try {
            conversationId?.let { id ->
                scope.launch {
                    try {
                        coreClient?.closeConversation(id)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                clearConversation()
                true
            } ?: false
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun startNewConversation() {
        closeConversation()
        openChatWithConfigFile(usePersistedConversation = false)
    }

    private fun getOrCreateConversationId(): UUID {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedId = prefs.getString(PREF_CONVERSATION_ID, null)
        
        return if (savedId != null) {
            try {
                UUID.fromString(savedId)
            } catch (e: IllegalArgumentException) {
                createAndSaveNewConversationId(prefs)
            }
        } else {
            createAndSaveNewConversationId(prefs)
        }
    }

    private fun createAndSaveNewConversationId(prefs: android.content.SharedPreferences): UUID {
        val newId = UUID.randomUUID()
        prefs.edit().putString(PREF_CONVERSATION_ID, newId.toString()).apply()
        return newId
    }

    fun clearConversation() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(PREF_CONVERSATION_ID).apply()
        conversationId = null
    }

    fun getCurrentConversationId(): UUID? = conversationId
}
