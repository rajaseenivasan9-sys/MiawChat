package com.example.newproject

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import androidx.compose.ui.platform.ComposeView
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import androidx.compose.runtime.Composable
import com.salesforce.android.smi.ui.UIClient
import com.salesforce.android.smi.ui.UIConfiguration

/**
 * Bottom Sheet Dialog Fragment for displaying Salesforce chat
 * Displays the chat as a modal at the bottom with a blue header, matching iOS behavior
 */
class ChatBottomSheetDialogFragment : BottomSheetDialogFragment() {

    private var uiClient: UIClient? = null
    private var uiConfiguration: UIConfiguration? = null

    companion object {
        private var _tempConfig: UIConfiguration? = null
        
        fun newInstance(config: UIConfiguration): ChatBottomSheetDialogFragment {
            _tempConfig = config
            return ChatBottomSheetDialogFragment()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        uiConfiguration = _tempConfig
        // Set style for rounded corners and translucent background
        setStyle(STYLE_NORMAL, R.style.ChatBottomSheetDialogTheme)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        // Inflate the custom layout
        val rootView = inflater.inflate(R.layout.chat_activity, container, false)

        // Get references to views
        val contentContainer = rootView.findViewById<FrameLayout>(R.id.content_container)
        val chatHeader = rootView.findViewById<View>(R.id.chat_header)
        val minimizeButton = chatHeader?.findViewById<ImageButton>(R.id.minimize_button)
        val closeButton = chatHeader?.findViewById<ImageButton>(R.id.close_button)

        // Set up button click listeners
        minimizeButton?.setOnClickListener {
            SalesforceMessagingManager.sendEventToFlutter("minimized")
            dismiss()
        }

        closeButton?.setOnClickListener {
            SalesforceMessagingManager.sendEventToFlutter("closed")
            dismiss()
        }

        // Create UIClient and show it using Compose
        if (uiConfiguration != null) {
            try {
                uiClient = UIClient.Factory.create(uiConfiguration!!)
                
                // Add ComposeView to the content container
                val composeView = ComposeView(requireContext()).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                    setContent {
                        // MessagingInAppUI is the main composable for SMI SDK
                        // Parameters for 1.10.0: onExit
                        uiClient?.MessagingInAppUI(onExit = { dismiss() })
                    }
                }
                contentContainer.addView(composeView)
            } catch (e: Exception) {
                e.printStackTrace()
                dismiss()
            }
        }

        return rootView
    }

    override fun onStart() {
        super.onStart()
        // Ensure the bottom sheet is fully expanded and occupies most of the screen
        val dialog = dialog
        if (dialog != null) {
            val bottomSheet = dialog.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
            if (bottomSheet != null) {
                val behavior = BottomSheetBehavior.from(bottomSheet)
                behavior.state = BottomSheetBehavior.STATE_EXPANDED
                behavior.isHideable = true
                
                // Set height to roughly 90% of screen
                val displayMetrics = resources.displayMetrics
                bottomSheet.layoutParams.height = (displayMetrics.heightPixels * 0.95).toInt()
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        uiClient = null
        _tempConfig = null
    }
}
