package com.example.newproject

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import androidx.core.content.ContextCompat
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
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
        fun newInstance(config: UIConfiguration): ChatBottomSheetDialogFragment {
            return ChatBottomSheetDialogFragment().apply {
                arguments = Bundle().apply {
                    // We can't pass UIConfiguration directly through Bundle
                    // Instead, store it in a companion object temporarily
                    _tempConfig = config
                }
            }
        }

        private var _tempConfig: UIConfiguration? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        uiConfiguration = _tempConfig
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
        val minimizeButton = rootView.findViewById<ImageButton>(R.id.minimize_button)
        val closeButton = rootView.findViewById<ImageButton>(R.id.close_button)

        // Set up button click listeners
        minimizeButton.setOnClickListener {
            // Send minimize event to Flutter
            SalesforceMessagingManager.sendEventToFlutter("minimized")
            dismiss()
        }

        closeButton.setOnClickListener {
            // Send close event to Flutter
            SalesforceMessagingManager.sendEventToFlutter("closed")
            dismiss()
        }

        // Create UIClient and show it (this will open in the conversation activity)
        if (uiConfiguration != null) {
            uiClient = UIClient.Factory.create(uiConfiguration!!)
        }

        return rootView
    }

    override fun onDestroyView() {
        super.onDestroyView()
        uiClient = null
        _tempConfig = null
    }
}
