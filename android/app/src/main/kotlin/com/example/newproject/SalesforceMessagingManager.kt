package com.example.newproject

import android.content.Context
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
class SalesforceMessagingManager(private val context: Context) {

    private var uiClient: UIClient? = null
    private var coreClient: CoreClient? = null
    private var conversationId: UUID? = null
    
    // Coroutine scope for async operations
    private val supervisorJob = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.Main + supervisorJob)

    companion object {
        private const val CONFIG_FILE_NAME = "salesforce_config.json"
        
        // For manual configuration (Option 2)
        // Replace these values with your Salesforce deployment details
        private const val SERVICE_API_URL = "https://YOUR_SERVICE_API_URL.salesforce-scrt.com"
        private const val ORG_ID = "YOUR_ORG_ID"
        private const val DEPLOYMENT_NAME = "YOUR_DEPLOYMENT_NAME"
        
        // Preference key for storing conversation ID
        private const val PREF_CONVERSATION_ID = "salesforce_conversation_id"
        private const val PREFS_NAME = "salesforce_messaging_prefs"
    }

    /**
     * Opens the Salesforce chat conversation using config file
     * @param usePersistedConversation - If true, uses the same conversation ID across app restarts
     */
    fun openChatWithConfigFile(usePersistedConversation: Boolean = true) {
        try {
            // Create a Core configuration object from config file
            val coreConfig = CoreConfiguration.fromFile(context, CONFIG_FILE_NAME)

            // Get or generate conversation ID
            val conversationID = if (usePersistedConversation) {
                getOrCreateConversationId()
            } else {
                UUID.randomUUID()
            }
            
            this.conversationId = conversationID

            // Create a UI configuration object
            val config = UIConfiguration(coreConfig, conversationID)

            // Create CoreClient for conversation management
            coreClient = CoreClient.Factory.create(context, coreConfig)

            // Create UIClient and open conversation
            uiClient = UIClient.Factory.create(config)
            uiClient?.openConversationActivity(context)
            
        } catch (e: Exception) {
            e.printStackTrace()
            throw e
        }
    }

    /**
     * Opens the Salesforce chat conversation using manual configuration
     * @param usePersistedConversation - If true, uses the same conversation ID across app restarts
     * @param serviceApiUrl - Optional custom Service API URL
     * @param orgId - Optional custom Organization ID
     * @param deploymentName - Optional custom Deployment Name
     */
    fun openChatManual(
        usePersistedConversation: Boolean = true,
        serviceApiUrl: String = SERVICE_API_URL,
        orgId: String = ORG_ID,
        deploymentName: String = DEPLOYMENT_NAME
    ) {
        try {
            // Get a URL for the service API path
            val url = URL(serviceApiUrl)

            // Create a Core configuration object manually
            val coreConfig = CoreConfiguration(url, orgId, deploymentName)

            // Get or generate conversation ID
            val conversationID = if (usePersistedConversation) {
                getOrCreateConversationId()
            } else {
                UUID.randomUUID()
            }
            
            this.conversationId = conversationID

            // Create a UI configuration object
            val config = UIConfiguration(coreConfig, conversationID)

            // Create CoreClient for conversation management
            coreClient = CoreClient.Factory.create(context, coreConfig)

            // Create UIClient and open conversation
            uiClient = UIClient.Factory.create(config)
            uiClient?.openConversationActivity(context)
            
        } catch (e: Exception) {
            e.printStackTrace()
            throw e
        }
    }

    /**
     * Closes the current conversation explicitly
     * When closed, no new messages can be sent to this conversation
     */
    fun closeConversation(): Boolean {
        return try {
            conversationId?.let { id ->
                // Use coroutine scope to call the suspend function
                scope.launch {
                    try {
                        coreClient?.closeConversation(id)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                // Clear the stored conversation ID after closing
                clearConversation()
                true
            } ?: false
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Starts a new conversation (closes current and creates new ID)
     */
    fun startNewConversation() {
        // Close existing conversation if any
        closeConversation()
        // Open chat with a new conversation ID
        openChatWithConfigFile(usePersistedConversation = false)
    }

    /**
     * Gets an existing conversation ID or creates a new one
     * This allows conversations to persist across app restarts
     */
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

    /**
     * Creates a new conversation ID and saves it to SharedPreferences
     */
    private fun createAndSaveNewConversationId(prefs: android.content.SharedPreferences): UUID {
        val newId = UUID.randomUUID()
        prefs.edit().putString(PREF_CONVERSATION_ID, newId.toString()).apply()
        return newId
    }

    /**
     * Clears the stored conversation ID
     * Call this when you want to start a fresh conversation
     */
    fun clearConversation() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(PREF_CONVERSATION_ID).apply()
        conversationId = null
    }

    /**
     * Returns the current conversation ID if one exists
     */
    fun getCurrentConversationId(): UUID? = conversationId
}

