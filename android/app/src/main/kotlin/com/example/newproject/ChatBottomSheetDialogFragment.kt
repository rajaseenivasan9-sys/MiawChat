package com.example.newproject

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
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
        // Create a container for the chat UI with blue header
        val rootView = FrameLayout(requireContext()).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // Add blue header (56dp height)
        val headerView = View(requireContext()).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(56)
            )
            setBackgroundColor(ContextCompat.getColor(requireContext(), android.R.color.holo_blue_dark))
        }
        rootView.addView(headerView)

        // Create content container below header
        val contentContainer = FrameLayout(requireContext()).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ).apply {
                topMargin = dp(56)
            }
            setBackgroundColor(ContextCompat.getColor(requireContext(), android.R.color.white))
        }
        rootView.addView(contentContainer)

        // Create UIClient and show it (this will open in the conversation activity)
        if (uiConfiguration != null) {
            uiClient = UIClient.Factory.create(uiConfiguration!!)
        }

        return rootView
    }

    private fun dp(value: Int): Int {
        return (value * requireContext().resources.displayMetrics.density).toInt()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        uiClient = null
        _tempConfig = null
    }
}
