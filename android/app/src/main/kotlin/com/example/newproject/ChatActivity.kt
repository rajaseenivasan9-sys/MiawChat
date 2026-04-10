package com.example.newproject

import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.salesforce.android.smi.ui.UIClient
import com.salesforce.android.smi.ui.UIConfiguration

/**
 * Activity that displays Salesforce chat as a bottom sheet modal with blue header
 * This wraps the UIClient to appear as a bottom sheet like iOS
 */
class ChatActivity : AppCompatActivity() {

    companion object {
        private const val UI_CONFIG_KEY = "uiConfig"
        private var currentUIConfig: UIConfiguration? = null
        private var eventCallback: ((String) -> Unit)? = null

        fun setUIConfig(config: UIConfiguration) {
            currentUIConfig = config
        }
        
        fun setEventCallback(callback: ((String) -> Unit)?) {
            eventCallback = callback
        }
    }
    
    private var eventSent = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Configure window for bottom sheet appearance
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = ContextCompat.getColor(this, android.R.color.holo_blue_dark)
        }

        // Set the custom layout
        setContentView(R.layout.chat_activity)

        // Get references to views
        val contentContainer = findViewById<FrameLayout>(R.id.content_container)
        val minimizeButton = findViewById<ImageButton>(R.id.minimize_button)
        val closeButton = findViewById<ImageButton>(R.id.close_button)

        // Set up button click listeners
        minimizeButton.setOnClickListener {
            // Send minimize event to Flutter
            if (!eventSent) {
                eventSent = true
                eventCallback?.invoke("minimized")
            }
            finish()
        }

        closeButton.setOnClickListener {
            // Send close event to Flutter
            if (!eventSent) {
                eventSent = true
                eventCallback?.invoke("closed")
            }
            finish()
        }

        // Open the Salesforce chat UI
        if (currentUIConfig != null) {
            try {
                val uiClient = UIClient.Factory.create(currentUIConfig!!)
                uiClient.openConversationActivity(this)
            } catch (e: Exception) {
                e.printStackTrace()
                finish()
            }
        } else {
            finish()
        }
    }

    override fun onBackPressed() {
        // Send close event when back button is pressed (only if not already sent)
        if (!eventSent) {
            eventSent = true
            eventCallback?.invoke("closed")
        }
        super.onBackPressed()
    }

    override fun finish() {
        // Send close event when activity is finished via finish() (only if not already sent)
        if (!eventSent) {
            eventSent = true
            eventCallback?.invoke("closed")
        }
        super.finish()
        // Add bottom slide animation when closing
        overridePendingTransition(0, android.R.anim.slide_out_right)
    }
}
