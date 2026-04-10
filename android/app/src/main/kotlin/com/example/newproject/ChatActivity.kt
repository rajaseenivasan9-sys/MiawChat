package com.example.newproject

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
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

        fun setUIConfig(config: UIConfiguration) {
            currentUIConfig = config
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Configure window for bottom sheet appearance
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = ContextCompat.getColor(this, android.R.color.holo_blue_dark)
        }

        // Create root container
        val rootView = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(ContextCompat.getColor(this@ChatActivity, android.R.color.white))
        }

        // Add blue header (56dp)
        val headerView = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(56)
            )
            setBackgroundColor(ContextCompat.getColor(this@ChatActivity, android.R.color.holo_blue_dark))
        }
        rootView.addView(headerView)

        // Add close button or handle in header
        val closeButton = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dpToPx(40), dpToPx(40)).apply {
                gravity = android.view.Gravity.TOP or android.view.Gravity.END
                rightMargin = dpToPx(16)
                topMargin = dpToPx(8)
            }
            setBackgroundResource(android.R.drawable.ic_menu_close_clear_cancel)
            setOnClickListener { finish() }
        }
        rootView.addView(closeButton)

        // Create content container for Salesforce chat UI
        val contentContainer = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ).apply {
                topMargin = dpToPx(56)
            }
        }
        rootView.addView(contentContainer)

        setContentView(rootView)

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

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }

    override fun finish() {
        super.finish()
        // Add bottom slide animation when closing
        overridePendingTransition(0, android.R.anim.slide_out_right)
    }
}
