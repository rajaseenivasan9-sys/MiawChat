package com.newyorklife.mynyl.mobile

import android.content.Context
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import com.salesforce.android.smi.core.*
import com.salesforce.android.smi.network.api.auth.UserVerificationProvider
import com.salesforce.android.smi.network.api.auth.UserVerificationToken
import com.salesforce.android.smi.network.data.domain.prechat.PreChatField
import com.salesforce.android.smi.ui.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.net.URL
import java.util.UUID

/**
 * Manager class for Salesforce In-App Messaging SDK.
 * Handles configuration, user verification, and opening of chat conversations.
 */
class SalesforceMessagingManager(
    private val context: Context,
    private val eventCallback: ((String) -> Unit)? = null
) {

    private var coreClient: CoreClient? = null
    private var conversationId: UUID? = null
    private var conversationClient: ConversationClient? = null
    private var tokenProvider: SalesforceAuthTokenProvider? = null

    private val supervisorJob = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.Main + supervisorJob)

    companion object {
        private const val CONFIG_FILE_NAME = "salesforce_config.json"
        private const val PREF_CONVERSATION_ID = "salesforce_conversation_id"
        private const val PREFS_NAME = "salesforce_messaging_prefs"
        private const val CHAT_NOTIFICATION_CHANNEL_ID = "salesforce_chat_messages"
        private const val CHAT_NOTIFICATION_CHANNEL_NAME = "Live Chat Messages"
        private const val CHAT_NOTIFICATION_ID = 9001

        private var staticEventCallback: ((String) -> Unit)? = null

        fun setStaticEventCallback(callback: ((String) -> Unit)?) {
            staticEventCallback = callback
        }

        fun sendEventToFlutter(event: String) {
            staticEventCallback?.invoke(event)
        }
    }

    fun setAuthTokenProvider(provider: SalesforceAuthTokenProvider) {
        tokenProvider = provider
    }

    /**
     * Revokes the current token and clears verification state.
     * Call this when the user logs out.
     */
    fun revokeToken() {
        scope.launch {
            try {
                coreClient?.revokeToken(deregisterDevice = false)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    /**
     * Opens the Salesforce chat conversation using config file.
     * @param usePersistedConversation If true, reuses conversation ID across app restarts.
     */
    fun openChatWithConfigFile(usePersistedConversation: Boolean = true) {
        val coreConfig = CoreConfiguration.fromFile(context, CONFIG_FILE_NAME, true)

        val conversationID = if (usePersistedConversation) {
            getOrCreateConversationId()
        } else {
            UUID.randomUUID()
        }

        this.conversationId = conversationID

        val config = UIConfiguration(coreConfig, conversationID)
        coreClient = CoreClient.Factory.create(context, coreConfig)

        tokenProvider.let {
            registerUserVerificationProvider()
        }

        openChatAsModal(config)
    }

    /**
     * Opens the Salesforce chat conversation using manual configuration.
     */
    fun openChatManual(
        usePersistedConversation: Boolean = true,
        serviceApiUrl: String,
        orgId: String,
        deploymentName: String
    ) {
        val url = URL(serviceApiUrl)
        val coreConfig = CoreConfiguration(url, orgId, deploymentName, true)

        val conversationID = if (usePersistedConversation) {
            getOrCreateConversationId()
        } else {
            UUID.randomUUID()
        }

        this.conversationId = conversationID

        val config = UIConfiguration(coreConfig, conversationID)
        coreClient = CoreClient.Factory.create(context, coreConfig)

        tokenProvider.let {
            registerUserVerificationProvider()
        }

        openChatAsModal(config)
    }

    /**
     * Opens the Salesforce chat conversation using manual configuration with pre-chat values.
     */
    fun openChatManualWithPreChatValues(
        usePersistedConversation: Boolean = true,
        serviceApiUrl: String,
        orgId: String,
        deploymentName: String,
        clientId: String,
        policyNumber: String,
        reason: String,
        timeZoneOffset: String,
    ) {
        val url = URL(serviceApiUrl)
        val coreConfig = CoreConfiguration(url, orgId, deploymentName, true)

        val conversationID = if (usePersistedConversation) {
            getOrCreateConversationId()
        } else {
            UUID.randomUUID()
        }

        this.conversationId = conversationID

        val config = UIConfiguration(coreConfig, conversationID)
        coreClient = CoreClient.Factory.create(context, coreConfig)
        registerHiddenPreChatValuesProvider(clientId, policyNumber, reason, timeZoneOffset)

        tokenProvider.let {
            registerUserVerificationProvider()
        }

        openChatAsModal(config)
    }

    private fun openChatAsModal(config: UIConfiguration) {
        setStaticEventCallback(eventCallback)
        listenForCoreEvents()

        if (context is androidx.fragment.app.FragmentActivity) {
            val fragment = SalesforceChatFragment.newInstance(config)
            val fragmentManager = context.supportFragmentManager
            fragment.show(fragmentManager, "SalesforceChatFragment")
        } else {
            throw IllegalStateException("Salesforce chat requires an activity context for full-screen display.")
        }
    }

    /**
     * Subscribes to CoreClient event flows to emit message and unread count updates to Flutter.
     */
    private fun listenForCoreEvents() {
       
    }

    private fun sendEventToFlutterWithData(event: String, data: Map<String, Any>) {
        // For now, we'll send just the event name and rely on Flutter to query the unread count
        // when it subscribes via the service
        sendEventToFlutter(event)
    }

    /**
     * Registers the UserVerificationProvider with the CoreClient.
     * The SDK will call userVerificationChallenge when it needs a token.
     */
    private fun registerUserVerificationProvider() {
        coreClient?.registerUserVerificationProvider(object : UserVerificationProvider {
            override suspend fun userVerificationChallenge(reason: UserVerificationProvider.ChallengeReason): UserVerificationToken {
                val token = when (reason) {
                    UserVerificationProvider.ChallengeReason.INITIAL -> tokenProvider?.onGetToken()
                    UserVerificationProvider.ChallengeReason.RENEW -> tokenProvider?.onRefreshToken()
                    UserVerificationProvider.ChallengeReason.EXPIRED -> tokenProvider?.onRefreshToken()
                    UserVerificationProvider.ChallengeReason.MALFORMED -> tokenProvider?.onGetToken()
                }

                if (token != null) {
                    return UserVerificationToken(UserVerificationToken.UserVerificationType.JWT, token)
                }

                return UserVerificationToken(UserVerificationToken.UserVerificationType.JWT, "")
            }
        })
    }

    /**
     * Registers the PreChatValuesProvider with the CoreClient.
     * The SDK will call setValues when it needs values to be set.
     */
    private fun registerHiddenPreChatValuesProvider(clientId: String, policyNumber: String, reason: String, timeZoneOffset: String) {
        coreClient?.registerHiddenPreChatValuesProvider(object : PreChatValuesProvider {
            override suspend fun setValues(input: List<PreChatField>): List<PreChatField> {
                input.map {
                    when (it.name) {
                        "Client_Id" -> it.userInput = clientId
                        "Policy_Number" -> it.userInput = policyNumber
                        "Reason" -> it.userInput = reason
                        "P_TimeZoneOffset" -> it.userInput = timeZoneOffset
                    }
                }
                return input
            }
        })
    }

    /**
     * Closes the current conversation explicitly.
     * After closing, no new messages can be sent to this conversation.
     */
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

    /**
     * Starts a new conversation (closes current and creates new ID).
     */
    fun startNewConversation() {
        closeConversation()
        openChatWithConfigFile(usePersistedConversation = false)
    }

    /**
     * Clears the stored conversation ID.
     */
    fun clearConversation() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(PREF_CONVERSATION_ID).apply()
        conversationId = null
    }

    /**
     * Returns the current conversation ID if one exists.
     */
    fun getCurrentConversationId(): UUID? = conversationId

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

    private fun showLocalChatNotificationIfBackground() {
        if (isAppInForeground()) {
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        ensureChatNotificationChannel()

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val notification = NotificationCompat.Builder(context, CHAT_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("MyNYL")
            .setContentText("You have a new chat message")
            .setStyle(NotificationCompat.BigTextStyle().bigText("You have a new chat message"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(CHAT_NOTIFICATION_ID, notification)
    }

    private fun ensureChatNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val existing = manager.getNotificationChannel(CHAT_NOTIFICATION_CHANNEL_ID)
        if (existing != null) {
            return
        }

        val channel = NotificationChannel(
            CHAT_NOTIFICATION_CHANNEL_ID,
            CHAT_NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifications for new Salesforce live chat messages"
        }
        manager.createNotificationChannel(channel)
    }

    private fun isAppInForeground(): Boolean {
        return ProcessLifecycleOwner.get().lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
    }
}
